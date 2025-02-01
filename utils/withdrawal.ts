import { expect } from "chai";
import { logGasUsage } from "./gas";
import { contractAt } from "./deploy";
import { expandDecimals, bigNumberify } from "./math";
import { executeWithOracleParams } from "./exchange";
import { parseLogs } from "./event";
import { getCancellationReason, getErrorString } from "./error";

import * as keys from "./keys";

export function getWithdrawalCount(dataStore) {
  return dataStore.getBytes32Count(keys.WITHDRAWAL_LIST);
}

export function getWithdrawalKeys(dataStore, start, end) {
  return dataStore.getBytes32ValuesAt(keys.WITHDRAWAL_LIST, start, end);
}

export function getAccountWithdrawalCount(dataStore, account) {
  return dataStore.getBytes32Count(keys.accountWithdrawalListKey(account));
}

export function getAccountWithdrawalKeys(dataStore, account, start, end) {
  return dataStore.getBytes32ValuesAt(keys.accountWithdrawalListKey(account), start, end);
}

export async function createWithdrawal(fixture, overrides: any = {}) {
  const { withdrawalVault, withdrawalHandler, wnt, ethUsdMarket } = fixture.contracts;
  const { wallet, user0 } = fixture.accounts;

  const account = overrides.account || user0;
  const receiver = overrides.receiver || account;
  const callbackContract = overrides.callbackContract || { address: ethers.constants.AddressZero };
  const uiFeeReceiver = overrides.uiFeeReceiver || { address: ethers.constants.AddressZero };
  const market = overrides.market || ethUsdMarket;
  const longTokenSwapPath = overrides.longTokenSwapPath || [];
  const shortTokenSwapPath = overrides.shortTokenSwapPath || [];
  const marketTokenAmount = overrides.marketTokenAmount || bigNumberify(0);
  const minLongTokenAmount = overrides.minLongTokenAmount || bigNumberify(0);
  const minShortTokenAmount = overrides.minShortTokenAmount || bigNumberify(0);
  const shouldUnwrapNativeToken = overrides.shouldUnwrapNativeToken || false;
  const executionFee = overrides.executionFee || "1000000000000000";
  const callbackGasLimit = overrides.callbackGasLimit || bigNumberify(0);
  const dataList = overrides.dataList || [];

  await wnt.mint(withdrawalVault.address, executionFee);

  const marketToken = await contractAt("MarketToken", market.marketToken);
  await marketToken.connect(account).transfer(withdrawalVault.address, marketTokenAmount);

  const params = {
    receiver: receiver.address,
    callbackContract: callbackContract.address,
    uiFeeReceiver: uiFeeReceiver.address,
    market: market.marketToken,
    longTokenSwapPath,
    shortTokenSwapPath,
    marketTokenAmount,
    minLongTokenAmount,
    minShortTokenAmount,
    shouldUnwrapNativeToken,
    executionFee,
    callbackGasLimit,
    dataList,
  };

  await logGasUsage({
    tx: withdrawalHandler.connect(wallet).createWithdrawal(account.address, params),
    label: overrides.gasUsageLabel,
  });
}

