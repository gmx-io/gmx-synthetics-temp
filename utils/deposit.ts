import { expect } from "chai";
import { logGasUsage } from "./gas";
import { expandDecimals, bigNumberify } from "./math";
import { executeWithOracleParams } from "./exchange";
import { contractAt } from "./deploy";
import { parseLogs } from "./event";
import { getCancellationReason, getErrorString } from "./error";

import * as keys from "./keys";

export function getDepositCount(dataStore) {
  return dataStore.getBytes32Count(keys.DEPOSIT_LIST);
}

export function getDepositKeys(dataStore, start, end) {
  return dataStore.getBytes32ValuesAt(keys.DEPOSIT_LIST, start, end);
}

export function getAccountDepositCount(dataStore, account) {
  return dataStore.getBytes32Count(keys.accountDepositListKey(account));
}

export function getAccountDepositKeys(dataStore, account, start, end) {
  return dataStore.getBytes32ValuesAt(keys.accountDepositListKey(account), start, end);
}

export async function createDeposit(fixture, overrides: any = {}) {
  const { depositVault, depositHandler, wnt, ethUsdMarket } = fixture.contracts;
  const { wallet, user0 } = fixture.accounts;

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
  const minMarketTokens = overrides.minMarketTokens || bigNumberify(0);
  const shouldUnwrapNativeToken = overrides.shouldUnwrapNativeToken || false;
  const executionFee = overrides.executionFee || "1000000000000000";
  const executionFeeToMint = overrides.executionFeeToMint || executionFee;
  const callbackGasLimit = overrides.callbackGasLimit || bigNumberify(0);
  const longTokenAmount = overrides.longTokenAmount || bigNumberify(0);
  const shortTokenAmount = overrides.shortTokenAmount || bigNumberify(0);
  const chainId = overrides.chainId || bigNumberify(0);
  const dataList = overrides.dataList || [];

  await wnt.mint(depositVault.address, executionFeeToMint);

  if (longTokenAmount.gt(0)) {
    const _initialLongToken = await contractAt("MintableToken", initialLongToken);
    await _initialLongToken.mint(depositVault.address, longTokenAmount);
  }

  if (shortTokenAmount.gt(0)) {
    const _initialShortToken = await contractAt("MintableToken", initialShortToken);
    await _initialShortToken.mint(depositVault.address, shortTokenAmount);
  }

  const params = {
    receiver: receiver.address,
    callbackContract: callbackContract.address,
    uiFeeReceiver: uiFeeReceiver.address,
    market: market.marketToken,
    initialLongToken,
    initialShortToken,
    longTokenSwapPath,
    shortTokenSwapPath,
    minMarketTokens,
    shouldUnwrapNativeToken,
    executionFee,
    callbackGasLimit,
    chainId,
    dataList,
  };

  const txReceipt = await logGasUsage({
    tx: depositHandler.connect(sender).createDeposit(account.address, params),
    label: overrides.gasUsageLabel,
  });

  const result = { txReceipt };
  return result;
}

export async function executeDeposit(fixture, overrides: any = {}) {
  const { dataStore, depositHandler, wnt, usdc } = fixture.contracts;
  const { gasUsageLabel } = overrides;
  const tokens = overrides.tokens || [wnt.address, usdc.address];
  const precisions = overrides.precisions || [8, 18];
  const minPrices = overrides.minPrices || [expandDecimals(5000, 4), expandDecimals(1, 6)];
  const maxPrices = overrides.maxPrices || [expandDecimals(5000, 4), expandDecimals(1, 6)];
  const depositKeys = await getDepositKeys(dataStore, 0, 1);
  const dataStreamTokens = overrides.dataStreamTokens || [];
  const dataStreamData = overrides.dataStreamData || [];
  const priceFeedTokens = overrides.priceFeedTokens || [];
  let depositKey = overrides.depositKey;
  let oracleBlockNumber = overrides.oracleBlockNumber;

  if (depositKeys.length > 0) {
    if (!depositKey) {
      depositKey = depositKeys[0];
    }
  }
  if (!oracleBlockNumber) {
    oracleBlockNumber = await ethers.provider.getBlockNumber();
  }

  const params = {
    key: depositKey,
    oracleBlockNumber,
    tokens,
    precisions,
    minPrices,
    maxPrices,
    execute: depositHandler.executeDeposit,
    gasUsageLabel,
    dataStreamTokens,
    dataStreamData,
    priceFeedTokens,
  };

  const txReceipt = await executeWithOracleParams(fixture, params);

  const logs = parseLogs(fixture, txReceipt);

  const cancellationReason = await getCancellationReason({
    logs,
    eventName: "DepositCancelled",
  });

  if (cancellationReason) {
    if (overrides.expectedCancellationReason) {
      expect(cancellationReason.name).eq(overrides.expectedCancellationReason);
    } else {
      throw new Error(`Deposit was cancelled: ${getErrorString(cancellationReason)}`);
    }
  } else {
    if (overrides.expectedCancellationReason) {
      throw new Error(
        `Deposit was not cancelled, expected cancellation with reason: ${overrides.expectedCancellationReason}`
      );
    }
  }

  const result = { txReceipt, logs };
  return result;
}

export async function handleDeposit(fixture, overrides: any = {}) {
  const createResult = await createDeposit(fixture, overrides.create);
  const executeResult = await executeDeposit(fixture, overrides.execute);
  return { createResult, executeResult };
}
