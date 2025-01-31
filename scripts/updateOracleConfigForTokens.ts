import { bigNumberify, expandDecimals } from "../utils/math";
import { encodeData } from "../utils/hash";
import { getFullKey } from "../utils/config";
import { timelockWriteMulticall } from "../utils/timelock";

import * as keys from "../utils/keys";
import { getOracleProviderAddress, getOracleProviderKey } from "../utils/oracle";

const expectedPhases = ["signal", "finalize"];

export async function updateOracleConfigForTokens() {
  const tokens = await hre.gmx.getTokens();

  const dataStore = await hre.ethers.getContract("DataStore");
  const multicall = await hre.ethers.getContract("Multicall3");
  const timelock = await hre.ethers.getContract("Timelock");

  const multicallReadParams = [];

  const phase = process.env.PHASE;

  if (!expectedPhases.includes(phase)) {
    throw new Error(`Unexpected PHASE: ${phase}. valid values: ${expectedPhases.join(", ")}`);
  }

  const tokenSymbols = Object.keys(tokens);
  let paramsCount: number | undefined = undefined;

  for (const tokenSymbol of tokenSymbols) {
    const token = tokens[tokenSymbol];

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
      callData: dataStore.interface.encodeFunctionData("getUint", [
        getFullKey(keys.PRICE_FEED_MULTIPLIER, encodeData(["address"], [token.address])),
      ]),
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        getFullKey(keys.STABLE_PRICE, encodeData(["address"], [token.address])),
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
      callData: dataStore.interface.encodeFunctionData("getUint", [
        getFullKey(keys.DATA_STREAM_MULTIPLIER, encodeData(["address"], [token.address])),
      ]),
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        getFullKey(keys.DATA_STREAM_SPREAD_REDUCTION_FACTOR, encodeData(["address"], [token.address])),
      ]),
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getAddress", [
        getFullKey(keys.ORACLE_PROVIDER_FOR_TOKEN, encodeData(["address"], [token.address])),
      ]),
    });

    if (paramsCount === undefined) {
      paramsCount = multicallReadParams.length;
    }
  }

  const result = await multicall.callStatic.aggregate3(multicallReadParams);

  const onchainOracleConfig = {};
  const { defaultAbiCoder } = hre.ethers.utils;

  for (let i = 0; i < tokenSymbols.length; i++) {
    const tokenSymbol = tokenSymbols[i];
    onchainOracleConfig[tokenSymbol] = {
      priceFeed: defaultAbiCoder.decode(["address"], result[i * paramsCount].returnData)[0],
      priceFeedMultiplier: defaultAbiCoder.decode(["uint"], result[i * paramsCount + 1].returnData)[0],
      stablePrice: defaultAbiCoder.decode(["uint"], result[i * paramsCount + 2].returnData)[0],
      dataStreamId: result[i * paramsCount + 3].returnData,
      dataStreamMultiplier: defaultAbiCoder.decode(["uint"], result[i * paramsCount + 4].returnData)[0],
      dataStreamSpreadReductionFactor: defaultAbiCoder.decode(["uint"], result[i * paramsCount + 5].returnData)[0],
      oracleProviderForToken: defaultAbiCoder.decode(["address"], result[i * paramsCount + 6].returnData)[0],
    };
  }

  const multicallWriteParams = [];

  for (const tokenSymbol of tokenSymbols) {
    console.log(`checking: ${tokenSymbol}`);
    const token = tokens[tokenSymbol];
    const onchainConfig = onchainOracleConfig[tokenSymbol];

    if (token.priceFeed && onchainConfig.priceFeed.toLowerCase() !== token.priceFeed.address.toLowerCase()) {
      const { priceFeed } = token;
      const priceFeedMultiplier =
        token.priceFeed.address === ethers.constants.AddressZero
          ? 0
          : expandDecimals(1, 60 - token.decimals - priceFeed.decimals);
      const stablePrice = priceFeed.stablePrice ? priceFeed.stablePrice : 0;

      if (
        !onchainConfig.priceFeedMultiplier.eq(priceFeedMultiplier) &&
        onchainConfig.priceFeed !== ethers.constants.AddressZero &&
        token.priceFeed.address !== ethers.constants.AddressZero
      ) {
        throw new Error(
          `priceFeedMultiplier mismatch for ${tokenSymbol}: ${priceFeedMultiplier.toString()}, ${onchainConfig.priceFeedMultiplier.toString()}`
        );
      }

      if (!onchainConfig.stablePrice.eq(stablePrice)) {
        throw new Error(
          `stablePrice mismatch for ${tokenSymbol}: ${stablePrice.toString()}, ${onchainConfig.stablePrice.toString()}`
        );
      }

      console.log(
        `setPriceFeed(${tokenSymbol}, ${priceFeed.address}, ${priceFeedMultiplier.toString()}, ${
          priceFeed.heartbeatDuration
        }, ${stablePrice.toString()})`
      );

      const method = phase === "signal" ? "signalSetPriceFeed" : "setPriceFeedAfterSignal";

      multicallWriteParams.push(
        timelock.interface.encodeFunctionData(method, [
          token.address,
          priceFeed.address,
          priceFeedMultiplier,
          priceFeed.heartbeatDuration,
          stablePrice,
        ])
      );
    }

    if (token.dataStreamFeedId && onchainConfig.dataStreamId !== token.dataStreamFeedId) {
      const dataStreamSpreadReductionFactor = bigNumberify(token.dataStreamSpreadReductionFactor ?? 0);
      const dataStreamMultiplier = expandDecimals(1, 60 - token.decimals - token.dataStreamFeedDecimals);

      if (!onchainConfig.dataStreamMultiplier.eq(dataStreamMultiplier)) {
        throw new Error(
          `dataStreamMultiplier mismatch for ${tokenSymbol}: ${dataStreamMultiplier.toString()}, ${onchainConfig.dataStreamMultiplier.toString()}`
        );
      }

      console.log(
        `setDataStream(${tokenSymbol} ${
          token.dataStreamFeedId
        }, ${dataStreamMultiplier.toString()}, ${dataStreamSpreadReductionFactor.toString()})`
      );

      const method = phase === "signal" ? "signalSetDataStream" : "setDataStreamAfterSignal";

      multicallWriteParams.push(
        timelock.interface.encodeFunctionData(method, [
          token.address,
          token.dataStreamFeedId,
          dataStreamMultiplier,
          dataStreamSpreadReductionFactor,
        ])
      );
    }

    const oracleProviderAddress = await getOracleProviderAddress(token.oracleProvider);
    if (oracleProviderAddress !== onchainConfig.oracleProviderForToken) {
      const oracleProviderKey = await getOracleProviderKey(oracleProviderAddress);
      console.log(`setOracleProviderForToken(${tokenSymbol} ${oracleProviderKey} ${oracleProviderAddress})`);

      const method = phase === "signal" ? "signalSetOracleProviderForToken" : "setOracleProviderForTokenAfterSignal";

      // signalSetOracleProviderForToken back to the current oracle provider in case
      // the oracle provider change needs to be rolled back
      if (method === "signalSetOracleProviderForToken") {
        multicallWriteParams.push(
          timelock.interface.encodeFunctionData("signalSetOracleProviderForToken", [
            token.address,
            onchainConfig.oracleProviderForToken,
          ])
        );
      }

      multicallWriteParams.push(timelock.interface.encodeFunctionData(method, [token.address, oracleProviderAddress]));
    }
  }

  console.log(`updating ${multicallWriteParams.length} params`);

  await timelockWriteMulticall({ timelock, multicallWriteParams });
}

async function main() {
  await updateOracleConfigForTokens();
}

main().catch((ex) => {
  console.error(ex);
  process.exit(1);
});
