import dotenv from "dotenv";
dotenv.config();

import path from "path";
import fs from "fs";
import { ethers } from "ethers";

import { HardhatUserConfig, task, types } from "hardhat/config";
import "@nomicfoundation/hardhat-verify";
import "hardhat-contract-sizer";
import "solidity-coverage";
import "hardhat-gas-reporter";
import "hardhat-deploy";
import "@nomicfoundation/hardhat-chai-matchers";

import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";

// extends hre with gmx domain data
import "./config";

// add test helper methods
import "./utils/test";
import { updateGlvConfig } from "./scripts/updateGlvConfigUtils";
import { updateMarketConfig } from "./scripts/updateMarketConfigUtils";

const getRpcUrl = (network) => {
  const defaultRpcs = {
    arbitrum: "https://arb1.arbitrum.io/rpc",
    avalanche: "https://api.avax.network/ext/bc/C/rpc",
    arbitrumGoerli: "https://goerli-rollup.arbitrum.io/rpc",
    arbitrumSepolia: "https://sepolia-rollup.arbitrum.io/rpc",
    avalancheFuji: "https://api.avax-test.network/ext/bc/C/rpc",
    snowtrace: "https://api.avax.network/ext/bc/C/rpc",
    arbitrumBlockscout: "https://arb1.arbitrum.io/rpc",
  };

  let rpc = defaultRpcs[network];

  const filepath = path.join("./.rpcs.json");
  if (fs.existsSync(filepath)) {
    const data = JSON.parse(fs.readFileSync(filepath).toString());
    if (data[network]) {
      rpc = data[network];
    }
  }

  return rpc;
};

export const getExplorerUrl = (network) => {
  const urls = {
    arbitrum: "https://api.arbiscan.io/",
    avalanche: "https://api.snowtrace.io/",
    snowscan: "https://api.snowscan.xyz/",
    arbitrumGoerli: "https://api-goerli.arbiscan.io/",
    arbitrumSepolia: "https://api-sepolia.arbiscan.io/",
    avalancheFuji: "https://api-testnet.snowtrace.io/",
    arbitrumBlockscout: "https://arbitrum.blockscout.com/api",
  };

  const url = urls[network];
  if (!url) {
    throw new Error(`Empty explorer url for ${network}`);
  }

  return url;
};

