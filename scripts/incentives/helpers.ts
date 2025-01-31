import fs from "fs";
import path from "path";

import prompts from "prompts";
import { ethers } from "ethers";
import hre from "hardhat";
import { bigNumberify, expandDecimals, formatAmount } from "../../utils/math";
import fetch from "node-fetch";

import staticReceiverOverridesMap from "./receiverOverrides";

normalizeAddressesInMap(staticReceiverOverridesMap);

function normalizeAddressesInMap(map: Record<string, string>) {
  for (const address of Object.keys(map)) {
    const checksumAddress = ethers.utils.getAddress(address);
    if (checksumAddress !== address) {
      map[checksumAddress] = map[address];
      delete map[address];
    }
  }
}

function getSubgraphEndpoint() {
  if (hre.network.name === "arbitrum") {
    return "https://subgraph.satsuma-prod.com/3b2ced13c8d9/gmx/synthetics-arbitrum-stats/api";
  } else if (hre.network.name === "avalanche") {
    return "https://subgraph.satsuma-prod.com/3b2ced13c8d9/gmx/synthetics-avalanche-stats/api";
  } else {
    throw new Error("Unsupported network");
  }
}

function getApiEndpoint() {
  if (hre.network.name === "arbitrum") {
    return "https://arbitrum-api.gmxinfra2.io";
  } else if (hre.network.name === "avalanche") {
    return "https://avalanche-api.gmxinfra2.io";
  } else {
    throw new Error("Unsupported network");
  }
}

export function getMinRewardThreshold(rewardToken: any) {
  if (rewardToken.symbol === "WAVAX") {
    return expandDecimals(3, 15);
  } else if (rewardToken.symbol === "ARB") {
    return expandDecimals(1, 17);
  } else if (rewardToken.symbol === "GM AVAX+") {
    return expandDecimals(1, 17);
  } else {
    throw new Error(`Undefined min reward threshold for reward token ${rewardToken.symbol}`);
  }
}

export const STIP_LP_DISTRIBUTION_TYPE_ID = 1001;
export const STIP_MIGRATION_DISTRIBUTION_TYPE_ID = 1002;
export const STIP_TRADING_INCENTIVES_DISTRIBUTION_TYPE_ID = 1003;
export const EIP_4844_COMPETITION_1_ID = 2001;
export const EIP_4844_COMPETITION_2_ID = 2002;
export const ARBITRUM_STIP_B_LP_ID = 1004;
export const ARBITRUM_STIP_B_TRADING_ID = 1005;
export const ARBITRUM_STIP_B_TRADING_BONUS_ID = 1006;
export const AVALANCHE_RUSH_LP_ID = 1100;
export const AVALANCHE_RUSH_TRADING_ID = 1101;
export const THRESHOLD_tBTC_ID = 1200;
const TEST_DISTRIBUTION_TYPE_ID = 9876;

export const INCENTIVES_DISTRIBUTOR_ADDRESS = "0x8704EE9AB8622BbC25410C7D4717ED51f776c7f6";

type IncentivesType = "lp" | "trading" | "glpMigration" | "competition" | "test";

export const distributionTypes: Record<
  string,
  Record<
    string,
    {
      name: string;
      incentivesType: IncentivesType;
    }
  >
