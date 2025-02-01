import { ethers } from "hardhat";

import { contractAt } from "../deploy";
import { bigNumberify, expandDecimals } from "../math";
import { logGasUsage } from "../gas";
import * as keys from "../keys";
import { executeWithOracleParams } from "../exchange";
import { parseLogs } from "../event";
import { getCancellationReason } from "../error";
import { expectCancellationReason } from "../validation";
import { expect } from "chai";

const { AddressZero } = ethers.constants;

export function getGlvWithdrawalKeys(dataStore, start, end) {
  return dataStore.getBytes32ValuesAt(keys.GLV_WITHDRAWAL_LIST, start, end);
}

export function getGlvWithdrawalCount(dataStore) {
  return dataStore.getBytes32Count(keys.GLV_WITHDRAWAL_LIST);
}

export function getAccountGlvWithdrawalCount(dataStore, account) {
  return dataStore.getBytes32Count(keys.accountGlvWithdrawalListKey(account));
}

export function getAccountGlvWithdrawalKeys(dataStore, account, start, end) {
  return dataStore.getBytes32ValuesAt(keys.accountGlvWithdrawalListKey(account), start, end);
}

export async function createGlvWithdrawal(fixture, overrides: any = {}) {
  const { glvVault, glvHandler, glvRouter, wnt, ethUsdMarket, ethUsdGlvAddress } = fixture.contracts;
  const { wallet, user0 } = fixture.accounts;

  const gasUsageLabel = overrides.gasUsageLabel;
  const glv = overrides.glv || ethUsdGlvAddress;
  const sender = overrides.sender || wallet;
  const account = overrides.account || user0;
  const receiver = overrides.receiver || account;
  const callbackContract = overrides.callbackContract || { address: ethers.constants.AddressZero };
  const uiFeeReceiver = overrides.uiFeeReceiver || { address: ethers.constants.AddressZero };
  const market = overrides.market || ethUsdMarket;
  const longTokenSwapPath = overrides.longTokenSwapPath || [];
  const shortTokenSwapPath = overrides.shortTokenSwapPath || [];
  const glvTokenAmount = bigNumberify(overrides.glvTokenAmount ?? 0);
  const minLongTokenAmount = bigNumberify(overrides.minLongTokenAmount ?? 0);
  const minShortTokenAmount = bigNumberify(overrides.minShortTokenAmount ?? 0);
  const shouldUnwrapNativeToken = overrides.shouldUnwrapNativeToken || false;
  const executionFee = bigNumberify(overrides.executionFee ?? "1000000000000000");
  const callbackGasLimit = bigNumberify(overrides.callbackGasLimit ?? 0);
  const useGlvHandler = Boolean(overrides.useGlvHandler) || false;
  const dataList = overrides.dataList || [];

  // allow for overriding executionFeeToMint to trigger InsufficientWntAmount error
  const executionFeeToMint = bigNumberify(overrides.executionFeeToMint ?? executionFee);
  await wnt.mint(glvVault.address, executionFeeToMint);

  const glvToken = await contractAt("GlvToken", glv);

  if (glvTokenAmount.gt(0)) {
    const glvTokenBalance = await glvToken.balanceOf(account.address);
    if (glvTokenBalance.lt(glvTokenAmount)) {
      console.warn("WARN: minting glv tokens without depositing funds. glv token price calculation could be incorrect");
      await glvToken.mint(account.address, glvTokenAmount.sub(glvTokenBalance));
    }
    await glvToken.connect(account).transfer(glvVault.address, glvTokenAmount);
  }

  const params = {
    receiver: receiver.address,
    callbackContract: callbackContract.address,
    uiFeeReceiver: uiFeeReceiver.address,
    glv,
    market: market.marketToken,
    longTokenSwapPath,
    shortTokenSwapPath,
    minLongTokenAmount,
    minShortTokenAmount,
    shouldUnwrapNativeToken,
    executionFee,
    callbackGasLimit,
    dataList,
  };

  for (const [key, value] of Object.entries(params)) {
    if (value === undefined) {
      throw new Error(`param "${key}" is undefined`);
    }
  }

  await logGasUsage({
    tx: useGlvHandler
      ? glvHandler.connect(sender).createGlvWithdrawal(account.address, params)
      : glvRouter.connect(account).createGlvWithdrawal(params),
    label: gasUsageLabel,
  });
}

