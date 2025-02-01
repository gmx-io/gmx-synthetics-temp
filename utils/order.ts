import { expect } from "chai";
import { mine } from "@nomicfoundation/hardhat-network-helpers";

import { logGasUsage } from "./gas";
import { bigNumberify, expandDecimals } from "./math";
import { executeWithOracleParams } from "./exchange";
import { parseLogs, getEventDataValue } from "./event";
import { getCancellationReason, getErrorString } from "./error";

import * as keys from "./keys";
import { Contract } from "ethers";

export const OrderType = {
  MarketSwap: 0,
  LimitSwap: 1,
  MarketIncrease: 2,
  LimitIncrease: 3,
  MarketDecrease: 4,
  LimitDecrease: 5,
  StopLossDecrease: 6,
  Liquidation: 7,
  StopIncrease: 8,
};

export const DecreasePositionSwapType = {
  NoSwap: 0,
  SwapPnlTokenToCollateralToken: 1,
  SwapCollateralTokenToPnlToken: 2,
};

export function getOrderCount(dataStore: Contract): Promise<number> {
  return dataStore.getBytes32Count(keys.ORDER_LIST);
}

export function getOrderKeys(dataStore: Contract, start: number, end: number): Promise<string[]> {
  return dataStore.getBytes32ValuesAt(keys.ORDER_LIST, start, end);
}

export async function getLastAccountOrder(dataStore: Contract, reader: Contract, account: string): Promise<any> {
  const orderCount = await getAccountOrderCount(dataStore, account);
  if (orderCount === 0) {
    return null;
  }
  const orderKeys = await getAccountOrderKeys(dataStore, account, orderCount - 1, orderCount);
  return reader.getOrder(dataStore.address, orderKeys[0]);
}

export function getAccountOrderCount(dataStore: Contract, account: string): Promise<number> {
  return dataStore.getBytes32Count(keys.accountOrderListKey(account));
}

export function getAccountOrderKeys(
  dataStore: Contract,
  account: string,
  start: number,
  end: number
): Promise<string[]> {
  return dataStore.getBytes32ValuesAt(keys.accountOrderListKey(account), start, end);
}

export function getAutoCancelOrderKeys(
  dataStore: Contract,
  positionKey: string,
  start: number,
  end: number
): Promise<string[]> {
  return dataStore.getBytes32ValuesAt(keys.autoCancelOrderListKey(positionKey), start, end);
}

export async function createOrder(fixture, overrides) {
  const { initialCollateralToken, orderType, gasUsageLabel } = overrides;

  const { orderVault, orderHandler, wnt } = fixture.contracts;
  const { wallet, user0 } = fixture.accounts;

  const decreasePositionSwapType = overrides.decreasePositionSwapType || DecreasePositionSwapType.NoSwap;
  const sender = overrides.sender || wallet;
  const account = overrides.account || user0;
  const receiver = overrides.receiver || account;
  const cancellationReceiver = overrides.cancellationReceiver || receiver;
  const callbackContract = overrides.callbackContract || { address: ethers.constants.AddressZero };
  const market = overrides.market || { marketToken: ethers.constants.AddressZero };
  const uiFeeReceiver = overrides.uiFeeReceiver || { address: ethers.constants.AddressZero };
  const sizeDeltaUsd = overrides.sizeDeltaUsd || "0";
  const initialCollateralDeltaAmount = overrides.initialCollateralDeltaAmount || "0";
  const swapPath = overrides.swapPath || [];
  const acceptablePrice = overrides.acceptablePrice || expandDecimals(5200, 12);
  const triggerPrice = overrides.triggerPrice || "0";
  const isLong = overrides.isLong === undefined ? true : overrides.isLong;
  const executionFee = overrides.executionFee || fixture.props.executionFee;
  const executionFeeToMint = overrides.executionFeeToMint || executionFee;
  const callbackGasLimit = overrides.callbackGasLimit || bigNumberify(0);
  const minOutputAmount = overrides.minOutputAmount || 0;
  const shouldUnwrapNativeToken = overrides.shouldUnwrapNativeToken || false;
  const autoCancel = overrides.autoCancel || false;
  const referralCode = overrides.referralCode || ethers.constants.HashZero;
  const validFromTime = overrides.validFromTime || 0;
  const dataList = overrides.dataList || [];

  if (
    [
      OrderType.MarketSwap,
      OrderType.LimitSwap,
      OrderType.MarketIncrease,
      OrderType.LimitIncrease,
      OrderType.StopIncrease,
    ].includes(orderType)
  ) {
    await initialCollateralToken.mint(orderVault.address, initialCollateralDeltaAmount);
  }

  await wnt.mint(orderVault.address, executionFeeToMint);

  const params = {
    addresses: {
      receiver: receiver.address,
      cancellationReceiver: cancellationReceiver.address,
      callbackContract: callbackContract.address,
      uiFeeReceiver: uiFeeReceiver.address,
      market: market.marketToken,
      initialCollateralToken: initialCollateralToken.address,
      swapPath,
    },
    numbers: {
      sizeDeltaUsd,
      initialCollateralDeltaAmount,
      acceptablePrice,
      triggerPrice,
      executionFee,
      callbackGasLimit,
      minOutputAmount,
      validFromTime,
    },
    orderType,
    decreasePositionSwapType,
    isLong,
    shouldUnwrapNativeToken,
    autoCancel,
    referralCode,
    dataList,
  };

  const txReceipt = await logGasUsage({
    tx: orderHandler.connect(sender).createOrder(account.address, params),
    label: gasUsageLabel,
  });

  const logs = parseLogs(fixture, txReceipt);

  const key = getEventDataValue(logs, "OrderCreated", "key");

  return { txReceipt, logs, key };
}