> = {
  [42161]: {
    [STIP_LP_DISTRIBUTION_TYPE_ID]: {
      name: "STIP LP",
      incentivesType: "lp",
    },
    [STIP_MIGRATION_DISTRIBUTION_TYPE_ID]: {
      name: "STIP MIGRATION",
      incentivesType: "glpMigration",
    },
    [STIP_TRADING_INCENTIVES_DISTRIBUTION_TYPE_ID]: {
      name: "STIP TRADING INCENTIVES",
      incentivesType: "trading",
    },
    [EIP_4844_COMPETITION_1_ID]: {
      name: "EIP-4844 COMPETITION 1",
      incentivesType: "competition",
    },
    [EIP_4844_COMPETITION_2_ID]: {
      name: "EIP-4844 COMPETITION 2",
      incentivesType: "competition",
    },
    [TEST_DISTRIBUTION_TYPE_ID]: {
      name: "TEST",
      incentivesType: "test",
    },
    [ARBITRUM_STIP_B_LP_ID]: {
      name: "STIP.b LP",
      incentivesType: "lp",
    },
    [ARBITRUM_STIP_B_TRADING_ID]: {
      name: "STIP.b TRADING",
      incentivesType: "trading",
    },
    [ARBITRUM_STIP_B_TRADING_BONUS_ID]: {
      name: "STIP.b TRADING BONUS",
      incentivesType: "trading",
    },
    [THRESHOLD_tBTC_ID]: {
      name: "Threshold tBTC",
      incentivesType: "lp",
    },
  },
  [43114]: {
    [AVALANCHE_RUSH_LP_ID]: {
      name: "AVALANCHE RUSH LP",
      incentivesType: "lp",
    },
    [AVALANCHE_RUSH_TRADING_ID]: {
      name: "AVALANCHE RUSH TRADING",
      incentivesType: "trading",
    },
  },
};

export function getDistributionTypeName(distributionTypeId: number) {
  const chainId = getChainId();
  if (!distributionTypes[chainId][distributionTypeId]) {
    throw new Error(`Unknown distribution with type id ${distributionTypeId} for chain id ${chainId}`);
  }
  return distributionTypes[chainId][distributionTypeId].name;
}

export async function requestSubgraph(query: string) {
  const payload = JSON.stringify({ query });
  const res = await fetch(getSubgraphEndpoint(), {
    method: "POST",
    body: payload,
    headers: { "Content-Type": "application/json" },
  });

  const j = await res.json();
  if (j.errors) {
    throw new Error(JSON.stringify(j));
  }

  return j.data;
}

export function guessBlockNumberByTimestamp(block: ethers.providers.Block, timestamp: number) {
  let blocksPerSecond: number;
  if (hre.network.name === "arbitrum") {
    blocksPerSecond = 4;
  } else if (hre.network.name === "avalanche") {
    blocksPerSecond = 0.5;
  } else {
    throw new Error(`Unknown block interval for network ${hre.network.name}`);
  }
  return block.number - Math.floor((block.timestamp - timestamp) * blocksPerSecond);
}

export async function getBlockByTimestamp(timestamp: number) {
  const tolerance = 0; // in seconds
  const latestBlock = await hre.ethers.provider.getBlock("latest");

  console.log(
    "searching block by timestamp %s (%s) latest block: %s %s",
    timestamp,
    new Date(timestamp * 1000).toISOString(),
    latestBlock.number,
    latestBlock.timestamp
  );

  let nextBlockNumber = guessBlockNumberByTimestamp(latestBlock, timestamp);

  const i = 0;
  const seenDiffs = new Set<number>();
  while (i < 15) {
    console.log("requesting next block %s", nextBlockNumber);
    const block = await hre.ethers.provider.getBlock(nextBlockNumber);

    if (Math.abs(block.timestamp - timestamp) < tolerance) {
      console.log(
        "found block %s %s diff %s",
        block.number,
        block.timestamp,
        new Date(block.timestamp * 1000).toISOString(),
        block.timestamp - timestamp
      );
      return block;
    }

    const diff = block.timestamp - timestamp;
    if (seenDiffs.has(diff)) {
      console.log("seen block %s diff %s. break", block.number, diff);
      return block;
    }

    seenDiffs.add(diff);
    console.log("%s seconds away", diff);

    nextBlockNumber = guessBlockNumberByTimestamp(block, timestamp);

    if (block.number === nextBlockNumber) {
      console.log("search stopped");
      return block;
    }
  }
  throw new Error("block is not found");
}

export async function requestPrices() {
  const url = new URL(`${getApiEndpoint()}/prices/tickers`);
  const res = await fetch(url);
  const prices = (await res.json()) as {
    maxPrice: string;
    minPrice: string;
    tokenSymbol: string;
    tokenAddress: string;
  }[];

  return prices;
}

