import { calculateCreate2 } from "eth-create2-calculator";
import { expandDecimals } from "./math";
import { hashData, hashString } from "./hash";
import { poolAmountKey, swapImpactPoolAmountKey } from "./keys";
import * as keys from "./keys";

import { ethers } from "ethers";

export const DEFAULT_MARKET_TYPE = hashString("basic-v1");

export function getMarketCount(dataStore) {
  return dataStore.getAddressCount(keys.MARKET_LIST);
}

export function getMarketKeys(dataStore, start, end) {
  return dataStore.getAddressValuesAt(keys.MARKET_LIST, start, end);
}

export async function getPoolAmount(dataStore, market, token) {
  const key = poolAmountKey(market, token);
  return await dataStore.getUint(key);
}

export async function getSwapImpactPoolAmount(dataStore, market, token) {
  const key = swapImpactPoolAmountKey(market, token);
  return await dataStore.getUint(key);
}

export async function getMarketTokenPrice(fixture, overrides: any = {}) {
  return (await getMarketTokenPriceWithPoolValue(fixture, overrides))[0];
}

export async function getMarketTokenPriceWithPoolValue(fixture, overrides: any = {}) {
  const { reader, dataStore, ethUsdMarket } = fixture.contracts;
  const market = overrides.market || ethUsdMarket;
  const pnlFactorType = overrides.pnlFactorType || keys.MAX_PNL_FACTOR_FOR_TRADERS;

  const overridePrices = overrides.prices || {};

  const indexTokenPrice = overridePrices.indexTokenPrice || {
    min: expandDecimals(5000, 4 + 8),
    max: expandDecimals(5000, 4 + 8),
  };

  const longTokenPrice = overridePrices.longTokenPrice || {
    min: expandDecimals(5000, 4 + 8),
    max: expandDecimals(5000, 4 + 8),
  };

  const shortTokenPrice = overridePrices.shortTokenPrice || {
    min: expandDecimals(1, 6 + 18),
    max: expandDecimals(1, 6 + 18),
  };

  const maximize = overrides.maximize === undefined ? true : overrides.maximize;

  return await reader.getMarketTokenPrice(
    dataStore.address,
    market,
    indexTokenPrice,
    longTokenPrice,
    shortTokenPrice,
    pnlFactorType,
    maximize
  );
}

export function getMarketTokenAddress(
  indexToken: string,
  longToken: string,
  shortToken: string,
  marketType: string,
  marketFactoryAddress: string,
  roleStoreAddress: string,
  dataStoreAddress: string
): string {
  const salt = hashData(
    ["string", "address", "address", "address", "bytes32"],
    ["GMX_MARKET", indexToken, longToken, shortToken, marketType]
  );
  // eslint-disable-next-line
  const MarketTokenArtifact = require("../artifacts/contracts/market/MarketToken.sol/MarketToken.json");
  const byteCode = MarketTokenArtifact.bytecode;
  return calculateCreate2(marketFactoryAddress, salt, byteCode, {
    params: [roleStoreAddress, dataStoreAddress],
    types: ["address", "address"],
  });
}

export function getMarketKey(indexToken: string, longToken: string, shortToken: string) {
  return [indexToken, longToken, shortToken].join(":");
}

export function createMarketConfigByKey({ marketConfigs, tokens }) {
  const marketConfigByKey = {};

  for (const marketConfig of marketConfigs) {
    const [indexToken, longToken, shortToken] = getMarketTokenAddresses(marketConfig, tokens);
    const marketKey = getMarketKey(indexToken, longToken, shortToken);
    marketConfigByKey[marketKey] = marketConfig;
  }

  return marketConfigByKey;
}

export async function getOnchainMarkets(
  read: (...args: any[]) => any,
  dataStoreAddress: string
): Promise<
  Record<
    string,
    {
      indexToken: string;
      longToken: string;
      shortToken: string;
      marketToken: string;
    }
  >
> {
  const onchainMarkets = await read("Reader", "getMarkets", dataStoreAddress, 0, 1000);
  return Object.fromEntries(
    onchainMarkets.map((market) => {
      const { indexToken, longToken, shortToken } = market;
      const marketKey = getMarketKey(indexToken, longToken, shortToken);
      return [marketKey, market];
    })
  );
}

export function getMarketTokenAddresses(marketConfig, tokens) {
  if (!marketConfig.swapOnly && !tokens[marketConfig.tokens.indexToken]) {
    throw new Error("invalid indexToken");
  }

  if (!tokens[marketConfig.tokens.longToken]) {
    throw new Error("invalid longToken");
  }

  if (!tokens[marketConfig.tokens.shortToken]) {
    throw new Error("invalid shortToken");
  }

  const indexToken = marketConfig.swapOnly
    ? ethers.constants.AddressZero
    : tokens[marketConfig.tokens.indexToken].address;
  const longToken = tokens[marketConfig.tokens.longToken].address;
  const shortToken = tokens[marketConfig.tokens.shortToken].address;
  return [indexToken, longToken, shortToken];
}