export async function executeWithdrawal(fixture, overrides: any = {}) {
  const { dataStore, withdrawalHandler, wnt, usdc } = fixture.contracts;
  const { gasUsageLabel } = overrides;
  const tokens = overrides.tokens || [wnt.address, usdc.address];
  const dataStreamTokens = overrides.dataStreamTokens || [];
  const dataStreamData = overrides.dataStreamData || [];
  const priceFeedTokens = overrides.priceFeedTokens || [];
  const precisions = overrides.precisions || [8, 18];
  const minPrices = overrides.minPrices || [expandDecimals(5000, 4), expandDecimals(1, 6)];
  const maxPrices = overrides.maxPrices || [expandDecimals(5000, 4), expandDecimals(1, 6)];
  const withdrawalKeys = await getWithdrawalKeys(dataStore, 0, 1);

  const params = {
    key: withdrawalKeys[0],
    oracleBlockNumber: await ethers.provider.getBlockNumber(),
    tokens,
    precisions,
    minPrices,
    maxPrices,
    execute: withdrawalHandler.executeWithdrawal,
    gasUsageLabel,
    dataStreamTokens,
    dataStreamData,
    priceFeedTokens,
  };

  const txReceipt = await executeWithOracleParams(fixture, params);
  const logs = parseLogs(fixture, txReceipt);

  const cancellationReason = await getCancellationReason({
    logs,
    eventName: "WithdrawalCancelled",
  });

  if (cancellationReason) {
    if (overrides.expectedCancellationReason) {
      expect(cancellationReason.name).eq(overrides.expectedCancellationReason);
    } else {
      throw new Error(`Withdrawal was cancelled: ${getErrorString(cancellationReason)}`);
    }
  } else {
    if (overrides.expectedCancellationReason) {
      throw new Error(
        `Withdrawal was not cancelled, expected cancellation with reason: ${overrides.expectedCancellationReason}`
      );
    }
  }

  const result = { txReceipt, logs };
  return result;
}

export async function executeAtomicWithdrawal(fixture, overrides: any = {}) {
  const { withdrawalVault, withdrawalHandler, wnt, usdc, ethUsdMarket, chainlinkPriceFeedProvider } = fixture.contracts;
  const { wallet, user0 } = fixture.accounts;

  const account = overrides.account || user0;
  const receiver = overrides.receiver || account;
  const callbackContract = overrides.callbackContract || { address: ethers.constants.AddressZero };
  const uiFeeReceiver = overrides.uiFeeReceiver || { address: ethers.constants.AddressZero };
  const market = overrides.market || ethUsdMarket;
  const longTokenSwapPath = overrides.longTokenSwapPath || [];
  const shortTokenSwapPath = overrides.shortTokenSwapPath || [];
  const marketTokenAmount = overrides.marketTokenAmount || bigNumberify(0);
  const minLongTokenAmount = overrides.minLongTokenAmount || bigNumberify(0);
  const minShortTokenAmount = overrides.minShortTokenAmount || bigNumberify(0);
  const shouldUnwrapNativeToken = overrides.shouldUnwrapNativeToken || false;
  const executionFee = overrides.executionFee || "1000000000000000";
  const callbackGasLimit = overrides.callbackGasLimit || bigNumberify(0);
  const dataList = overrides.dataList || [];

  await wnt.mint(withdrawalVault.address, executionFee);

  const marketToken = await contractAt("MarketToken", market.marketToken);
  await marketToken.connect(account).transfer(withdrawalVault.address, marketTokenAmount);

  const params = {
    receiver: receiver.address,
    callbackContract: callbackContract.address,
    uiFeeReceiver: uiFeeReceiver.address,
    market: market.marketToken,
    longTokenSwapPath,
    shortTokenSwapPath,
    marketTokenAmount,
    minLongTokenAmount,
    minShortTokenAmount,
    shouldUnwrapNativeToken,
    executionFee,
    callbackGasLimit,
    dataList,
  };

  let oracleParams = overrides.oracleParams;

  if (!oracleParams) {
    oracleParams = {
      tokens: [wnt.address, usdc.address],
      providers: [chainlinkPriceFeedProvider.address, chainlinkPriceFeedProvider.address],
      data: ["0x", "0x"],
    };
  }

  await logGasUsage({
    tx: withdrawalHandler.connect(wallet).executeAtomicWithdrawal(account.address, params, oracleParams),
    label: overrides.gasUsageLabel,
  });
}

export async function handleWithdrawal(fixture, overrides: { create?: any; execute?: any } = {}) {
  await createWithdrawal(fixture, overrides.create);
  await executeWithdrawal(fixture, overrides.execute);
}