export async function requestAllocationData(timestamp: number) {
  const url = new URL(`${getApiEndpoint()}/incentives`);
  url.searchParams.set("timestamp", String(timestamp));
  if (process.env.IGNORE_START_DATE) {
    url.searchParams.set("ignoreStartDate", "1");
  }
  const res = await fetch(url);
  const data = (await res.json()) as {
    lp: {
      isActive: boolean;
      totalRewards: string;
      totalShare: number;
      period: number;
      rewardsPerMarket: Record<string, string>;
      token: string;
      excludeHolders: string[];
    };
    migration: {
      isActive: boolean;
      maxRebateBps: number;
      period: number;
    };
    trading: {
      isActive: boolean;
      rebatePercent: number;
      allocation: string;
      period: number;
      token: string;
    };
  };

  return {
    lp: {
      ...data.lp,
      totalRewards: bigNumberify(data.lp.totalRewards || 0),
      rewardsPerMarket:
        data.lp.rewardsPerMarket &&
        Object.fromEntries(
          Object.entries(data.lp.rewardsPerMarket).map(([marketAddress, rewards]) => {
            return [marketAddress, bigNumberify(rewards)];
          })
        ),
    },
    migration: data.migration,
    trading: {
      ...data.trading,
      allocation: data.trading.allocation ? bigNumberify(data.trading.allocation) : undefined,
    },
  };
}

export function getChainId() {
  if (hre.network.name === "arbitrum") {
    return 42161;
  }

  if (hre.network.name === "avalanche") {
    return 43114;
  }

  throw new Error("Unsupported network");
}

export async function getFrameSigner() {
  try {
    const frame = new ethers.providers.JsonRpcProvider("http://127.0.0.1:1248");
    const signer = frame.getSigner();
    if (getChainId() !== (await signer.getChainId())) {
      throw new Error("Incorrect frame network");
    }
    return signer;
  } catch (e) {
    throw new Error(`getFrameSigner error: ${e.toString()}`);
  }
}

async function validateDolomiteVaults(vaults: string[]) {
  const dolomiteValidMarginAddress = "0x6Bd780E7fDf01D77e4d475c821f1e7AE05409072";
  const multicall = await hre.ethers.getContract("Multicall3");
  const abi = ["function DOLOMITE_MARGIN()"];
  const iface = new ethers.utils.Interface(abi);
  const methodName = "DOLOMITE_MARGIN";
  const data = iface.encodeFunctionData(methodName);

  const batchSize = 500;
  const multicallRequests = new Array(Math.ceil(vaults.length / batchSize)).fill(0).map(async (_, i) => {
    const from = i * batchSize;
    const to = Math.min(from + batchSize, vaults.length);
    const batch = vaults.slice(from, to);
    const multicallData = batch.map((vault) => ({
      target: vault,
      callData: data,
    }));
    console.debug("multicallData %s %s-%s", i, from, to);
    const result = await multicall.callStatic.aggregate3(multicallData);
    result.forEach(({ success, returnData }, j: number) => {
      if (!success) {
        throw new Error("Multicall request failed");
      }
      const dolomiteMargin: string = ethers.utils.defaultAbiCoder.decode(["address"], returnData)[0];
      console.log("dolomite vault %s margin %s", batch[j], dolomiteMargin);
      if (dolomiteMargin !== dolomiteValidMarginAddress) {
        console.error(
          "ERROR: Dolomite vault %s has incorrect margin %s expected %s",
          batch[j],
          dolomiteMargin,
          dolomiteValidMarginAddress
        );
        throw new Error("Dolomite vault has incorrect margin");
      }
    });
  });

  await Promise.all(multicallRequests);

  console.log("Dolomite vaults are valid");
}

export async function fetchDolomiteReceiverOverrides() {
  if (hre.network.name !== "arbitrum") {
    return {};
  }

  console.log("fetching Dolomite overrides");

  const url = "https://api.dolomite.io/isolation-mode/42161/proxy-vaults/gmx";
  const res: { data: Record<string, string> } = await fetch(url).then((r) => r.json());

  const overrides = Object.fromEntries(
    Object.entries(res.data).map(([from, to]) => {
      return [ethers.utils.getAddress(from), ethers.utils.getAddress(to)];
    })
  );

  console.log("received %s overrides", Object.keys(overrides).length);

  normalizeAddressesInMap(overrides);

  await validateDolomiteVaults(Object.keys(overrides));

  return overrides;
}

