import { setTimeout } from "timers/promises";
import { exec } from "child_process";
import { readJsonFile, writeJsonFile } from "../utils/file";
import { getExplorerUrl } from "../hardhat.config";

import hre from "hardhat";
import got from "got";

const apiKey = hre.network.config.verify.etherscan.apiKey;

// a custom argument file may be needed for complex arguments
// https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-verify#complex-arguments
//
// example:
// ARBISCAN_API_KEY=<api key> npx hardhat --network arbitrum verify --constructor-args ./verification/gov/govTimelockController.js --contract contracts/gov/GovTimelockController.sol:GovTimelockController 0x99Ff4D52e97813A1784bC4A1b37554DC3499D67e
async function getIsContractVerified(apiUrl: string, address: string) {
  try {
    const res: any = await got
      .get(`${apiUrl}api`, {
        searchParams: {
          module: "contract",
          action: "getabi",
          address,
          apikey: apiKey,
        },
      })
      .json();

    if (res.status !== "1") {
      if (res.result?.includes("rate limit reached")) {
        throw new Error("Rate limit reached");
      }
      if (res.result?.includes("Invalid API URL endpoint")) {
        throw new Error("Invalid API URL endpoint");
      }

      if (!res.result?.includes("Contract source code not verified")) {
        console.warn("%s: %s", res.message, res.result);
      }
    }

    return res.status === "1";
  } catch (e) {
    console.warn(`getIsContractVerified error: ${e}`);
    return false;
  }
}

function encodeArg(arg) {
  if (Array.isArray(arg)) {
    return `[${arg.map((item) => encodeArg(item))}]`;
  }

  if (typeof arg !== "string") {
    return arg;
  }

  return `"${arg}"`;
}

async function verifyForNetwork(verificationNetwork) {
  const apiUrl = getExplorerUrl(verificationNetwork);
  const cacheFilePath = `./scripts/cache/verification/${verificationNetwork}.json`;
  console.log("cacheFilePath", cacheFilePath);
  console.log("apiUrl", apiUrl);

  let cache = readJsonFile(cacheFilePath);
  if (cache === undefined) {
    cache = {};
  }

  const allDeployments = await hre.deployments.all();
  console.log("Verifying %s contracts", Object.keys(allDeployments).length);

  const unverifiedContracts = [];

  for (const [name, deployment] of Object.entries(allDeployments)) {
    const start = Date.now();
    const { address, args } = deployment;
    const argStr = args.map((arg) => encodeArg(arg)).join(" ");

    if (process.env.CONTRACT && process.env.CONTRACT !== name) {
      console.log("skip %s", name);
      continue;
    }

    try {
      let isContractVerified = cache[address];
      if (!isContractVerified) {
        await setTimeout(200);
        console.log(`checking contract verification ${address}`);
        isContractVerified = await getIsContractVerified(apiUrl, address);
      }

      if (isContractVerified) {
        console.log(`${name} already verified: ${address}`);
        continue;
      }

      console.log("Verifying contract %s %s %s", name, address, argStr);
      const metadata = JSON.parse(deployment.metadata);
      const contractFQN = `${Object.keys(metadata.settings.compilationTarget)[0]}:${name}`;
      const contractArg = `--contract ${contractFQN}`;

      console.log("command", `npx hardhat verify ${contractArg} --network ${verificationNetwork} ${address} ${argStr}`);
      await new Promise((resolve, reject) => {
        exec(
          `npx hardhat verify ${contractArg} --network ${verificationNetwork} ${address} ${argStr}`,
          (ex, stdout, stderr) => {
            if (ex) {
              reject(ex);
              return;
            }
            if (stderr) {
              reject(stderr);
              return;
            }
            resolve(stdout);
          }
        );
      });
      console.log("Verified contract %s %s in %ss", name, address, (Date.now() - start) / 1000);
      cache[address] = true;
    } catch (ex) {
      unverifiedContracts.push({
        address,
        error: ex,
      });
      console.error("Failed to verify contract %s in %ss", address, (Date.now() - start) / 1000);
      console.error(ex);
    }
  }

  writeJsonFile(cacheFilePath, cache);

  if (unverifiedContracts.length > 0) {
    console.log(`${unverifiedContracts.length} contracts were not verified`);
    console.log(`-------`);
    for (let i = 0; i < unverifiedContracts.length; i++) {
      const unverifiedContract = unverifiedContracts[i];
      console.log(`${i + 1}: ${unverifiedContract.address}`);
    }
    console.log(`-------`);
    for (let i = 0; i < unverifiedContracts.length; i++) {
      const unverifiedContract = unverifiedContracts[i];
      console.log(`${i + 1}: ${unverifiedContract.address}`);
      console.log(`Error: ${unverifiedContract.error}`);
    }
  }
  console.log("Done");
}

async function main() {
  const networkName = process.env.VERIFICATION_NETWORK ? process.env.VERIFICATION_NETWORK : hre.network.name;

  if (networkName === "avalanche") {
    await verifyForNetwork("avalanche");
    // await verifyForNetwork("snowscan");
  } else {
    await verifyForNetwork(networkName);
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
