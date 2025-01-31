import hre from "hardhat";
import prompts from "prompts";

import * as keys from "../utils/keys";

async function main() {
  const oracleConfig = await hre.gmx.getOracle();

  const dataStore = await hre.ethers.getContract("DataStore");
  const config = await hre.ethers.getContract("Config");

  for (const [key, value] of Object.entries(oracleConfig)) {
    console.log("%s: %s", key, value);
  }

  let hasUpdates = false;
  for (const [key, configKey] of [
    [keys.MAX_ORACLE_PRICE_AGE, "maxOraclePriceAge"],
    [keys.MAX_ORACLE_TIMESTAMP_RANGE, "maxOracleTimestampRange"],
  ]) {
    const newValue = oracleConfig[configKey];
    const oldValue = await dataStore.getUint(key);

    if (newValue.toString() !== oldValue.toString()) {
      hasUpdates = true;
      console.log("updated value for %s: %s -> %s", configKey, oldValue, newValue);
    }
  }

  if (!hasUpdates) {
    console.log("all parameters are up to date");
    return;
  }

  let write = process.env.WRITE === "true";
  if (!write) {
    ({ write } = await prompts({
      type: "confirm",
      name: "write",
      message: "Do you want to execute the transactions?",
    }));
  }

  if (write) {
    for (const [key, configKey] of [
      [keys.MAX_ORACLE_PRICE_AGE, "maxOraclePriceAge"],
      [keys.MAX_ORACLE_TIMESTAMP_RANGE, "maxOracleTimestampRange"],
    ]) {
      const newValue = oracleConfig[configKey];
      const oldValue = await dataStore.getUint(key);

      if (newValue.toString() !== oldValue.toString()) {
        if (write) {
          console.log("sending transaction...");
          const tx = await config.setUint(key, "0x", newValue);
          console.log("tx sent: %s", tx.hash);
        }
      }
    }
  } else {
    console.log("NOTE: executed in read-only mode, no transactions were sent");
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