export async function overrideReceivers(data: Record<string, string>): Promise<Record<string, string>> {
  const dolomiteReceiverOverrides = await fetchDolomiteReceiverOverrides();
  const receiverOverridesMap = {
    ...staticReceiverOverridesMap,
    ...dolomiteReceiverOverrides,
  };

  const appliedOverrides: Record<string, string> = {};

  for (const [receiver, amount] of Object.entries(data)) {
    const checksumReceiver = ethers.utils.getAddress(receiver);
    const newReceiver = receiverOverridesMap[checksumReceiver];
    if (!newReceiver) {
      continue;
    }
    console.warn("WARN: override receiver %s -> %s amount: %s", receiver, newReceiver, amount);
    appliedOverrides[receiver] = newReceiver;
    delete data[receiver];
    if (newReceiver in data) {
      data[newReceiver] = bigNumberify(data[newReceiver]).add(amount).toString();
    } else {
      data[newReceiver] = amount;
    }
  }

  return appliedOverrides;
}

export function saveDistribution(
  fromDate: Date,
  name: string,
  tokenAddress: string,
  jsonResult: Record<string, string>,
  distributionTypeId: number,
  appliedOverrides: Record<string, string>
) {
  const dateStr = fromDate.toISOString().substring(0, 10);
  const dirPath = path.join(__dirname, "distributions", `epoch_${dateStr}_${hre.network.name}`);
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath);
  }
  const filename = path.join(dirPath, `${name}_distribution.json`);
  const id = `${dateStr}_${hre.network.name}_${distributionTypeId}`;

  Object.keys(jsonResult).forEach((receiver) => {
    if (ethers.utils.getAddress(receiver) !== receiver) {
      throw Error(`Receiver address should be check summed: ${receiver}`);
    }
  });

  fs.writeFileSync(
    filename,
    JSON.stringify(
      {
        token: tokenAddress,
        distributionTypeId,
        chainId: getChainId(),
        id,
        amounts: jsonResult,
        appliedOverrides,
      },
      null,
      4
    )
  );
  console.log("distribution data is saved to %s", filename);

  const csv = ["recipient,amount"];
  const filename3 = path.join(dirPath, `${name}_distribution.csv`);
  for (const [recipient, amount] of Object.entries(jsonResult)) {
    csv.push(`${recipient},${formatAmount(amount, 18, 2)}`);
  }
  fs.writeFileSync(filename3, csv.join("\n"));
  console.log("csv data saved to %s", filename3);
}

const getLatestWednesday = () => {
  const date = new Date();
  const day = date.getDay();
  const diff = date.getDate() - day + (day === 0 ? -4 : 3);
  const ret = new Date(date.setDate(diff));
  ret.setUTCHours(0, 0, 0, 0);
  return ret;
};

