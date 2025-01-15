import got from "got";
import hre from "hardhat";
import { bigNumberify, expandDecimals, formatAmount } from "../utils/math";

function getOracleAbi() {
  if (hre.network.name === "arbitrum") {
    return "https://arbitrum-api.gmxinfra.io/";
  } else if (hre.network.name === "avalanche") {
    return "https://avalanche-api.gmxinfra.io/";
  }
  throw new Error("Unsupported network");
}

async function getTickers() {
  const tickers: any[] = await got(`${getOracleAbi()}prices/tickers`).json();

  return Object.fromEntries(
    tickers.map((ticker) => {
      return [ticker.tokenAddress, ticker];
    })
  );
}

function getPriceProp(ticker) {
  return {
    min: ticker.minPrice,
    max: ticker.maxPrice,
  };
}

async function main() {
  const marketFromAddress = "0x6853EA96FF216fAb11D2d930CE3C508556A4bdc4"; // DOGE
  const marketToAddress = "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336"; // ETH
  const blockNumber = await hre.ethers.provider.getBlockNumber();
  console.log("blockNumber", blockNumber);

  const dataStore = await hre.ethers.getContract("DataStore");
  const reader = await hre.ethers.getContract("Reader");

  const [tickers, marketFrom, marketTo] = await Promise.all([
    getTickers(),
    reader.getMarket(dataStore.address, marketFromAddress),
    reader.getMarket(dataStore.address, marketToAddress),
  ]);

  const marketFromPrices = {
    indexTokenPrice: getPriceProp(tickers[marketFrom.indexToken]),
    longTokenPrice: getPriceProp(tickers[marketFrom.longToken]),
    shortTokenPrice: getPriceProp(tickers[marketFrom.shortToken]),
  };

  const [marketFromTokenPriceOnchain] = await reader.getMarketTokenPrice(
    dataStore.address,
    marketFrom,
    marketFromPrices.indexTokenPrice,
    marketFromPrices.longTokenPrice,
    marketFromPrices.shortTokenPrice,
    "0xdd8747ceca84c84319e46661e0ee4095cc511df8c2208b6ff4e9d2b2e6930bb6", // MAX_PNL_FACTOR_FOR_WITHDRAWALS
    false,
    { blockTag: blockNumber }
  );
  console.log("marketFromTokenPriceOnchain $%s", formatAmount(marketFromTokenPriceOnchain, 30));
  const marketFromAmountIn = expandDecimals(1000, 18);
  const marketFromAmountInUsd = marketFromAmountIn.mul(marketFromTokenPriceOnchain).div(expandDecimals(1, 18));
  console.log("marketFromAmountInUsd $%s", formatAmount(marketFromAmountInUsd, 30));

  const withdrawalOutput = await reader.getWithdrawalAmountOut(
    dataStore.address,
    marketFrom,
    marketFromPrices,
    marketFromAmountIn,
    hre.ethers.constants.AddressZero,
    bigNumberify(1), // SwapPricingType.Shift
    { blockTag: blockNumber }
  );

  console.log(
    "withdrawalOutput %s ETH %s USDC",
    formatAmount(withdrawalOutput[0], 18),
    formatAmount(withdrawalOutput[1], 6)
  );

  const marketToPrices = {
    indexTokenPrice: getPriceProp(tickers[marketTo.indexToken]),
    longTokenPrice: getPriceProp(tickers[marketTo.longToken]),
    shortTokenPrice: getPriceProp(tickers[marketTo.shortToken]),
  };

  const depositOutput = await reader.getDepositAmountOut(
    dataStore.address,
    marketTo,
    marketToPrices,
    withdrawalOutput[0],
    withdrawalOutput[1],
    hre.ethers.constants.AddressZero,
    bigNumberify(1), // SwapPricingType.Shift
    false, // includeVirtualInventoryImpact
    { blockTag: blockNumber }
  );

  console.log("depositOutput %s GM", formatAmount(depositOutput, 18));

  const [marketToTokenPriceOnchain] = await reader.getMarketTokenPrice(
    dataStore.address,
    marketTo,
    marketToPrices.indexTokenPrice,
    marketToPrices.longTokenPrice,
    marketToPrices.shortTokenPrice,
    "0xf806434c19658de952949276d3592c470dbe9a4accb46625a589f92a87b96e2a", // MAX_PNL_FACTOR_FOR_DEPOSITS
    true,
    { blockTag: blockNumber }
  );
  const marketToAmountOutUsd = depositOutput.mul(marketToTokenPriceOnchain).div(expandDecimals(1, 18));
  console.log("marketToAmountOutUsd $%s", formatAmount(marketToAmountOutUsd, 30));

  const priceImpactUsd = marketToAmountOutUsd.sub(marketFromAmountInUsd);
  const priceImpactPercent = priceImpactUsd.mul(expandDecimals(1, 30)).div(marketToAmountOutUsd);
  console.log("priceImpact $%s (%s%)", formatAmount(priceImpactUsd, 30), formatAmount(priceImpactPercent, 28));
}

main()
  .then(() => {
    console.log("done");
    process.exit(0);
  })
  .catch((ex) => {
    console.error(ex);
    process.exit(1);
  });