const getEnvAccounts = (chainName?: string) => {
  const { ACCOUNT_KEY, ACCOUNT_KEY_FILE, ARBITRUM_SEPOLIA_ACCOUNT_KEY } = process.env;

  if (chainName === "arbitrumSepolia" && ARBITRUM_SEPOLIA_ACCOUNT_KEY) {
    return [ARBITRUM_SEPOLIA_ACCOUNT_KEY];
  }

  if (ACCOUNT_KEY) {
    return [ACCOUNT_KEY];
  }

  if (ACCOUNT_KEY_FILE) {
    const filepath = path.join("./keys/", ACCOUNT_KEY_FILE);
    const data = JSON.parse(fs.readFileSync(filepath));
    if (!data) {
      throw new Error("Invalid key file");
    }

    if (data.key) {
      return [data.key];
    }

    if (!data.mnemonic) {
      throw new Error("Invalid mnemonic");
    }

    const wallet = ethers.Wallet.fromMnemonic(data.mnemonic);
    return [wallet.privateKey];
  }

  return [];
};

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
        details: {
          constantOptimizer: true,
        },
      },
    },
  },
  networks: {
    hardhat: {
      saveDeployments: true,
      // forking: {
      //   url: `https://rpc.ankr.com/avalanche`,
      //   blockNumber: 33963320,
      // },
    },
    localhost: {
      saveDeployments: true,
    },
    arbitrum: {
      url: getRpcUrl("arbitrum"),
      chainId: 42161,
      accounts: getEnvAccounts(),
      verify: {
        etherscan: {
          apiUrl: getExplorerUrl("arbitrum"),
          apiKey: process.env.ARBISCAN_API_KEY,
        },
      },
      blockGasLimit: 20_000_000,
    },
    avalanche: {
      url: getRpcUrl("avalanche"),
      chainId: 43114,
      accounts: getEnvAccounts(),
      gasPrice: 200000000000,
      verify: {
        etherscan: {
          apiUrl: getExplorerUrl("avalanche"),
          apiKey: process.env.SNOWTRACE_API_KEY,
        },
      },
      blockGasLimit: 15_000_000,
    },
    snowscan: {
      url: getRpcUrl("avalanche"),
      chainId: 43114,
      accounts: getEnvAccounts(),
      gasPrice: 200000000000,
      verify: {
        etherscan: {
          apiUrl: getExplorerUrl("snowscan"),
          apiKey: process.env.SNOWTRACE_API_KEY,
        },
      },
      blockGasLimit: 15_000_000,
    },
    snowtrace: {
      url: getRpcUrl("snowtrace"),
      accounts: getEnvAccounts(),
    },
    arbitrumBlockscout: {
      url: getRpcUrl("arbitrumBlockscout"),
      accounts: getEnvAccounts(),
      verify: {
        etherscan: {
          apiUrl: getExplorerUrl("arbitrumBlockscout"),
          apiKey: "arbitrumBlockscout",
        },
      },
    },
    arbitrumGoerli: {
      url: getRpcUrl("arbitrumGoerli"),
      chainId: 421613,
      accounts: getEnvAccounts(),
      verify: {
        etherscan: {
          apiUrl: getExplorerUrl("arbitrumGoerli"),
          apiKey: process.env.ARBISCAN_API_KEY,
        },
      },
      blockGasLimit: 10000000,
    },
    arbitrumSepolia: {
      url: getRpcUrl("arbitrumSepolia"),
      chainId: 421614,
      accounts: getEnvAccounts("arbitrumSepolia"),
      verify: {
        etherscan: {
          apiUrl: getExplorerUrl("arbitrumSepolia"),
          apiKey: process.env.ARBISCAN_API_KEY,
        },
      },
      blockGasLimit: 10000000,
    },
    avalancheFuji: {
      url: getRpcUrl("avalancheFuji"),
      chainId: 43113,
      accounts: getEnvAccounts(),
      verify: {
        etherscan: {
          apiUrl: getExplorerUrl("avalancheFuji"),
          apiKey: process.env.SNOWTRACE_API_KEY,
        },
      },
      blockGasLimit: 2500000,
      // gasPrice: 50000000000,
    },
  },
  // hardhat-deploy has issues with some contracts
  // https://github.com/wighawag/hardhat-deploy/issues/264
  etherscan: {
    apiKey: {
      // hardhat-verify plugin uses "avalancheFujiTestnet" name
      arbitrumOne: process.env.ARBISCAN_API_KEY,
      avalanche: process.env.SNOWTRACE_API_KEY,
      arbitrumGoerli: process.env.ARBISCAN_API_KEY,
      arbitrumSepolia: process.env.ARBISCAN_API_KEY,
      avalancheFujiTestnet: process.env.SNOWTRACE_API_KEY,
      snowtrace: "snowtrace", // apiKey is not required, just set a placeholder
      arbitrumBlockscout: "arbitrumBlockscout",
    },
    customChains: [
      {
        network: "snowtrace",
        chainId: 43114,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan",
          browserURL: "https://avalanche.routescan.io",
        },
      },
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://https://sepolia.arbiscan.io/",
        },
      },
      // {
      //   network: "arbitrumBlockscout",
      //   chainId: 42161,
      //   urls: {
      //     apiURL: "https://arbitrum.blockscout.com/api",
      //     browserURL: "https://arbitrum.blockscout.com",
      //   },
      // },
    ],
  },
  sourcify: {
    enabled: false,
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
  },
  namedAccounts: {
    deployer: 0,
  },
  mocha: {
    timeout: 100000000,
  },
};

task("update-glv-config", "Update GLV config")
  .addParam("write", "Write to the config", false, types.boolean)
  .setAction(updateGlvConfig);

task("update-market-config", "Update market config")
  .addParam("write", "Write to the config", false, types.boolean)
  .addOptionalParam("market", "Market address", undefined, types.string)
  .addOptionalParam("includeRiskOracleBaseKeys", "Include risk oracle base keys", false, types.boolean)
  .addOptionalParam("includeKeeperBaseKeys", "Include keeper base keys", false, types.boolean)
  .setAction(updateMarketConfig);

export default config;
