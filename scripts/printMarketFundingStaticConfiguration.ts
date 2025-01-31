import hre from "hardhat";
import { bigNumberify, formatAmount } from "../utils/math";
import { getMarketKey, getMarketTokenAddresses, getOnchainMarkets } from "../utils/market";

async function main() {
  const tokens = await hre.gmx.getTokens();
  const markets = await hre.gmx.getMarkets();
  const dataStore = await hre.ethers.getContract("DataStore");
  const read = hre.deployments.read;
  const onchainMarketsByTokens = await getOnchainMarkets(read, dataStore.address);
  const addressToSymbol: { [address: string]: string } = {};
  for (const [tokenSymbol, tokenConfig] of Object.entries(tokens)) {
    let address = tokenConfig.address;
    if (!address) {
      address = (await hre.ethers.getContract(tokenSymbol)).address;
    }
    addressToSymbol[address] = tokenSymbol;
  }

  for (const market of markets) {
    if (!market.tokens.indexToken) {
      continue;
    }
    const marketToken = getMarketToken(market, tokens, onchainMarketsByTokens);
    const maxFundingRate = Math.round(
      formatAmount(bigNumberify(market.maxFundingFactorPerSecond).mul(86400).mul(365).mul(100), 30, 2)
    );
    const maxFundingRateFloor = maxFundingRate / 100 - 0.1;
    const maxFundingRateCap = maxFundingRate / 100 + 0.2;
    console.log('"%s": {', marketToken);
    console.log("  // %s/USD [%s-%s]", market.tokens.indexToken, market.tokens.longToken, market.tokens.shortToken);
    console.log('  "maxFundingRateFloor": %s / HOURS_PER_YEAR,', maxFundingRateFloor);
    console.log('  "maxFundingRateCap": %s / HOURS_PER_YEAR,', maxFundingRateCap);
    console.log("},");
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

function getMarketToken(market, tokens, onchainMarketsByTokens) {
  const [indexToken, longToken, shortToken] = getMarketTokenAddresses(market, tokens);
  const marketKey = getMarketKey(indexToken, longToken, shortToken);
  const onchainMarket = onchainMarketsByTokens[marketKey];
  return onchainMarket.marketToken;
}
