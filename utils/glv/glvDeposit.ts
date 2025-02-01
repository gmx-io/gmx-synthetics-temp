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

export function getGlvDepositKeys(dataStore, start, end) {
  return dataStore.getBytes32ValuesAt(keys.GLV_DEPOSIT_LIST, start, end);
}

export function getGlvDepositCount(dataStore) {
  return dataStore.getBytes32Count(keys.GLV_DEPOSIT_LIST);
}

export function getAccountGlvDepositCount(dataStore, account) {
  return dataStore.getBytes32Count(keys.accountGlvDepositListKey(account));
}

export function getAccountGlvDepositKeys(dataStore, account, start, end) {
  return dataStore.getBytes32ValuesAt(keys.accountGlvDepositListKey(account), start, end);
}

export async function createGlvDeposit(fixture, overrides: any = {}) {
  const { glvVault, glvRouter, glvHandler, wnt, ethUsdMarket, ethUsdGlvAddress } = fixture.contracts;
  const { wallet, user0 } = fixture.accounts;

  const gasUsageLabel = overrides.gasUsageLabel;
  const glv = overrides.glv || ethUsdGlvAddress;
  const sender = overrides.sender || wallet;
  const account = overrides.account || user0;
  const receiver = overrides.receiver || account;
  const callbackContract = overrides.callbackContract || { address: ethers.constants.AddressZero };
  const uiFeeReceiver = overrides.uiFeeReceiver || { address: ethers.constants.AddressZero };
  const market = overrides.market || ethUsdMarket;
  const initialLongToken = overrides.initialLongToken || market.longToken;
  const initialShortToken = overrides.initialShortToken || market.shortToken;
  const longTokenSwapPath = overrides.longTokenSwapPath || [];
  const shortTokenSwapPath = overrides.shortTokenSwapPath || [];
  const minGlvTokens = bigNumberify(overrides.minGlvTokens ?? 0);
  const shouldUnwrapNativeToken = overrides.shouldUnwrapNativeToken || false;
  const executionFee = bigNumberify(overrides.executionFee ?? "1000000000000000");
  const callbackGasLimit = bigNumberify(overrides.callbackGasLimit ?? 0);
  const marketTokenAmount = bigNumberify(overrides.marketTokenAmount ?? 0);
  const longTokenAmount = bigNumberify(overrides.longTokenAmount ?? 0);
  const shortTokenAmount = bigNumberify(overrides.shortTokenAmount ?? 0);
  const isMarketTokenDeposit = overrides.isMarketTokenDeposit || false;
  const useGlvHandler = Boolean(overrides.useGlvHandler) || false;
  const dataList = overrides.dataList || [];

  const executionFeeToMint = bigNumberify(overrides.executionFeeToMint ?? executionFee);
  await wnt.mint(glvVault.address, executionFeeToMint);

  if (marketTokenAmount.gt(0)) {
    const _marketToken = await contractAt("MintableToken", market.marketToken);
    const balance = await _marketToken.balanceOf(account.address);
    if (balance.lt(marketTokenAmount)) {
      await _marketToken.mint(account.address, marketTokenAmount.sub(balance));
      console.warn(
        "WARN: minting market tokens without depositing funds. market token price calculation could be incorrect"
      );
    }
    await _marketToken.connect(account).transfer(glvVault.address, marketTokenAmount);
  }

  if (longTokenAmount.gt(0)) {
    const _initialLongToken = await contractAt("MintableToken", initialLongToken);
    await _initialLongToken.mint(glvVault.address, longTokenAmount);
  }

  if (shortTokenAmount.gt(0)) {
    const _initialShortToken = await contractAt("MintableToken", initialShortToken);
    await _initialShortToken.mint(glvVault.address, shortTokenAmount);
  }

  const params = {
    glv,
    receiver: receiver.address,
    callbackContract: callbackContract.address,
    uiFeeReceiver: uiFeeReceiver.address,
    market: market.marketToken,
    initialLongToken,
    initialShortToken,
    longTokenSwapPath,
    shortTokenSwapPath,
    marketTokenAmount,
    minGlvTokens,
    shouldUnwrapNativeToken,
    executionFee,
    callbackGasLimit,
    isMarketTokenDeposit,
    gasUsageLabel,
    dataList,
  };

  const optionalParams = new Set(["gasUsageLabel", "simulate", "simulateExecute"]);
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined && !optionalParams.has(key)) {
      throw new Error(`param "${key}" is undefined`);
    }
  }

  const txReceipt = await logGasUsage({
    tx: useGlvHandler
      ? glvHandler.connect(sender).createGlvDeposit(account.address, params)
      : glvRouter.connect(account).createGlvDeposit(params),
    label: gasUsageLabel,
  });

  const result = { txReceipt };
  return result;
}

