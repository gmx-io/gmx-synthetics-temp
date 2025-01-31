import hre, { network } from "hardhat";

import { validateMarketConfigs } from "./validateMarketConfigsUtils";
import { encodeData } from "../utils/hash";
import { bigNumberify } from "../utils/math";
import { getFullKey, appendUintConfigIfDifferent } from "../utils/config";
import * as keys from "../utils/keys";

const processTokens = async ({ tokens, handleConfig }) => {
  for (const [, token] of Object.entries(tokens) as any) {
    if (token.dataStreamSpreadReductionFactor !== undefined) {
      await handleConfig(
        "uint",
        keys.DATA_STREAM_SPREAD_REDUCTION_FACTOR,
        encodeData(["address"], [token.address]),
        token.dataStreamSpreadReductionFactor,
        `dataStreamSpreadReductionFactor ${token.dataStreamSpreadReductionFactor}`
      );
    }

    // the config below is for non-synthetic markets only
    if (token.synthetic) {
      continue;
    }

    await handleConfig(
      "uint",
      keys.TOKEN_TRANSFER_GAS_LIMIT,
      encodeData(["address"], [token.address]),
      token.transferGasLimit,
      `transferGasLimit ${token.transferGasLimit}`
    );

    if (token.buybackMaxPriceImpactFactor !== undefined) {
      await handleConfig(
        "uint",
        keys.BUYBACK_MAX_PRICE_IMPACT_FACTOR,
        encodeData(["address"], [token.address]),
        token.buybackMaxPriceImpactFactor,
        `buybackMaxPriceImpactFactor ${token.buybackMaxPriceImpactFactor}`
      );
    }
  }
};

async function main() {
  if (!["arbitrumGoerli", "avalancheFuji"].includes(network.name)) {
    const { errors } = await validateMarketConfigs();
    if (errors.length !== 0) {
      throw new Error("Invalid market configs");
    }
  }

  const tokens = await hre.gmx.getTokens();

  const dataStore = await hre.ethers.getContract("DataStore");
  const multicall = await hre.ethers.getContract("Multicall3");
  const config = await hre.ethers.getContract("Config");

  const keys = [];
  const multicallReadParams = [];

  await processTokens({
    tokens,
    handleConfig: async (type, baseKey, keyData) => {
      if (type !== "uint") {
        throw new Error("Unsupported type");
      }

      const key = getFullKey(baseKey, keyData);

      keys.push(key);
      multicallReadParams.push({
        target: dataStore.address,
        allowFailure: false,
        callData: dataStore.interface.encodeFunctionData("getUint", [key]),
      });
    },
  });

  const result = await multicall.callStatic.aggregate3(multicallReadParams);
  const dataCache = {};
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    const value = result[i].returnData;
    dataCache[key] = bigNumberify(value);
  }

  const multicallWriteParams = [];

  await processTokens({
    tokens,
    handleConfig: async (type, baseKey, keyData, value, label) => {
      if (type !== "uint") {
        throw new Error("Unsupported type");
      }

      await appendUintConfigIfDifferent(multicallWriteParams, dataCache, baseKey, keyData, value, label);
    },
  });

  console.log(`updating ${multicallWriteParams.length} params`);
  console.log("multicallWriteParams", multicallWriteParams);

  if (process.env.WRITE === "true") {
    const tx = await config.multicall(multicallWriteParams);
    console.log(`tx sent: ${tx.hash}`);
  } else {
    console.log("NOTE: executed in read-only mode, no transactions were sent");
  }
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((ex) => {
    console.error(ex);
    process.exit(1);
  });
