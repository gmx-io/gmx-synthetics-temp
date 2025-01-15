import got from "got";
import hre from "hardhat";
import { formatAmount } from "../utils/math";

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
      return [ticker.tokenAddress, getPriceProp(ticker)];
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
  const tokens = await hre.gmx.getTokens();
  const tickers = await getTickers();

  const glvReader = await hre.ethers.getContract("GlvReader");
  const dataStore = await hre.ethers.getContract("DataStore");
  const reader = await hre.ethers.getContract("Reader");
  const markets = await reader.getMarkets(dataStore.address, 0, 100);
  const marketToIndexToken = Object.fromEntries(markets.map((market) => [market.marketToken, market.indexToken]));

  const addressToSymbol: { [address: string]: string } = {};
  for (const [tokenSymbol, tokenConfig] of Object.entries(tokens) as any) {
    let address = tokenConfig.address;
    if (!address) {
      address = (await hre.ethers.getContract(tokenSymbol)).address;
    }
    addressToSymbol[address] = tokenSymbol;
  }

  console.log("reading data from DataStore %s Reader %s", dataStore.address, glvReader.address);
  const glvInfoList = [...(await glvReader.getGlvInfoList(dataStore.address, 0, 100))];

  for (const glvInfo of glvInfoList) {
    const longTokenPrice = tickers[glvInfo.glv.longToken];
    const shortTokenPrice = tickers[glvInfo.glv.shortToken];
    const indexTokenPrices = glvInfo.markets.map((marketToken) => tickers[marketToIndexToken[marketToken]]);

    const params = [
      dataStore.address,
      glvInfo.markets,
      indexTokenPrices,
      longTokenPrice,
      shortTokenPrice,
      glvInfo.glv.glvToken,
      true,
    ];

    const [glvTokenPrice, glvValue] = await glvReader.getGlvTokenPrice(...params);
    console.log("glv token price: $%s value: $%s", formatAmount(glvTokenPrice, 30), formatAmount(glvValue, 30));
  }
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((ex) => {
    console.error(ex);
    process.exit(1);
  });
