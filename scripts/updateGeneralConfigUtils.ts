import hre, { network } from "hardhat";

import prompts from "prompts";
import { bigNumberify } from "../utils/math";
import {
  getFullKey,
  appendUintConfigIfDifferent,
  appendAddressConfigIfDifferent,
  appendBoolConfigIfDifferent,
} from "../utils/config";
import * as keys from "../utils/keys";

const processGeneralConfig = async ({ generalConfig, oracleConfig, handleConfig }) => {
  await handleConfig(
    "address",
    keys.CHAINLINK_PAYMENT_TOKEN,
    "0x",
    oracleConfig.chainlinkPaymentToken,
    `chainlinkPaymentToken`
  );

  await handleConfig(
    "uint",
    keys.SEQUENCER_GRACE_DURATION,
    "0x",
    generalConfig.sequencerGraceDuration,
    `sequencerGraceDuration`
  );

  await handleConfig("uint", keys.MAX_UI_FEE_FACTOR, "0x", generalConfig.maxUiFeeFactor, `maxUiFeeFactor`);

  await handleConfig(
    "uint",
    keys.MAX_AUTO_CANCEL_ORDERS,
    "0x",
    generalConfig.maxAutoCancelOrders,
    `maxAutoCancelOrders`
  );

  await handleConfig(
    "uint",
    keys.MAX_TOTAL_CALLBACK_GAS_LIMIT_FOR_AUTO_CANCEL_ORDERS,
    "0x",
    generalConfig.maxTotalCallbackGasLimitForAutoCancelOrders,
    `maxTotalCallbackGasLimitForAutoCancelOrders`
  );

  await handleConfig(
    "uint",
    keys.MIN_HANDLE_EXECUTION_ERROR_GAS,
    "0x",
    generalConfig.minHandleExecutionErrorGas,
    `minHandleExecutionErrorGas`
  );

  await handleConfig(
    "uint",
    keys.MIN_HANDLE_EXECUTION_ERROR_GAS_TO_FORWARD,
    "0x",
    generalConfig.minHandleExecutionErrorGasToForward,
    `minHandleExecutionErrorGasToForward`
  );

  await handleConfig(
    "uint",
    keys.MIN_ADDITIONAL_GAS_FOR_EXECUTION,
    "0x",
    generalConfig.minAdditionalGasForExecution,
    `minAdditionalGasForExecution`
  );

  await handleConfig(
    "uint",
    keys.REFUND_EXECUTION_FEE_GAS_LIMIT,
    "0x",
    generalConfig.refundExecutionFeeGasLimit,
    `refundExecutionFeeGasLimit`
  );

  await handleConfig(
    "uint",
    keys.MAX_CALLBACK_GAS_LIMIT,
    "0x",
    generalConfig.maxCallbackGasLimit,
    `maxCallbackGasLimit`
  );

  await handleConfig("uint", keys.MAX_SWAP_PATH_LENGTH, "0x", generalConfig.maxSwapPathLength, `maxSwapPathLength`);

  await handleConfig("uint", keys.MIN_COLLATERAL_USD, "0x", generalConfig.minCollateralUsd, `minCollateralUsd`);

  await handleConfig("uint", keys.MIN_POSITION_SIZE_USD, "0x", generalConfig.minPositionSizeUsd, `minCollateralUsd`);

  await handleConfig(
    "uint",
    keys.SWAP_FEE_RECEIVER_FACTOR,
    "0x",
    generalConfig.swapFeeReceiverFactor,
    `swapFeeReceiverFactor`
  );

  await handleConfig(
    "uint",
    keys.POSITION_FEE_RECEIVER_FACTOR,
    "0x",
    generalConfig.positionFeeReceiverFactor,
    `positionFeeReceiverFactor`
  );

  await handleConfig(
    "uint",
    keys.LIQUIDATION_FEE_RECEIVER_FACTOR,
    "0x",
    generalConfig.liquidationFeeReceiverFactor,
    `liquidationFeeReceiverFactor`
  );

  await handleConfig("uint", keys.DEPOSIT_GAS_LIMIT, "0x", generalConfig.depositGasLimit, `depositGasLimit`);

  await handleConfig("uint", keys.WITHDRAWAL_GAS_LIMIT, "0x", generalConfig.withdrawalGasLimit, `withdrawalGasLimit`);

  await handleConfig("uint", keys.shiftGasLimitKey(), "0x", generalConfig.shiftGasLimit, `shiftGasLimit`);

  await handleConfig(
    "uint",
    keys.singleSwapGasLimitKey(),
    "0x",
    generalConfig.singleSwapGasLimit,
    `singleSwapGasLimit`
  );

  await handleConfig(
    "uint",
    keys.increaseOrderGasLimitKey(),
    "0x",
    generalConfig.increaseOrderGasLimit,
    `increaseOrderGasLimit`
  );

  await handleConfig(
    "uint",
    keys.decreaseOrderGasLimitKey(),
    "0x",
    generalConfig.decreaseOrderGasLimit,
    `decreaseOrderGasLimit`
  );

  await handleConfig("uint", keys.swapOrderGasLimitKey(), "0x", generalConfig.swapOrderGasLimit, `swapOrderGasLimit`);

  if (hre.network.name !== "avalanche" || process.env.SKIP_GLV_LIMITS_AVALANCHE !== "true") {
    await handleConfig(
      "uint",
      keys.glvPerMarketGasLimitKey(),
      "0x",
      generalConfig.glvPerMarketGasLimit,
      `glvPerMarketGasLimit`
    );

    await handleConfig(
      "uint",
      keys.glvDepositGasLimitKey(),
      "0x",
      generalConfig.glvDepositGasLimit,
      `glvDepositGasLimit`
    );

    await handleConfig(
      "uint",
      keys.glvWithdrawalGasLimitKey(),
      "0x",
      generalConfig.glvWithdrawalGasLimit,
      `glvWithdrawalGasLimit`
    );

    await handleConfig("uint", keys.glvShiftGasLimitKey(), "0x", generalConfig.glvShiftGasLimit, `glvShiftGasLimit`);
  }

  await handleConfig(
    "uint",
    keys.NATIVE_TOKEN_TRANSFER_GAS_LIMIT,
    "0x",
    generalConfig.nativeTokenTransferGasLimit,
    `nativeTokenTransferGasLimit`
  );

  if (generalConfig.estimatedGasFeeBaseAmount) {
    await handleConfig(
      "uint",
      keys.ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1,
      "0x",
      generalConfig.estimatedGasFeeBaseAmount,
      `estimatedGasFeeBaseAmount`
    );

    if (network.name === "arbitrum") {
      throw new Error("estimatedGasFeeBaseAmount should be updated in a separate keeper");
    }
  }

  if (generalConfig.estimatedGasPerOraclePrice) {
    await handleConfig(
      "uint",
      keys.ESTIMATED_GAS_FEE_PER_ORACLE_PRICE,
      "0x",
      generalConfig.estimatedGasPerOraclePrice,
      `estimatedGasPerOraclePrice`
    );

    if (network.name === "arbitrum") {
      throw new Error("estimatedGasPerOraclePrice should be updated in a separate keeper");
    }
  }

  await handleConfig(
    "uint",
    keys.ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR,
    "0x",
    generalConfig.estimatedGasFeeMultiplierFactor,
    `estimatedGasFeeMultiplierFactor`
  );

  if (generalConfig.executionGasFeeBaseAmount) {
    await handleConfig(
      "uint",
      keys.EXECUTION_GAS_FEE_BASE_AMOUNT_V2_1,
      "0x",
      generalConfig.executionGasFeeBaseAmount,
      `executionGasFeeBaseAmount`
    );

    if (network.name === "arbitrum") {
      throw new Error("executionGasFeeBaseAmount should be updated in a separate keeper");
    }
  }

  if (generalConfig.executionGasPerOraclePrice) {
    await handleConfig(
      "uint",
      keys.EXECUTION_GAS_FEE_PER_ORACLE_PRICE,
      "0x",
      generalConfig.executionGasPerOraclePrice,
      `executionGasPerOraclePrice`
    );

    if (network.name === "arbitrum") {
      throw new Error("executionGasPerOraclePrice should be updated in a separate keeper");
    }
  }

  await handleConfig(
    "uint",
    keys.EXECUTION_GAS_FEE_MULTIPLIER_FACTOR,
    "0x",
    generalConfig.executionGasFeeMultiplierFactor,
    `executionGasFeeMultiplierFactor`
  );

  if (generalConfig.requestExpirationTime !== undefined) {
    await handleConfig(
      "uint",
      keys.REQUEST_EXPIRATION_TIME,
      "0x",
      generalConfig.requestExpirationTime,
      `requestExpirationTime`
    );
  }

  if (generalConfig.requestExpirationTime !== undefined) {
    await handleConfig(
      "uint",
      keys.REQUEST_EXPIRATION_TIME,
      "0x",
      generalConfig.requestExpirationTime,
      `requestExpirationTime`
    );
  }
};