export async function executeOrder(fixture, overrides: any = {}) {
  const { wnt, usdc } = fixture.contracts;
  const { gasUsageLabel, oracleBlockNumberOffset } = overrides;
  const { dataStore, orderHandler } = fixture.contracts;
  const tokens = overrides.tokens || [wnt.address, usdc.address];
  const dataStreamTokens = overrides.dataStreamTokens || [];
  const dataStreamData = overrides.dataStreamData || [];
  const priceFeedTokens = overrides.priceFeedTokens || [];
  const precisions = overrides.precisions || [8, 18];
  const minPrices = overrides.minPrices || [expandDecimals(5000, 4), expandDecimals(1, 6)];
  const maxPrices = overrides.maxPrices || [expandDecimals(5000, 4), expandDecimals(1, 6)];
  const orderKeys = await getOrderKeys(dataStore, 0, 20);
  const orderKey = overrides.orderKey || orderKeys[orderKeys.length - 1];
  let oracleBlockNumber = overrides.oracleBlockNumber || (await ethers.provider.getBlockNumber());
  oracleBlockNumber = bigNumberify(oracleBlockNumber);

  const oracleBlocks = overrides.oracleBlocks;
  const minOracleBlockNumbers = overrides.minOracleBlockNumbers;
  const maxOracleBlockNumbers = overrides.maxOracleBlockNumbers;
  const oracleTimestamps = overrides.oracleTimestamps;
  const blockHashes = overrides.blockHashes;

  if (oracleBlockNumberOffset) {
    if (oracleBlockNumberOffset > 0) {
      mine(oracleBlockNumberOffset);
    }

    oracleBlockNumber = oracleBlockNumber.add(oracleBlockNumberOffset);
  }

  const params = {
    key: orderKey,
    oracleBlockNumber,
    tokens,
    precisions,
    minPrices,
    maxPrices,
    simulate: overrides.simulate,
    execute: overrides.simulate ? orderHandler.simulateExecuteOrder : orderHandler.executeOrder,
    gasUsageLabel,
    oracleBlocks,
    minOracleBlockNumbers,
    maxOracleBlockNumbers,
    oracleTimestamps,
    blockHashes,
    dataStreamTokens,
    dataStreamData,
    priceFeedTokens,
  };

  const txReceipt = await executeWithOracleParams(fixture, params);
  const logs = parseLogs(fixture, txReceipt);
  const cancellationReason = await getCancellationReason({
    logs,
    eventName: "OrderCancelled",
  });

  if (cancellationReason) {
    if (overrides.expectedCancellationReason) {
      expect(cancellationReason.name).eq(overrides.expectedCancellationReason);
    } else {
      throw new Error(`Order was cancelled: ${getErrorString(cancellationReason)}`);
    }
  } else {
    if (overrides.expectedCancellationReason) {
      throw new Error(
        `Order was not cancelled, expected cancellation with reason: ${overrides.expectedCancellationReason}`
      );
    }
  }

  const frozenReason = await getCancellationReason({
    logs,
    eventName: "OrderFrozen",
  });

  if (frozenReason) {
    if (overrides.expectedFrozenReason) {
      expect(frozenReason.name).eq(overrides.expectedFrozenReason);
    } else {
      throw new Error(`Order was frozen: ${getErrorString(frozenReason)}`);
    }
  } else {
    if (overrides.expectedFrozenReason) {
      throw new Error(`Order was not frozen, expected freeze with reason: ${overrides.expectedFrozenReason}`);
    }
  }

  const result = { txReceipt, logs };

  if (overrides.afterExecution) {
    await overrides.afterExecution(result);
  }

  return result;
}

export async function handleOrder(fixture, overrides = {}) {
  const createResult = await createOrder(fixture, overrides.create);
  const executeResult = await executeOrder(fixture, overrides.execute);
  return { createResult, executeResult };
}
