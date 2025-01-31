import prompts from "prompts";
import hre, { ethers } from "hardhat";

import { bigNumberify, expandDecimals } from "../utils/math";
import { encodeData } from "../utils/hash";
import { getFullKey } from "../utils/config";

import * as keys from "../utils/keys";
import { getOracleProviderAddress } from "../utils/oracle";

export async function initOracleConfigForTokens({ write }) {
  const tokens = await hre.gmx.getTokens();

  const dataStore = await hre.ethers.getContract("DataStore");
  const multicall = await hre.ethers.getContract("Multicall3");
  const config = await hre.ethers.getContract("Config");

  const multicallReadParams = [];

  const tokenSymbols = Object.keys(tokens);
  let paramsCount: number | undefined = undefined;

  for (const tokenSymbol of tokenSymbols) {
    const token = tokens[tokenSymbol];
    const oracleProviderAddress = await getOracleProviderAddress(token.oracleProvider);
    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getAddress", [
        getFullKey(keys.PRICE_FEED, encodeData(["address"], [token.address])),
      ]),
    });
    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getBytes32", [
        getFullKey(keys.DATA_STREAM_ID, encodeData(["address"], [token.address])),
      ]),
    });
    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getAddress", [
        getFullKey(keys.ORACLE_PROVIDER_FOR_TOKEN, encodeData(["address"], [token.address])),
      ]),
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        getFullKey(
          keys.ORACLE_TIMESTAMP_ADJUSTMENT,
          encodeData(["address", "address"], [oracleProviderAddress, token.address])
        ),
      ]),
    });

    if (paramsCount === undefined) {
      paramsCount = multicallReadParams.length;
    }
  }

  const result = await multicall.callStatic.aggregate3(multicallReadParams);

  const onchainOracleConfig = {};
  const { defaultAbiCoder } = ethers.utils;

  for (let i = 0; i < tokenSymbols.length; i++) {
    const tokenSymbol = tokenSymbols[i];
    onchainOracleConfig[tokenSymbol] = {
      priceFeed: defaultAbiCoder.decode(["address"], result[i * paramsCount].returnData)[0],
      dataStreamId: result[i * paramsCount + 1].returnData,
      oracleProvider: defaultAbiCoder.decode(["address"], result[i * paramsCount + 2].returnData)[0],
      oracleTimestampAdjustment: defaultAbiCoder.decode(["uint"], result[i * paramsCount + 3].returnData)[0],
    };
  }

  const multicallWriteParams = [];

  for (let i = 0; i < tokenSymbols.length; i++) {
    const tokenSymbol = tokenSymbols[i];
    console.log(`checking ${tokenSymbol}`);
    const token = tokens[tokenSymbol];
    const onchainConfig = onchainOracleConfig[tokenSymbol];

    if (onchainConfig.priceFeed === ethers.constants.AddressZero && token.priceFeed) {
      const { priceFeed } = token;
      const priceFeedMultiplier = expandDecimals(1, 60 - token.decimals - priceFeed.decimals);
      const stablePrice = priceFeed.stablePrice ? priceFeed.stablePrice : 0;

      console.log(
        `setPriceFeed(${tokenSymbol}, ${priceFeed.address}, ${priceFeedMultiplier.toString()}, ${
          priceFeed.heartbeatDuration
        }, ${stablePrice.toString()})`
      );

      multicallWriteParams.push(
        config.interface.encodeFunctionData("setPriceFeed", [
          token.address,
          priceFeed.address,
          priceFeedMultiplier,
          priceFeed.heartbeatDuration,
          stablePrice,
        ])
      );
    }

    if (onchainConfig.dataStreamId === ethers.constants.HashZero && token.dataStreamFeedId) {
      const dataStreamMultiplier = expandDecimals(1, 60 - token.decimals - token.dataStreamFeedDecimals);
      const dataStreamSpreadReductionFactor = bigNumberify(token.dataStreamSpreadReductionFactor ?? 0);

      console.log(
        `setDataStream(${tokenSymbol} ${
          token.dataStreamFeedId
        }, ${dataStreamMultiplier.toString()}, ${dataStreamSpreadReductionFactor.toString()})`
      );

      multicallWriteParams.push(
        config.interface.encodeFunctionData("setDataStream", [
          token.address,
          token.dataStreamFeedId,
          dataStreamMultiplier,
          dataStreamSpreadReductionFactor,
        ])
      );
    }

    if (
      token.oracleTimestampAdjustment !== undefined &&
      !onchainConfig.oracleTimestampAdjustment.eq(token.oracleTimestampAdjustment)
    ) {
      const oracleProviderAddress = await getOracleProviderAddress(token.oracleProvider);
      console.log(
        `set oracle timestamp adjustment ${oracleProviderAddress} ${tokenSymbol} ${token.oracleTimestampAdjustment}`
      );

      multicallWriteParams.push(
        config.interface.encodeFunctionData("setUint", [
          keys.ORACLE_TIMESTAMP_ADJUSTMENT,
          defaultAbiCoder.encode(["address", "address"], [oracleProviderAddress, token.address]),
          token.oracleTimestampAdjustment,
        ])
      );
    }
  }

  for (const tokenSymbol of tokenSymbols) {
    const token = tokens[tokenSymbol];
    const onchainConfig = onchainOracleConfig[tokenSymbol];
    const oracleProviderAddress = await getOracleProviderAddress(token.oracleProvider);

    if (onchainConfig.oracleProvider.toLowerCase() !== oracleProviderAddress.toLowerCase()) {
      console.log(`update oracle provider for ${tokenSymbol}`);
      multicallWriteParams.push(
        config.interface.encodeFunctionData("initOracleProviderForToken", [token.address, oracleProviderAddress])
      );
    }
  }

  console.log("multicallWriteParams", multicallWriteParams);
  if (multicallWriteParams.length === 0) {
    console.log("no params to update");
    return;
  }

  console.log(`updating ${multicallWriteParams.length} params`);

  if (!write) {
    ({ write } = await prompts({
      type: "confirm",
      name: "write",
      message: "Do you want to execute the transactions?",
    }));
  }

  if (write) {
    const tx = await config.multicall(multicallWriteParams);
    console.log(`tx sent: ${tx.hash}`);
  } else {
    console.log("NOTE: executed in read-only mode, no transactions were sent");
  }
}