export async function executeGlvWithdrawal(fixture, overrides: any = {}) {
  const { dataStore, glvHandler, glvRouter, wnt, usdc, sol, ethUsdGlvAddress } = fixture.contracts;
  const gasUsageLabel = overrides.gasUsageLabel;
  const glv = overrides.glv || ethUsdGlvAddress;
  const dataStreamTokens = overrides.dataStreamTokens || [];
  const dataStreamData = overrides.dataStreamData || [];
  const priceFeedTokens = overrides.priceFeedTokens || [];
  const tokens = overrides.tokens || [wnt.address, usdc.address, sol.address];
  const precisions = overrides.precisions || [8, 18, 8];
  const minPrices = overrides.minPrices || [expandDecimals(5000, 4), expandDecimals(1, 6), expandDecimals(600, 4)];
  const maxPrices = overrides.maxPrices || [expandDecimals(5000, 4), expandDecimals(1, 6), expandDecimals(600, 4)];
  const glvWithdrawalKeys = await getGlvWithdrawalKeys(dataStore, 0, 1);

  let glvWithdrawalKey = overrides.key;
  let oracleBlockNumber = overrides.oracleBlockNumber;

  if (glvWithdrawalKeys.length > 0) {
    if (!glvWithdrawalKey) {
      glvWithdrawalKey = glvWithdrawalKeys[0];
    }
  }
  if (!oracleBlockNumber) {
    oracleBlockNumber = await ethers.provider.getBlockNumber();
  }

  const params: any = {
    glv,
    key: glvWithdrawalKey,
    tokens,
    precisions,
    minPrices,
    maxPrices,
    execute: glvHandler.executeGlvWithdrawal,
    simulateExecute: glvRouter.simulateExecuteGlvWithdrawal,
    simulate: overrides.simulate,
    dataStreamTokens,
    dataStreamData,
    priceFeedTokens,
    oracleBlockNumber,
    gasUsageLabel,
  };

  const optionalParams = new Set(["gasUsageLabel", "simulate", "simulateExecute"]);
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined && !optionalParams.has(key)) {
      throw new Error(`param "${key}" is undefined`);
    }
  }

  const txReceipt = await executeWithOracleParams(fixture, params);

  if (overrides.simulate) {
    return;
  }

  const logs = parseLogs(fixture, txReceipt);

  const cancellationReason = await getCancellationReason({
    logs,
    eventName: "GlvWithdrawalCancelled",
  });

  expectCancellationReason(cancellationReason, overrides.expectedCancellationReason, "GlvWithdrawal");

  const result = { txReceipt, logs };
  return result;
}

export async function handleGlvWithdrawal(fixture, overrides: any = {}) {
  const createResult = await createGlvWithdrawal(fixture, overrides.create);

  const createOverridesCopy = { ...overrides.create };
  delete createOverridesCopy.gasUsageLabel;

  const executeResult = await executeGlvWithdrawal(fixture, { ...createOverridesCopy, ...overrides.execute });
  return { createResult, executeResult };
}

export function expectEmptyGlvWithdrawal(glvWithdrawal: any) {
  expect(glvWithdrawal.addresses.account).eq(AddressZero);
  expect(glvWithdrawal.addresses.receiver).eq(AddressZero);
  expect(glvWithdrawal.addresses.callbackContract).eq(AddressZero);
  expect(glvWithdrawal.addresses.market).eq(AddressZero);
  expect(glvWithdrawal.addresses.glv).eq(AddressZero);
  expect(glvWithdrawal.addresses.uiFeeReceiver).eq(AddressZero);
  expect(glvWithdrawal.addresses.longTokenSwapPath).deep.eq([]);
  expect(glvWithdrawal.addresses.shortTokenSwapPath).deep.eq([]);

  expect(glvWithdrawal.numbers.glvTokenAmount).eq(0);
  expect(glvWithdrawal.numbers.minLongTokenAmount).eq(0);
  expect(glvWithdrawal.numbers.minShortTokenAmount).eq(0);
  expect(glvWithdrawal.numbers.updatedAtTime).eq(0);
  expect(glvWithdrawal.numbers.executionFee).eq(0);
  expect(glvWithdrawal.numbers.callbackGasLimit).eq(0);

  expect(glvWithdrawal.flags.shouldUnwrapNativeToken).eq(false);
}

export function expectGlvWithdrawal(glvWithdrawal: any, expected: any) {
  ["glv", "market", "account", "receiver", "callbackContract", "uiFeeReceiver"].forEach((key) => {
    if (key in expected) {
      const value = expected[key].address ?? expected[key].marketToken ?? expected[key];
      expect(glvWithdrawal.addresses[key], key).eq(value);
    }
  });

  ["longTokenSwapPath", "shortTokenSwapPath"].forEach((key) => {
    if (key in expected) {
      expect(glvWithdrawal.addresses[key], key).deep.eq(expected[key]);
    }
  });

  [
    "glvTokenAmount",
    "minLongTokenAmount",
    "minShortTokenAmount",
    "updatedAtTime",
    "executionFee",
    "callbackGasLimit",
  ].forEach((key) => {
    if (key in expected) {
      expect(glvWithdrawal.numbers[key], key).eq(expected[key]);
    }
  });

  ["shouldUnwrapNativeToken"].forEach((key) => {
    if (key in expected) {
      expect(glvWithdrawal.flags[key], key).eq(expected[key]);
    }
  });
}
