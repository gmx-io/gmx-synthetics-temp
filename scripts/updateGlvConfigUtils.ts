import prompts from "prompts";

import { encodeData } from "../utils/hash";
import { bigNumberify } from "../utils/math";
import { getMarketKey, getOnchainMarkets } from "../utils/market";
import { getFullKey, appendUintConfigIfDifferent } from "../utils/config";
import { handleInBatches } from "../utils/batch";
import * as keys from "../utils/keys";

const processGlvs = async ({ glvs, onchainMarketsByTokens, tokens, handleConfig, dataStore }) => {
  const marketsToAdd: [string, string][] = [];

  for (const glvConfig of glvs) {
    const longToken = tokens[glvConfig.longToken];
    const shortToken = tokens[glvConfig.shortToken];
    const glvSymbol = glvConfig.symbol ?? `GLV [${glvConfig.longToken}-${glvConfig.shortToken}]`;

    const glvAddress = glvConfig.address;

    if (!glvAddress) {
      throw new Error(`No address for GLV ${glvConfig.longToken}-${glvConfig.shortToken} in the config`);
    }

    await handleConfig(
      "uint",
      keys.GLV_SHIFT_MIN_INTERVAL,
      encodeData(["address"], [glvAddress]),
      glvConfig.shiftMinInterval,
      `shiftMinInterval ${glvSymbol}`
    );
    await handleConfig(
      "uint",
      keys.GLV_SHIFT_MAX_PRICE_IMPACT_FACTOR,
      encodeData(["address"], [glvAddress]),
      glvConfig.shiftMaxPriceImpactFactor,
      `shiftMaxPriceImpactFactor ${glvSymbol}`
    );
    await handleConfig(
      "uint",
      keys.MIN_GLV_TOKENS_FOR_FIRST_DEPOSIT,
      encodeData(["address"], [glvAddress]),
      glvConfig.minTokensForFirstGlvDeposit,
      `minTokensForFirstGlvDeposit ${glvSymbol}`
    );

    await handleConfig(
      "uint",
      keys.TOKEN_TRANSFER_GAS_LIMIT,
      encodeData(["address"], [glvConfig.address]),
      glvConfig.transferGasLimit || 200_000,
      `transferGasLimit ${glvConfig.transferGasLimit}`
    );

    const glvSupportedMarketList = await dataStore.getAddressValuesAt(
      keys.glvSupportedMarketListKey(glvAddress),
      0,
      100
    );

    for (const glvMarketConfig of glvConfig.markets) {
      const indexToken = tokens[glvMarketConfig.indexToken];
      const marketKey = getMarketKey(indexToken.address, longToken.address, shortToken.address);
      const onchainMarket = onchainMarketsByTokens[marketKey];
      const marketAddress = onchainMarket.marketToken;

      if (!glvSupportedMarketList.includes(marketAddress)) {
        marketsToAdd.push([glvAddress, marketAddress]);
      }

      if (glvMarketConfig.isMarketDisabled !== undefined) {
        await handleConfig(
          "uint",
          keys.IS_GLV_MARKET_DISABLED,
          encodeData(["address", "address"], [glvAddress, marketAddress]),
          glvMarketConfig.isMarketDisabled,
          `isMarketDisabled market ${indexToken.symbol}/USD in ${glvSymbol}`
        );
      }
      await handleConfig(
        "uint",
        keys.GLV_MAX_MARKET_TOKEN_BALANCE_AMOUNT,
        encodeData(["address", "address"], [glvAddress, marketAddress]),
        glvMarketConfig.glvMaxMarketTokenBalanceAmount,
        `glvMaxMarketTokenBalanceAmount market ${indexToken.symbol}/USD in ${glvSymbol}`
      );
      await handleConfig(
        "uint",
        keys.GLV_MAX_MARKET_TOKEN_BALANCE_USD,
        encodeData(["address", "address"], [glvAddress, marketAddress]),
        glvMarketConfig.glvMaxMarketTokenBalanceUsd,
        `glvMaxMarketTokenBalanceUsd market ${indexToken.symbol}/USD in ${glvSymbol}`
      );
    }
  }
  return marketsToAdd;
};

export async function updateGlvConfig({ write }) {
  console.log("running update glv config...");
  const { read } = hre.deployments;

  const [tokens, glvs, dataStore, glvHandler, multicall, config] = await Promise.all([
    hre.gmx.getTokens(),
    hre.gmx.getGlvs(),
    hre.ethers.getContract("DataStore"),
    hre.ethers.getContract("GlvHandler"),
    hre.ethers.getContract("Multicall3"),
    hre.ethers.getContract("Config"),
  ]);

  const onchainMarketsByTokens = await getOnchainMarkets(read, dataStore.address);

  const configKeys = [];
  const multicallReadParams = [];
  const readStart = Date.now();
  console.log("reading on-chain config...");
  const marketsToAdd = await processGlvs({
    glvs,
    onchainMarketsByTokens,
    tokens,
    dataStore,
    handleConfig: (type, baseKey, keyData) => {
      if (type !== "uint") {
        throw new Error("Unsupported type");
      }

      const key = getFullKey(baseKey, keyData);

      configKeys.push(key);
      multicallReadParams.push({
        target: dataStore.address,
        allowFailure: false,
        callData: dataStore.interface.encodeFunctionData("getUint", [key]),
      });
    },
  });

  const result = await multicall.callStatic.aggregate3(multicallReadParams);
  console.log("done in %sms", Date.now() - readStart);

  const dataCache = {};
  for (let i = 0; i < configKeys.length; i++) {
    const key = configKeys[i];
    const value = result[i].returnData;
    dataCache[key] = bigNumberify(value);
  }

  const multicallWriteParams = [];
  console.log("preparing write params...");
  const prepareStart = Date.now();
  await processGlvs({
    glvs,
    onchainMarketsByTokens,
    tokens,
    dataStore,
    handleConfig: async (type, baseKey, keyData, value, label) => {
      if (type !== "uint") {
        throw new Error("Unsupported type");
      }

      await appendUintConfigIfDifferent(multicallWriteParams, dataCache, baseKey, keyData, value, label);
    },
  });
  console.log("done in %sms", Date.now() - prepareStart);

  if (multicallWriteParams.length === 0) {
    console.log("no changes to apply");
    return;
  }

  console.info(`updating ${multicallWriteParams.length} params`);
  console.info("multicallWriteParams", multicallWriteParams);

  console.log("running simulation");
  for (const [glvAddress, marketAddress] of marketsToAdd) {
    console.log("simulating adding market %s to glv %s", marketAddress, glvAddress);
    await glvHandler.callStatic.addMarketToGlv(glvAddress, marketAddress);
  }

  await handleInBatches(multicallWriteParams, 100, async (batch) => {
    console.log("simulating config updates");
    await config.callStatic.multicall(batch);
  });
  console.log("simulation done");

  if (!write) {
    ({ write } = await prompts({
      type: "confirm",
      name: "write",
      message: "Do you want to execute the transactions?",
    }));
  }

  if (!write) {
    console.info("NOTE: executed in read-only mode, no transactions were sent");
    return;
  }

  for (const [glvAddress, marketAddress] of marketsToAdd) {
    console.log("adding market %s to glv %s", marketAddress, glvAddress);
    const tx = await glvHandler.addMarketToGlv(glvAddress, marketAddress);
    console.log("sent tx: %s", tx.hash);
  }

  await handleInBatches(multicallWriteParams, 100, async (batch) => {
    const tx = await config.multicall(batch);
    console.info(`update config tx sent: ${tx.hash}`);
  });
}
