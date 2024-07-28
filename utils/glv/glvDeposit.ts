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
  const { glvVault, glvHandler, wnt, ethUsdMarket, ethUsdGlvAddress } = fixture.contracts;
  const { wallet, user0 } = fixture.accounts;

  const gasUsageLabel = overrides.gasUsageLabel || "createGlvWithdrawal";
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
  const minGlvTokens = overrides.minGlvTokens || bigNumberify(0);
  const shouldUnwrapNativeToken = overrides.shouldUnwrapNativeToken || false;
  const executionFee = overrides.executionFee || "1000000000000000";
  const executionFeeToMint = overrides.executionFeeToMint || executionFee;
  const callbackGasLimit = overrides.callbackGasLimit || bigNumberify(0);
  const marketTokenAmount = overrides.marketTokenAmount || bigNumberify(0);
  const longTokenAmount = overrides.longTokenAmount || bigNumberify(0);
  const shortTokenAmount = overrides.shortTokenAmount || bigNumberify(0);
  const isMarketTokenDeposit = overrides.isMarketTokenDeposit || false;

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
  };

  for (const [key, value] of Object.entries(params)) {
    if (value === undefined) {
      throw new Error(`param "${key}" is undefined`);
    }
  }

  const txReceipt = await logGasUsage({
    tx: glvHandler.connect(sender).createGlvDeposit(account.address, params),
    label: gasUsageLabel,
  });

  const result = { txReceipt };
  return result;
}

export async function executeGlvDeposit(fixture, overrides: any = {}) {
  const { glvReader, dataStore, glvHandler, wnt, usdc, sol } = fixture.contracts;
  const gasUsageLabel = overrides.gasUsageLabel || "executeGlvWithdrawal";
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
    if (!oracleBlockNumber) {
      const glvDeposit = await glvReader.getGlvDeposit(dataStore.address, glvDepositKeys[0]);
      oracleBlockNumber = glvDeposit.numbers.updatedAtBlock;
    }
  }

  const params: any = {
    key: glvDepositKey,
    tokens,
    precisions,
    minPrices,
    maxPrices,
    execute: glvHandler.executeGlvDeposit,
    simulateExecute: glvHandler.simulateExecuteGlvDeposit,
    simulate: overrides.simulate,
    gasUsageLabel,
    dataStreamTokens,
    dataStreamData,
    priceFeedTokens,
    oracleBlockNumber,
  };

  const txReceipt = await executeWithOracleParams(fixture, params);

  const logs = parseLogs(fixture, txReceipt);

  const cancellationReason = await getCancellationReason({
    logs,
    eventName: "GlvDepositCancelled",
  });

  expectCancellationReason(cancellationReason, overrides.expectedCancellationReason, "GlvDeposit");

  const result = { txReceipt, logs };
  return result;
}

export async function handleGlvDeposit(fixture, overrides: any = {}) {
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
  expect(glvDeposit.numbers.updatedAtBlock).eq(0);
  expect(glvDeposit.numbers.updatedAtTime).eq(0);
  expect(glvDeposit.numbers.executionFee).eq(0);
  expect(glvDeposit.numbers.callbackGasLimit).eq(0);

  expect(glvDeposit.flags.shouldUnwrapNativeToken).eq(false);
  expect(glvDeposit.flags.isMarketTokenDeposit).eq(false);
}