export async function updateGeneralConfig({ write }) {
  const generalConfig = await hre.gmx.getGeneral();
  const oracleConfig = await hre.gmx.getOracle();

  const dataStore = await hre.ethers.getContract("DataStore");
  const multicall = await hre.ethers.getContract("Multicall3");
  const config = await hre.ethers.getContract("Config");

  const configKeys = [];
  const multicallReadParams = [];
  const types = [];

  await processGeneralConfig({
    generalConfig,
    oracleConfig,
    handleConfig: async (type, baseKey, keyData) => {
      const key = getFullKey(baseKey, keyData);

      configKeys.push(key);
      types.push(type);

      if (type === "uint") {
        multicallReadParams.push({
          target: dataStore.address,
          allowFailure: false,
          callData: dataStore.interface.encodeFunctionData("getUint", [key]),
        });
      } else if (type === "address") {
        multicallReadParams.push({
          target: dataStore.address,
          allowFailure: false,
          callData: dataStore.interface.encodeFunctionData("getAddress", [key]),
        });
      } else if (type === "bool") {
        multicallReadParams.push({
          target: dataStore.address,
          allowFailure: false,
          callData: dataStore.interface.encodeFunctionData("getBool", [key]),
        });
      } else {
        throw new Error(`Unsupported type: ${type}`);
      }
    },
  });

  const result = await multicall.callStatic.aggregate3(multicallReadParams);
  const dataCache = {};
  for (let i = 0; i < configKeys.length; i++) {
    const type = types[i];
    const key = configKeys[i];
    const value = result[i].returnData;
    if (type === "uint") {
      dataCache[key] = bigNumberify(value);
    } else if (type === "address") {
      dataCache[key] = ethers.utils.defaultAbiCoder.decode(["address"], value)[0];
    } else if (type === "bool") {
      dataCache[key] = ethers.utils.defaultAbiCoder.decode(["bool"], value)[0];
    } else {
      throw new Error(`Unsupported type: ${type}`);
    }
  }

  const multicallWriteParams = [];

  await processGeneralConfig({
    generalConfig,
    oracleConfig,
    handleConfig: async (type, baseKey, keyData, value, label) => {
      if (type === "uint") {
        await appendUintConfigIfDifferent(multicallWriteParams, dataCache, baseKey, keyData, value, label);
      } else if (type === "address") {
        await appendAddressConfigIfDifferent(multicallWriteParams, dataCache, baseKey, keyData, value, label);
      } else if (type === "bool") {
        await appendBoolConfigIfDifferent(multicallWriteParams, dataCache, baseKey, keyData, value, label);
      } else {
        throw new Error(`Unsupported type: ${type}`);
      }
    },
  });

  console.log(`updating ${multicallWriteParams.length} params`);
  console.log("multicallWriteParams", multicallWriteParams);

  if (multicallWriteParams.length === 0) {
    console.log("no changes to apply");
    return;
  }

  try {
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
      await config.callStatic.multicall(multicallWriteParams, {
        from: "0xF09d66CF7dEBcdEbf965F1Ac6527E1Aa5D47A745",
      });
      console.log("NOTE: executed in read-only mode, no transactions were sent");
    }
  } catch (ex) {
    if (
      ex.errorName === "InvalidBaseKey" &&
      hre.network.name === "avalanche" &&
      process.env.SKIP_GLV_LIMITS_AVALANCHE !== "true"
    ) {
      console.error(ex);
      console.log("Use SKIP_GLV_LIMITS_AVALANCHE=true to skip updating GLV gas limits on Avalanche");
      return;
    }

    throw ex;
  }
}
