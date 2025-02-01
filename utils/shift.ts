import { expect } from "chai";
import { logGasUsage } from "./gas";
import { contractAt } from "./deploy";
import { expandDecimals, bigNumberify } from "./math";
import { executeWithOracleParams } from "./exchange";
import { parseLogs } from "./event";
import { getCancellationReason, getErrorString } from "./error";

import * as keys from "./keys";

export function getShiftCount(dataStore) {
  return dataStore.getBytes32Count(keys.SHIFT_LIST);
}

export function getShiftKeys(dataStore, start, end) {
  return dataStore.getBytes32ValuesAt(keys.SHIFT_LIST, start, end);
}

export function getAccountShiftCount(dataStore, account) {
  return dataStore.getBytes32Count(keys.accountShiftListKey(account));
}

export function getAccountShiftKeys(dataStore, account, start, end) {
  return dataStore.getBytes32ValuesAt(keys.accountShiftListKey(account), start, end);
}

export async function createShift(fixture, overrides: any = {}) {
  const { shiftVault, shiftHandler, wnt, ethUsdMarket, solUsdMarket } = fixture.contracts;
  const { wallet, user0 } = fixture.accounts;

  const sender = overrides.sender || wallet;
  const account = overrides.account || user0;
  const receiver = overrides.receiver || account;
  const callbackContract = overrides.callbackContract || { address: ethers.constants.AddressZero };
  const uiFeeReceiver = overrides.uiFeeReceiver || { address: ethers.constants.AddressZero };
  const fromMarket = overrides.fromMarket || ethUsdMarket;
  const toMarket = overrides.toMarket || solUsdMarket;
  const marketTokenAmount = overrides.marketTokenAmount || bigNumberify(0);
  const minMarketTokens = overrides.minMarketTokens || bigNumberify(0);
  const executionFee = overrides.executionFee || "1000000000000000";
  const callbackGasLimit = overrides.callbackGasLimit || bigNumberify(0);
  const dataList = overrides.dataList || [];

  await wnt.mint(shiftVault.address, executionFee);

  const marketToken = await contractAt("MarketToken", fromMarket.marketToken);
  await marketToken.connect(account).transfer(shiftVault.address, marketTokenAmount);

  const params = {
    receiver: receiver.address,
    callbackContract: callbackContract.address,
    uiFeeReceiver: uiFeeReceiver.address,
    fromMarket: fromMarket.marketToken,
    toMarket: toMarket.marketToken,
    minMarketTokens,
    executionFee,
    callbackGasLimit,
    dataList,
  };

  const txReceipt = await logGasUsage({
    tx: shiftHandler.connect(sender).createShift(account.address, params),
    label: overrides.gasUsageLabel,
  });

  const result = { txReceipt };
  return result;
}

export async function executeShift(fixture, overrides: any = {}) {
  const { dataStore, shiftHandler, wnt, usdc, sol } = fixture.contracts;
  const { gasUsageLabel } = overrides;
  const tokens = overrides.tokens || [wnt.address, usdc.address, sol.address];
  const precisions = overrides.precisions || [8, 18, 8];
  const minPrices = overrides.minPrices || [expandDecimals(5000, 4), expandDecimals(1, 6), expandDecimals(600, 4)];
  const maxPrices = overrides.maxPrices || [expandDecimals(5000, 4), expandDecimals(1, 6), expandDecimals(600, 4)];
  const shiftKeys = await getShiftKeys(dataStore, 0, 1);
  const dataStreamTokens = overrides.dataStreamTokens || [];
  const dataStreamData = overrides.dataStreamData || [];
  const priceFeedTokens = overrides.priceFeedTokens || [];
  let shiftKey = overrides.shiftKey;
  let oracleBlockNumber = overrides.oracleBlockNumber;

  if (shiftKeys.length > 0) {
    if (!shiftKey) {
      shiftKey = shiftKeys[0];
    }
    if (!oracleBlockNumber) {
      oracleBlockNumber = (await ethers.provider.getBlock()).number;
    }
  }

  const params = {
    key: shiftKey,
    oracleBlockNumber,
    tokens,
    precisions,
    minPrices,
    maxPrices,
    execute: shiftHandler.executeShift,
    gasUsageLabel,
    dataStreamTokens,
    dataStreamData,
    priceFeedTokens,
  };

  const txReceipt = await executeWithOracleParams(fixture, params);

  const logs = parseLogs(fixture, txReceipt);

  const cancellationReason = await getCancellationReason({
    logs,
    eventName: "ShiftCancelled",
  });

  if (cancellationReason) {
    if (overrides.expectedCancellationReason) {
      expect(cancellationReason.name).eq(overrides.expectedCancellationReason);
    } else {
      throw new Error(`Shift was cancelled: ${getErrorString(cancellationReason)}`);
    }
  } else {
    if (overrides.expectedCancellationReason) {
      throw new Error(
        `Shift was not cancelled, expected cancellation with reason: ${overrides.expectedCancellationReason}`
      );
    }
  }

  const result = { txReceipt, logs };
  return result;
}

export async function handleShift(fixture, overrides: any = {}) {
  const createResult = await createShift(fixture, overrides.create);
  const executeResult = await executeShift(fixture, overrides.execute);
  return { createResult, executeResult };
}
