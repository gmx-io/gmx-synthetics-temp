import hre from "hardhat";

import * as keys from "../utils/keys";

const { ethers } = hre;

async function main() {
  const dataStore = await ethers.getContract("DataStore");

  const maxOracleRefPriceDeviationFactor = await dataStore.getUint(keys.MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR);
  console.log("maxOracleRefPriceDeviationFactor", maxOracleRefPriceDeviationFactor.toString());
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((ex) => {
    console.error(ex);
    process.exit(1);
  });
