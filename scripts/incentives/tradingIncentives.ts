import hre, { ethers } from "hardhat";
import { bigNumberify, formatAmount } from "../../utils/math";
import {
  getDistributionTypeName,
  getMinRewardThreshold,
  getRewardToken,
  getRewardTokenPrice,
  overrideReceivers,
  processArgs,
  requestAllocationData,
  requestPrices,
  requestSubgraph,
  saveDistribution,
} from "./helpers";

async function requestMigrationData(fromTimestamp: number) {
  const data: {
    userTradingIncentivesStats: {
      positionFeesUsd: string;
      account: string;
    }[];
    tradingIncentivesStat: {
      positionFeesUsd: string;
    };
  } = await requestSubgraph(`{
    userTradingIncentivesStats(
      first: 10000,
      where: {
        timestamp: ${fromTimestamp},
        period: "1w"
      }
    ) {
      positionFeesUsd
      account
    }
    tradingIncentivesStat(id: "1w:${fromTimestamp}") {
      positionFeesUsd
    }
  }`);

  return {
    userTradingIncentivesStats: data.userTradingIncentivesStats
      .map((item) => {
        return {
          account: ethers.utils.getAddress(item.account),
          positionFeesUsd: bigNumberify(item.positionFeesUsd),
        };
      })
      .sort((a, b) => (a.positionFeesUsd.lt(b.positionFeesUsd) ? -1 : 1)),
    tradingIncentivesStat: data.tradingIncentivesStat
      ? {
          ...data.tradingIncentivesStat,
          positionFeesUsd: bigNumberify(data.tradingIncentivesStat.positionFeesUsd),
        }
      : null,
  };
}

async function main() {
  const { fromTimestamp, fromDate, toTimestamp, toDate, distributionTypeId } = await processArgs("trading");

  console.log("Running script to get distribution data");
  console.log("From: %s (timestamp %s)", fromDate.toISOString().substring(0, 19), fromTimestamp);
  console.log("To: %s (timestamp %s)", toDate.toISOString().substring(0, 19), toTimestamp);

  const [{ userTradingIncentivesStats, tradingIncentivesStat }, allocationData, prices] = await Promise.all([
    requestMigrationData(fromTimestamp),
    requestAllocationData(fromTimestamp),
    requestPrices(),
  ]);

  if (userTradingIncentivesStats.length === 0) {
    console.warn("WARN: no userTradingIncentivesStats data for this period");
    return;
  }

  if (!tradingIncentivesStat) {
    console.warn("WARN: no tradingIncentivesStat data for this period");
    return;
  }

  const tokens = await hre.gmx.getTokens();
  const rewardToken = getRewardToken(tokens, allocationData.trading.token);
  console.log("rewardToken %s %s", rewardToken.symbol, rewardToken.address);
  const rewardTokenPrice = getRewardTokenPrice(prices, rewardToken.address);

  const jsonResult: Record<string, string> = {};
  const minRewardThreshold = getMinRewardThreshold(rewardToken);

  let usersBelowThreshold = 0;
  let eligibleUsers = 0;
  let userTotalPositionFeesInRewardToken = bigNumberify(0);
  let userTotalPositionFeesUsd = bigNumberify(0);

  const allocation = allocationData.trading.allocation;
  let adjustedRebatePercent = bigNumberify(allocationData.trading.rebatePercent);

  userTradingIncentivesStats.sort((a, b) => {
    return a.positionFeesUsd.lt(b.positionFeesUsd) ? -1 : 1;
  });
  for (const item of userTradingIncentivesStats) {
    userTotalPositionFeesUsd = userTotalPositionFeesUsd.add(item.positionFeesUsd);
    const positionFeesInRewardToken = item.positionFeesUsd.div(rewardTokenPrice.maxPrice);
    userTotalPositionFeesInRewardToken = userTotalPositionFeesInRewardToken.add(positionFeesInRewardToken);
  }

  const usedAllocation = userTotalPositionFeesInRewardToken.mul(adjustedRebatePercent).div(10000);
  if (usedAllocation.gt(allocation)) {
    adjustedRebatePercent = adjustedRebatePercent.mul(allocation).div(usedAllocation);
  }

  let userTotalRewards = bigNumberify(0);
  for (const item of userTradingIncentivesStats) {
    const positionFeesInRewardToken = item.positionFeesUsd.div(rewardTokenPrice.maxPrice);
    const userRebates = positionFeesInRewardToken.mul(adjustedRebatePercent).div(10000);

    userTotalRewards = userTotalRewards.add(userRebates);
  }

  for (const item of userTradingIncentivesStats) {
    const positionFeesInRewardToken = item.positionFeesUsd.div(rewardTokenPrice.maxPrice);
    const userRebates = positionFeesInRewardToken.mul(adjustedRebatePercent).div(10000);

    console.log(
      "user %s rebate %s (%s%) position fee: %s %s",
      item.account,
      `${formatAmount(userRebates, rewardToken.decimals, 2, true)} ${rewardToken.symbol}`.padEnd(14),
      formatAmount(userRebates.mul(10000).div(userTotalRewards), 2, 2),
      `${formatAmount(positionFeesInRewardToken, rewardToken.decimals, 2, true)} ${rewardToken.symbol}`.padEnd(15),
      `($${formatAmount(item.positionFeesUsd, 30, 2, true)})`.padEnd(14)
    );

    if (userRebates.lt(minRewardThreshold)) {
      usersBelowThreshold++;
      console.log("skip user %s", item.account);
      continue;
    }
    eligibleUsers++;

    jsonResult[item.account] = userRebates.toString();
  }

  const appliedOverrides = await overrideReceivers(jsonResult);

  console.log(
    "Trading incentives (%s, %s) for period from %s to %s",
    hre.network.name,
    getDistributionTypeName(distributionTypeId),
    fromDate.toISOString().substring(0, 10),
    toDate.toISOString().substring(0, 10)
  );

  console.log(
    "sum of position fees paid: %s %s ($%s)",
    formatAmount(userTotalPositionFeesInRewardToken, rewardToken.decimals, 2, true),
    rewardToken.symbol,
    formatAmount(userTotalPositionFeesUsd, 30, 2, true)
  );

  console.log(
    "allocation: %s %s",
    formatAmount(allocationData.trading.allocation, rewardToken.expandDecimals, 2, true),
    rewardToken.symbol
  );
  console.log("used allocation %s %s", formatAmount(usedAllocation, rewardToken.decimals, 2, true), rewardToken.symbol);

  console.log(
    "initial rebate percent: %s%, adjusted rebate percent: %s%",
    formatAmount(allocationData.trading.rebatePercent, 2, 2),
    formatAmount(adjustedRebatePercent, 2, 2)
  );
  console.log(
    "min reward threshold: %s %s ($%s)",
    formatAmount(minRewardThreshold, rewardToken.expandDecimals, 4),
    rewardToken.symbol,
    formatAmount(minRewardThreshold.mul(rewardTokenPrice.maxPrice), 30, 2)
  );
  console.log("eligible users: %s", eligibleUsers);
  console.log("users below threshold: %s", usersBelowThreshold);

  console.log(
    "sum of user rewards: %s %s",
    formatAmount(userTotalRewards, rewardToken.expandDecimals, 2, true),
    rewardToken.symbol
  );

  saveDistribution(
    fromDate,
    "tradingIncentives",
    rewardToken.address,
    jsonResult,
    distributionTypeId,
    appliedOverrides
  );
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