export async function processArgs(incentivesType?: IncentivesType) {
  if (!["arbitrum", "avalanche"].includes(hre.network.name)) {
    throw new Error("Unsupported network");
  }

  const chainId = getChainId();

  let distributionTypeId: number;

  if (process.env.DISTRIBUTION_TYPE_ID) {
    distributionTypeId = Number(process.env.DISTRIBUTION_TYPE_ID);
  } else {
    ({ distributionTypeId } = await prompts({
      type: "select",
      name: "distributionTypeId",
      message: "Enter the distribution type",
      choices: Object.entries(distributionTypes[chainId])
        .filter(([, { incentivesType: _type }]) => _type === incentivesType)
        .map(([id, { name }]) => ({
          title: `${id}: ${name}`,
          value: Number(id),
        })),
    }));
  }

  const knownDistributionTypeIds = new Set(Object.keys(distributionTypes[chainId]).map((id) => Number(id)));
  if (!knownDistributionTypeIds.has(distributionTypeId)) {
    throw new Error(
      `unknown DISTRIBUTION_TYPE_ID ${distributionTypeId}. Valid values:\n${Array.from(knownDistributionTypeIds)
        .map((id) => `${id}: ${getDistributionTypeName(id)}`)
        .join("\n")}`
    );
  }

  if (incentivesType && distributionTypes[chainId][distributionTypeId].incentivesType !== incentivesType) {
    console.error(
      "ERROR: incorrect incentives type: '%s' expected: '%s'",
      distributionTypes[chainId][distributionTypeId].incentivesType,
      incentivesType
    );
    throw new Error("Incentives type don't match");
  }

  let fromDate: Date;
  if (process.env.FROM_DATE) {
    fromDate = new Date(process.env.FROM_DATE);
  } else {
    const latestWednesday = getLatestWednesday();
    const previousWednesday = new Date(latestWednesday.getTime() - 1000 * 86400 * 7);
    ({ fromDate } = await prompts({
      type: "select",
      name: "fromDate",
      message: "Enter the start of epoch",
      choices: [
        { title: `${latestWednesday.toISOString().substring(0, 10)} (current epoch)`, value: latestWednesday },
        { title: `${previousWednesday.toISOString().substring(0, 10)} (previous epoch)`, value: previousWednesday },
      ],
      initial: 1,
    }));
  }

  if (fromDate.getDay() !== 3) {
    throw Error(`FROM_DATE should be Wednesday: ${fromDate.getDay()}`);
  }
  if (fromDate.getUTCHours() !== 0 || fromDate.getUTCMinutes() !== 0 || fromDate.getUTCSeconds() !== 0) {
    throw Error(`FROM_DATE should be at 00:00:00 UTC: ${fromDate.toISOString().substring(0, 19)}`);
  }

  const fromTimestamp = Math.floor(+fromDate / 1000);

  let toTimestamp = fromTimestamp + 86400 * 7;

  if (toTimestamp > Date.now() / 1000) {
    if (!process.env.SKIP_EPOCH_VALIDATION) {
      throw new Error("Epoch has not ended yet. Run with SKIP_EPOCH_VALIDATION=1 if this is expected");
    }

    console.warn("WARN: epoch has not ended yet");
    toTimestamp = Math.floor(Date.now() / 1000) - 60;
  }

  const secondsSinceEpochEnded = Date.now() / 1000 - toTimestamp;
  if (secondsSinceEpochEnded > 86400 * 7) {
    const days = Math.floor(secondsSinceEpochEnded / 86400);
    if (!process.env.SKIP_EPOCH_VALIDATION) {
      throw new Error(`Epoch is old ended ${days} days ago. Run with SKIP_EPOCH_VALIDATION=1 if this is expected`);
    }

    console.warn("WARN: epoch is old ended %s days ago", days);
  }

  const toDate = new Date(toTimestamp * 1000);

  return {
    fromTimestamp,
    fromDate,
    toTimestamp,
    toDate,
    distributionTypeId,
  };
}

export function getRewardToken(tokens: any[], address: string) {
  if (address === "0x08b25A2a89036d298D6dB8A74ace9d1ce6Db15E5") {
    return {
      symbol: "GM AVAX+",
      address,
      decimals: 18,
    };
  }

  const rewardToken = Object.values(tokens).find((t: any) => t.address === address) as any;

  if (!rewardToken) {
    throw new Error(`Unknown reward token ${address}`);
  }

  return rewardToken;
}

export function getRewardTokenPrice(
  prices: {
    maxPrice: string;
    minPrice: string;
    tokenAddress: string;
    tokenSymbol: string;
  }[],
  address: string
) {
  if (address === "0x08b25A2a89036d298D6dB8A74ace9d1ce6Db15E5") {
    return {
      maxPrice: "1026000000000",
      minPrice: "1026000000000",
      tokenAddress: address,
      tokenSymbol: "GM AVAX+",
    };
  }

  const rewardTokenPrice = prices.find((p) => p.tokenAddress === address);
  if (!rewardTokenPrice) {
    throw new Error(`No price for reward token ${address}`);
  }
  return rewardTokenPrice;
}
