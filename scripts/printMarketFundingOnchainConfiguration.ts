import hre from "hardhat";
import * as keys from "../utils/keys";
import { formatAmount } from "../utils/math";

async function main() {
  const tokens = await hre.gmx.getTokens();
  const addressToSymbol: { [address: string]: string } = {};
  for (const [tokenSymbol, tokenConfig] of Object.entries(tokens)) {
    let address = tokenConfig.address;
    if (!address) {
      address = (await hre.ethers.getContract(tokenSymbol)).address;
    }
    addressToSymbol[address] = tokenSymbol;
  }

  const reader = await hre.ethers.getContract("Reader");
  const dataStore = await hre.ethers.getContract("DataStore");
  console.log("reading data from DataStore %s Reader %s", dataStore.address, reader.address);
  const markets = [...(await reader.getMarkets(dataStore.address, 0, 100))];

  for (const [, market] of markets.entries()) {
    if (market.indexToken === hre.ethers.constants.AddressZero) {
      continue;
    }
    const indexTokenSymbol = addressToSymbol[market.indexToken];
    if (!indexTokenSymbol) {
      continue;
    }
    const longTokenSymbol = addressToSymbol[market.longToken];
    const shortTokenSymbol = addressToSymbol[market.shortToken];
    const [minFundingFactorPerSecondKey, maxFundingFactorPerSecondKey] = await Promise.all([
      dataStore.getUint(keys.minFundingFactorPerSecondKey(market.marketToken)),
      dataStore.getUint(keys.maxFundingFactorPerSecondKey(market.marketToken)),
    ]);
    console.log(
      "market: %s %s min funding rate %s max funding rate %s",
      market.marketToken,
      `(${indexTokenSymbol}/USD [${longTokenSymbol}/${shortTokenSymbol}])`.padEnd(25),
      formatAmount(minFundingFactorPerSecondKey.mul(86400).mul(365), 30, 2),
      formatAmount(maxFundingFactorPerSecondKey.mul(86400).mul(365), 30, 2)
    );
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