export async function executeGlvDeposit(fixture, overrides: any = {}) {
  const { dataStore, glvHandler, glvRouter, wnt, usdc, sol } = fixture.contracts;
  const gasUsageLabel = overrides.gasUsageLabel;
  const tokens = overrides.tokens || [wnt.address, usdc.address, sol.address];
  const precisions = overrides.precisions || [8, 18, 8];
  const minPrices = overrides.minPrices || [expandDecimals(5000, 4), expandDecimals(1, 6), expandDecimals(600, 4)];
  const maxPrices = overrides.maxPrices || [expandDecimals(5000, 4), expandDecimals(1, 6), expandDecimals(600, 4)];
  const glvDepositKeys = await getGlvDepositKeys(dataStore, 0, 1);
  const dataStreamTokens = overrides.dataStreamTokens || [];
  const dataStreamData = overrides.dataStreamData || [];
  const priceFeedTokens = overrides.priceFeedTokens || [];
  let glvDepositKey = overrides.key;
  let oracleBlockNumber = overrides.oracleBlockNumber;

  if (glvDepositKeys.length > 0) {
    if (!glvDepositKey) {
      glvDepositKey = glvDepositKeys[0];
    }
  }
  if (!oracleBlockNumber) {
    oracleBlockNumber = await ethers.provider.getBlockNumber();
  }

  const params: any = {
    key: glvDepositKey,
    tokens,
    precisions,
    minPrices,
    maxPrices,
    execute: glvHandler.executeGlvDeposit,
    simulateExecute: glvRouter.simulateExecuteGlvDeposit,
    simulate: overrides.simulate,
    dataStreamTokens,
    dataStreamData,
    priceFeedTokens,
    oracleBlockNumber,
  };
  if (gasUsageLabel) {
    params.gasUsageLabel = gasUsageLabel;
  }

  const txReceipt = await executeWithOracleParams(fixture, params);

  if (overrides.simulate) {
    return;
  }

  const logs = parseLogs(fixture, txReceipt);

  const cancellationReason = await getCancellationReason({
    logs,
    eventName: "GlvDepositCancelled",
  });

  expectCancellationReason(cancellationReason, overrides.expectedCancellationReason, "GlvDeposit");

  const result = { txReceipt, logs };
  return result;
}

export async function handleGlvDeposit(
  fixture,
  overrides: {
    create?: any;
    execute?: any;
  } = {}
) {
  const createResult = await createGlvDeposit(fixture, overrides.create);

  const createOverridesCopy = { ...overrides.create };
  delete createOverridesCopy.gasUsageLabel;
  const executeResult = await executeGlvDeposit(fixture, { ...createOverridesCopy, ...overrides.execute });

  return { createResult, executeResult };
}

export function expectEmptyGlvDeposit(glvDeposit: any) {
  expect(glvDeposit.addresses.glv).eq(AddressZero);
  expect(glvDeposit.addresses.account).eq(AddressZero);
  expect(glvDeposit.addresses.receiver).eq(AddressZero);
  expect(glvDeposit.addresses.callbackContract).eq(AddressZero);
  expect(glvDeposit.addresses.uiFeeReceiver).eq(AddressZero);
  expect(glvDeposit.addresses.market).eq(AddressZero);
  expect(glvDeposit.addresses.initialLongToken).eq(AddressZero);
  expect(glvDeposit.addresses.initialShortToken).eq(AddressZero);
  expect(glvDeposit.addresses.longTokenSwapPath).deep.eq([]);
  expect(glvDeposit.addresses.shortTokenSwapPath).deep.eq([]);

  expect(glvDeposit.numbers.marketTokenAmount).eq(0);
  expect(glvDeposit.numbers.initialLongTokenAmount).eq(0);
  expect(glvDeposit.numbers.initialShortTokenAmount).eq(0);
  expect(glvDeposit.numbers.minGlvTokens).eq(0);
  expect(glvDeposit.numbers.updatedAtTime).eq(0);
  expect(glvDeposit.numbers.executionFee).eq(0);
  expect(glvDeposit.numbers.callbackGasLimit).eq(0);

  expect(glvDeposit.flags.shouldUnwrapNativeToken).eq(false);
  expect(glvDeposit.flags.isMarketTokenDeposit).eq(false);
}

export function expectGlvDeposit(glvDeposit: any, expected: any) {
  [
    "glv",
    "account",
    "receiver",
    "callbackContract",
    "uiFeeReceiver",
    "market",
    "initialLongToken",
    "initialShortToken",
  ].forEach((key) => {
    if (key in expected) {
      const value = expected[key].address ?? expected[key].marketToken ?? expected[key];
      expect(glvDeposit.addresses[key], key).eq(value);
    }
  });

  ["longTokenSwapPath", "shortTokenSwapPath"].forEach((key) => {
    if (key in expected) {
      expect(glvDeposit.addresses[key], key).deep.eq(expected[key]);
    }
  });

  [
    "marketTokenAmount",
    "initialLongTokenAmount",
    "initialShortTokenAmount",
    "minGlvTokens",
    "updatedAtTime",
    "executionFee",
    "callbackGasLimit",
  ].forEach((key) => {
    if (key in expected) {
      expect(glvDeposit.numbers[key], key).eq(expected[key]);
    }
  });

  if (expected.longTokenAmount) {
    expect(glvDeposit.numbers.initialLongTokenAmount, "initialLongTokenAmount").eq(expected.longTokenAmount);
  }
  if (expected.shortTokenAmount) {
    expect(glvDeposit.numbers.initialShortTokenAmount, "initialShortTokenAmount").eq(expected.shortTokenAmount);
  }

  ["shouldUnwrapNativeToken", "isMarketTokenDeposit"].forEach((key) => {
    if (key in expected) {
      expect(glvDeposit.flags[key], key).eq(expected[key]);
    }
  });

  expect(glvDeposit._dataList).deep.eq(expected.dataList);
}
