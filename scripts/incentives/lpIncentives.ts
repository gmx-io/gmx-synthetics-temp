import { BigNumber, ethers } from "ethers";
import hre from "hardhat";
import { bigNumberify, expandDecimals, formatAmount } from "../../utils/math";
import {
  getBlockByTimestamp,
  getDistributionTypeName,
  getMinRewardThreshold,
  getRewardToken,
  getRewardTokenPrice,
  INCENTIVES_DISTRIBUTOR_ADDRESS,
  overrideReceivers,
  processArgs,
  requestAllocationData,
  requestPrices,
  requestSubgraph,
  saveDistribution,
} from "./helpers";
import { toLoggableObject } from "../../utils/print";
import { setTimeout } from "timers/promises";

function getUserMarketInfosQuery(
  i: number,
  toBlockNumber: number,
  glvOrMarketsWithRewardsCond: string,
  excludeHoldersCond: string
) {
  return `
    liquidityProviderInfos(
      first: 10000
      skip: ${i * 10000}
      block: {
        number: ${toBlockNumber}
      }
      where: {
        account_not_in: ${excludeHoldersCond}
        glvOrMarketAddress_in: ${glvOrMarketsWithRewardsCond}
      }
    ) {
      account
      glvOrMarketAddress
      type
      tokensBalance
    }
  `;
}

type LiquidityProviderInfo = {
  account: string;
  glvOrMarketAddress: string;
  tokensBalance: string;
};

async function requestBalancesData(
  fromTimestamp: number,
  toBlockNumber: number,
  glvOrMarketsWithRewards: string[],
  excludeHolders: string[]
) {
  const glvOrMarketsWithRewardsCond = '["' + glvOrMarketsWithRewards.map((m) => m.toLowerCase()).join('","') + '"]';

  // subgraph returns empty result if `account_not_in` is empty array
  const excludeHoldersCond =
    excludeHolders.length > 0 ? '["' + excludeHolders.map((m) => m.toLowerCase()).join('","') + '"]' : '["0x"]';

  const data: {
    liquidityProviderIncentivesStats: {
      account: string;
      glvOrMarketAddress: string;
      type: string;
      weightedAverageTokensBalance: string;
    }[];
    incentivesStats: {
      type: string;
      glvOrMarketAddress: string;
    }[];
    liquidityProviderInfos0: LiquidityProviderInfo[];
    liquidityProviderInfos1: LiquidityProviderInfo[];
    liquidityProviderInfos2: LiquidityProviderInfo[];
    liquidityProviderInfos3: LiquidityProviderInfo[];
    liquidityProviderInfos4: LiquidityProviderInfo[];
    liquidityProviderInfos5: LiquidityProviderInfo[];
    liquidityProviderInfos6: LiquidityProviderInfo[];
    liquidityProviderInfos7: LiquidityProviderInfo[];
    liquidityProviderInfos8: LiquidityProviderInfo[];
  } = await requestSubgraph(`{
    liquidityProviderIncentivesStats(
      first: 10000
      where: {
        timestamp: ${fromTimestamp}
        period: "1w"
        account_not_in: ${excludeHoldersCond}
        glvOrMarketAddress_in: ${glvOrMarketsWithRewardsCond}
      }
    ) {
      account
      glvOrMarketAddress
      type
      weightedAverageTokensBalance
    }
    incentivesStats(
      first: 10000
      where: {
        glvOrMarketAddress_in: ${glvOrMarketsWithRewardsCond}
        timestamp: ${fromTimestamp}
        period: "1w"
      }
    ) {
      glvOrMarketAddress
      type
    }
    liquidityProviderInfos0: ${getUserMarketInfosQuery(
      0,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
    liquidityProviderInfos1: ${getUserMarketInfosQuery(
      1,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
    liquidityProviderInfos2: ${getUserMarketInfosQuery(
      2,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
    liquidityProviderInfos3: ${getUserMarketInfosQuery(
      3,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
    liquidityProviderInfos4: ${getUserMarketInfosQuery(
      4,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
    liquidityProviderInfos5: ${getUserMarketInfosQuery(
      5,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
    liquidityProviderInfos6: ${getUserMarketInfosQuery(
      6,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
    liquidityProviderInfos7: ${getUserMarketInfosQuery(
      7,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
    liquidityProviderInfos8: ${getUserMarketInfosQuery(
      8,
      toBlockNumber,
      glvOrMarketsWithRewardsCond,
      excludeHoldersCond
    )}
  }`);

  if (data.incentivesStats.length === 10000) {
    throw new Error("should paginate incentivesStats");
  }

  if (data.liquidityProviderIncentivesStats.length === 10000) {
    throw new Error("should paginate liquidityProviderIncentivesStats");
  }

  const liquidityProviderInfos = [
    ...data.liquidityProviderInfos0,
    ...data.liquidityProviderInfos1,
    ...data.liquidityProviderInfos2,
    ...data.liquidityProviderInfos3,
    ...data.liquidityProviderInfos4,
    ...data.liquidityProviderInfos5,
    ...data.liquidityProviderInfos6,
    ...data.liquidityProviderInfos7,
    ...data.liquidityProviderInfos8,
  ];

  if (liquidityProviderInfos.length === 90000) {
    throw new Error("should paginate liquidityProviderInfos");
  }

  const seenUserMarketInfo = new Set();
  for (const liquidityProviderInfo of liquidityProviderInfos) {
    const key = `${liquidityProviderInfo.account}:${liquidityProviderInfo.glvOrMarketAddress}`;
    if (seenUserMarketInfo.has(key)) {
      console.error(
        "ERROR: duplicated liquidityProviderInfo account %s glv or market %s",
        liquidityProviderInfo.account,
        liquidityProviderInfo.glvOrMarketAddress
      );
      throw new Error("Duplicated liquidityProviderInfo");
    }
    seenUserMarketInfo.add(key);
  }

  const dataByMarket = Object.fromEntries(
    glvOrMarketsWithRewards.map((glvOrMarketAddress) => {
      glvOrMarketAddress = glvOrMarketAddress.toLowerCase();
      const userBalances: Record<string, BigNumber> = {};
      for (const lpStat of data.liquidityProviderIncentivesStats) {
        if (lpStat.glvOrMarketAddress === glvOrMarketAddress) {
          userBalances[ethers.utils.getAddress(lpStat.account)] = bigNumberify(lpStat.weightedAverageTokensBalance);
        }
      }
      for (const info of liquidityProviderInfos) {
        if (info.glvOrMarketAddress !== glvOrMarketAddress) {
          continue;
        }
        if (ethers.utils.getAddress(info.account) in userBalances) {
          continue;
        }
        if (info.tokensBalance === "0") {
          continue;
        }
        userBalances[ethers.utils.getAddress(info.account)] = bigNumberify(info.tokensBalance);
      }

      return [ethers.utils.getAddress(glvOrMarketAddress), userBalances];
    })
  );

  return dataByMarket;
}

/*
Example of usage:
...
*/

async function main() {
  const { fromTimestamp, fromDate, toTimestamp, toDate, distributionTypeId } = await processArgs("lp");

  const toBlock = await getBlockByTimestamp(toTimestamp);
  console.log("found toBlock %s %s for timestamp %s", toBlock.number, toBlock.timestamp, toTimestamp);

  console.log("Running script to get distribution data");
  console.log("From: %s (timestamp %s)", fromDate.toISOString().substring(0, 19), fromTimestamp);
  console.log("To: %s (timestamp %s)", toDate.toISOString().substring(0, 19), toTimestamp);

  const [allocationData, prices] = await Promise.all([requestAllocationData(fromTimestamp), requestPrices()]);

  const lpAllocationData = allocationData.lp;

  if (!lpAllocationData.isActive) {
    console.warn("WARN: LP incentives are not active for this period");
    return;
  }

  const deployments = await hre.deployments.all();
  // to avoid sending funds to e.g. Vault contracts
  const excludeHolders = [
    INCENTIVES_DISTRIBUTOR_ADDRESS, //
    ...Object.values(deployments).map((d) => d.address),
  ];

  if (lpAllocationData.excludeHolders.length > 0) {
    console.warn("WARN: excludeHolders: %s", lpAllocationData.excludeHolders.join(", "));
    excludeHolders.push(...lpAllocationData.excludeHolders);
  }

  const glvOrMarketsWithRewards = Object.entries(lpAllocationData.rewardsPerMarket)
    .filter(([, allocation]) => {
      return allocation.gt(0);
    })
    .map(([glvOrMarketAddress]) => glvOrMarketAddress);

  const balancesData = await requestBalancesData(
    fromTimestamp,
    toBlock.number,
    glvOrMarketsWithRewards,
    excludeHolders
  );

  const tokens = await hre.gmx.getTokens();
  const rewardToken = getRewardToken(tokens, lpAllocationData.token);
  console.log("rewardToken %s %s", rewardToken.symbol, rewardToken.address);

  const rewardTokenPrice = getRewardTokenPrice(prices, rewardToken.address);

  if (Math.abs(lpAllocationData.totalShare - 1) > 0.001) {
    console.warn("WARN: total share %s of glv or market allocations is not 1", lpAllocationData.totalShare);
    await setTimeout(3000);
  }

  console.log("allocationData", toLoggableObject(lpAllocationData));

  if (!lpAllocationData.isActive) {
    throw new Error(`There is no incentives for week starting on ${fromDate}`);
  }

  const usersDistributionResult: Record<string, BigNumber> = {};

  for (const glvOrMarketAddress of Object.keys(lpAllocationData.rewardsPerMarket)) {
    if (lpAllocationData.rewardsPerMarket[glvOrMarketAddress].eq(0)) {
      continue;
    }
    if (!(glvOrMarketAddress in balancesData)) {
      throw new Error(`No balances data for glv or market ${glvOrMarketAddress}`);
    }
    const userBalances = balancesData[glvOrMarketAddress];
    const userBalancesSum = Object.values(userBalances).reduce((acc, userBalance) => {
      return acc.add(userBalance);
    }, bigNumberify(0));

    const allocation = lpAllocationData.rewardsPerMarket[glvOrMarketAddress];
    console.log(
      "glv or market %s allocation %s userBalancesSum: %s",
      glvOrMarketAddress,
      formatAmount(allocation, rewardToken.decimals, 2, true),
      formatAmount(userBalancesSum, rewardToken.decimals, 2, true)
    );

    let userTotalRewardsForMarket = bigNumberify(0);
    for (const [userAccount, userBalance] of Object.entries(userBalances)) {
      if (!(userAccount in usersDistributionResult)) {
        usersDistributionResult[userAccount] = bigNumberify(0);
      }

      const userRewards = userBalance.mul(allocation).div(userBalancesSum);
      userTotalRewardsForMarket = userTotalRewardsForMarket.add(userRewards);

      console.log(
        "glv or market %s user %s rewards %s %s avg balance %s (%s%)",
        glvOrMarketAddress,
        userAccount,
        formatAmount(userRewards, rewardToken.decimals, 2, true).padStart(8),
        rewardToken.symbol,
        formatAmount(userBalance, rewardToken.decimals, 2, true).padStart(12),
        formatAmount(userBalance.mul(10000).div(userBalancesSum), 2, 2)
      );

      usersDistributionResult[userAccount] = usersDistributionResult[userAccount].add(userRewards);
    }

    if (userTotalRewardsForMarket.gt(allocation)) {
      console.error(
        "ERROR: glv or market %s user total rewards %s exceeds allocation %s",
        glvOrMarketAddress,
        formatAmount(userTotalRewardsForMarket, rewardToken.decimals, 2, true),
        formatAmount(allocation, rewardToken.decimals, 2, true)
      );
      throw new Error("User total rewards for glv or market exceeds allocation");
    }
  }
  const minRewardThreshold = getMinRewardThreshold(rewardToken);

  let userTotalRewards = bigNumberify(0);
  const jsonResult: Record<string, string> = {};
  let usersBelowThreshold = 0;
  let eligibleUsers = 0;

  for (const [userAccount, userRewards] of Object.entries(usersDistributionResult).sort((a, b) => {
    return a[1].lt(b[1]) ? -1 : 1;
  })) {
    userTotalRewards = userTotalRewards.add(userRewards);
    if (userRewards.lt(minRewardThreshold)) {
      console.log(
        "user %s rewards: %s %s below threshold",
        userAccount,
        formatAmount(userRewards, rewardToken.decimals, 2, true),
        rewardToken.symbol
      );
      usersBelowThreshold++;
      continue;
    }
    eligibleUsers++;
    console.log(
      "user: %s rewards: %s %s (%s%)",
      userAccount,
      formatAmount(userRewards, rewardToken.decimals, 2, true),
      rewardToken.symbol,
      formatAmount(userRewards.mul(10000).div(lpAllocationData.totalRewards), 2, 2)
    );

    jsonResult[userAccount] = userRewards.toString();
  }

  if (userTotalRewards.sub(lpAllocationData.totalRewards).gt(expandDecimals(1, rewardToken.decimals))) {
    throw new Error(
      "Sum of user rewards exceeds total allocated rewards " + `${userTotalRewards} > ${lpAllocationData.totalRewards}`
    );
  }

  const appliedOverrides = await overrideReceivers(jsonResult);

  for (const glvOrMarketAddress of Object.keys(lpAllocationData.rewardsPerMarket)) {
    console.log(
      "glv or market %s allocation: %s",
      glvOrMarketAddress,
      formatAmount(lpAllocationData.rewardsPerMarket[glvOrMarketAddress], rewardToken.decimals, 2, true)
    );
  }

  console.log(
    "Liquidity incentives (%s, %s) for period from %s to %s",
    hre.network.name,
    getDistributionTypeName(distributionTypeId),
    fromDate.toISOString().substring(0, 10),
    toDate.toISOString().substring(0, 10)
  );
  console.log(
    "allocated rewards: %s %s",
    formatAmount(lpAllocationData.totalRewards, rewardToken.decimals, 2, true),
    rewardToken.symbol
  );

  console.log(
    "min reward threshold: %s %s ($%s)",
    formatAmount(minRewardThreshold, rewardToken.expandDecimals, 4),
    rewardToken.symbol,
    formatAmount(minRewardThreshold.mul(rewardTokenPrice.maxPrice), 30, 2)
  );
  console.log("total users: %s", eligibleUsers + usersBelowThreshold);
  console.log("eligible users: %s", eligibleUsers);
  console.log("users below threshold: %s", usersBelowThreshold);

  // userTotalRewards can be slightly lower than allocated rewards because of rounding
  console.log(
    "sum of user rewards: %s %s",
    formatAmount(userTotalRewards, rewardToken.decimals, 2, true),
    rewardToken.symbol
  );

  saveDistribution(fromDate, "lpIncentives", rewardToken.address, jsonResult, distributionTypeId, appliedOverrides);
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
