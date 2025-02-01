import { expect } from "chai";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { usingResult } from "../../utils/use";
import { deployFixture } from "../../utils/fixture";
import { expandDecimals, decimalToFloat, bigNumberify } from "../../utils/math";
import { handleDeposit } from "../../utils/deposit";
import { handleOrder } from "../../utils/order";
import { getMarketTokenPriceWithPoolValue } from "../../utils/market";
import { grantRole } from "../../utils/role";
import * as keys from "../../utils/keys";
import { handleWithdrawal } from "../../utils/withdrawal";
import {
  getAccountPositionCount,
  getPendingImpactAmountKey,
  getPositionKey,
  getPositionKeys,
} from "../../utils/position";
import { OrderType } from "../../utils/order";

describe("Guardian.PositionImpactPoolDistribution", () => {
  let fixture;
  let wallet, user0, user1;
  let config, dataStore, roleStore, ethUsdMarket, usdc, reader, wnt;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ wallet, user0, user1 } = fixture.accounts);
    ({ config, dataStore, roleStore, ethUsdMarket, usdc, reader, wnt } = fixture.contracts);

    await grantRole(roleStore, wallet.address, "CONFIG_KEEPER");

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(1000, 18), // $5,000,000
        shortTokenAmount: expandDecimals(5_000_000, 6), // $5,000,000
      },
    });
  });

  it("Market value reflects next position impact pool value", async () => {
    // Current pool value should reflect sum of long and short token deposit
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(1));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(10_000_000)); // $10,000,000
    });

    await dataStore.setUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken), expandDecimals(400, 18)); // $2,000,000

    // Pool value should be decremented by impact pool value
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(8, 1));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(8_000_000)); // $8,000,000
    });

    await config.setPositionImpactDistributionRate(
      ethUsdMarket.marketToken,
      expandDecimals(200, 18), // minPositionImpactPoolAmount
      expandDecimals(2, 43) // positionImpactPoolDistributionRate, 0.00002 ETH per second, 200 ETH for 10,000,000 seconds
    );

    await time.increase(50_000); // 0.00002 ETH/sec * 50,000 sec = 1 ETH should be distributed

    // Pool should gain 1 ETH of value $5,000 since next impact pool amount is utilized rather than current one.
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(8005, 4));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(8_005_000)); // $8,005,000
    });
  });

  it("Distribution does not go below minimum impact pool amount", async () => {
    // Current pool value should reflect sum of long and short token deposit
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(1));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(10_000_000)); // $10,000,000
    });

    await dataStore.setUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken), expandDecimals(400, 18)); // $2,000,000

    // Pool value should be decremented by impact pool value
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(8, 1));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(8_000_000)); // $8,000,000
    });

    await config.setPositionImpactDistributionRate(
      ethUsdMarket.marketToken,
      expandDecimals(399, 18), // minPositionImpactPoolAmount
      expandDecimals(2, 43) // positionImpactPoolDistributionRate, 0.00002 ETH per second, 200 ETH for 10,000,000 seconds
    );

    await time.increase(50_000); // 0.00002 ETH/sec * 50,000 sec = 1 ETH should be distributed

    // Pool should gain 1 ETH of value $5,000 since next impact pool amount is utilized rather than current one.
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(8005, 4));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(8_005_000)); // $8,005,000
    });

    // Trigger a distribution through the config
    await config.setPositionImpactDistributionRate(
      ethUsdMarket.marketToken,
      expandDecimals(399, 18), // minPositionImpactPoolAmount
      expandDecimals(2, 43) // positionImpactPoolDistributionRate, 0.00002 ETH per second, 200 ETH for 10,000,000 seconds
    );

    // We are at the minimum and should no longer distribute
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(
      expandDecimals(399, 18)
    );

    await time.increase(50_000); // 0.00002 ETH/sec * 50,000 sec = 1 ETH should NOT be distributed

    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(8005, 4));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(8_005_000)); // $8,005,000
    });

    // We are at the minimum and should no longer distribute
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(
      expandDecimals(399, 18)
    );

    await time.increase(50_000); // 0.00002 ETH/sec * 50,000 sec = 1 ETH should NOT be distributed

    // Trigger a distribution through deposit
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        shortTokenAmount: expandDecimals(1_000_000, 6), // $1,000,000
      },
    });

    // We are at the minimum and should no longer distribute
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(
      expandDecimals(399, 18)
    );

    await time.increase(50_000); // 0.00002 ETH/sec * 50,000 sec = 1 ETH should NOT be distributed

    // Trigger a distribution through withdrawal
    await handleWithdrawal(fixture, {
      create: {
        market: ethUsdMarket,
        marketTokenAmount: expandDecimals(1_000_000, 18), // $1,000,000
      },
    });

    // We are at the minimum and should no longer distribute
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(
      expandDecimals(399, 18)
    );
  });

  it("Changing min distribution amount", async () => {
    // Current pool value should reflect sum of long and short token deposit
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(1));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(10_000_000)); // $10,000,000
    });

    await dataStore.setUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken), expandDecimals(400, 18)); // $2,000,000

    // Pool value should be decremented by impact pool value
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(8, 1));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(8_000_000)); // $8,000,000
    });

    await config.setPositionImpactDistributionRate(
      ethUsdMarket.marketToken,
      expandDecimals(399, 18), // minPositionImpactPoolAmount
      expandDecimals(2, 43) // positionImpactPoolDistributionRate, 0.00002 ETH per second, 200 ETH for 10,000,000 seconds
    );

    await time.increase(200_000); // 0.00002 ETH/sec * 200,000 sec = 4 ETH should be distributed

    // Pool should gain 1 ETH of value $5,000 since next impact pool amount is utilized rather than current one.
    await usingResult(getMarketTokenPriceWithPoolValue(fixture), ([marketTokenPrice, poolValueInfo]) => {
      expect(marketTokenPrice).eq(decimalToFloat(8005, 4));
      expect(poolValueInfo.poolValue).eq(decimalToFloat(8_005_000)); // $8,005,000
    });

    // Trigger a distribution through the config + decrease the minPositionImpactPoolAmount to 398 ETH
    await config.setPositionImpactDistributionRate(
      ethUsdMarket.marketToken,
      expandDecimals(398, 18), // minPositionImpactPoolAmount
      expandDecimals(2, 43) // positionImpactPoolDistributionRate, 0.00002 ETH per second, 200 ETH for 10,000,000 seconds
    );

    // Although 4 ETH can be distributed, we do not allow the impact pool to go below the EARLIER minimum (399 ETH)
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(
      expandDecimals(399, 18)
    );

    await time.increase(200_000); // 0.00002 ETH/sec * 200,000 sec = 4 ETH should be distributed

    // Trigger a distribution through deposit
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        shortTokenAmount: expandDecimals(1_000_000, 6), // $1,000,000
      },
    });

    // Although 4 ETH can be distributed, we do not allow the impact pool to go below the new minimum (398 ETH)
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(
      expandDecimals(398, 18)
    );
  });

  it("Position receiving positive price impact with distribution", async () => {
    // set price impact to 10% for every $50,000 of token imbalance
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(2, 6));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 6));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));
    await config.setPositionImpactDistributionRate(
      ethUsdMarket.marketToken,
      expandDecimals(0, 18), // minPositionImpactPoolAmount
      expandDecimals(2, 43) // positionImpactPoolDistributionRate, 0.00002 ETH per second, 200 ETH for 10,000,000 seconds
    );

    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await getAccountPositionCount(dataStore, user1.address)).eq(0);

    // User1 creates a short market increase unbalancing the pool
    await handleOrder(fixture, {
      create: {
        account: user1,
        market: ethUsdMarket,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: expandDecimals(50 * 1000, 6), // $50,000
        sizeDeltaUsd: decimalToFloat(100 * 1000), // 2x position
        acceptablePrice: expandDecimals(4100, 12),
        orderType: OrderType.MarketIncrease,
        isLong: false,
      },
    });

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(0);

    const positionKey1 = getPositionKey(user1.address, ethUsdMarket.marketToken, usdc.address, false);
    // 10% * 2 * $100,000 = $20,000 = 4 ETH
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey1))).eq("-3999999999999999926"); // ~4 ETH

    // Check that User1's order got filled
    expect(await getAccountPositionCount(dataStore, user1.address)).eq(1);

    // User0 creates a long market increase to balance the pool
    await handleOrder(fixture, {
      create: {
        account: user0,
        market: ethUsdMarket,
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(1, 18), // $5,000
        sizeDeltaUsd: decimalToFloat(10 * 1000), // 2x position
        acceptablePrice: expandDecimals(5200, 12),
        orderType: OrderType.MarketIncrease,
        isLong: true,
      },
    });

    // Check that User0's order got filled
    expect(await getAccountPositionCount(dataStore, user0.address)).eq(1);

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(0);

    const positionKey0 = getPositionKey(user0.address, ethUsdMarket.marketToken, wnt.address, true);
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0))).eq(0); // positive impact is capped by the impact pool amount which is 0

    // User1 creates a short market decrease, balancing the pool
    await handleOrder(fixture, {
      create: {
        account: user1,
        market: ethUsdMarket,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: expandDecimals(50 * 1000, 6), // $50,000
        sizeDeltaUsd: decimalToFloat(100 * 1000), // 2x position
        acceptablePrice: expandDecimals(5000, 12),
        orderType: OrderType.MarketDecrease,
        isLong: false,
      },
    });

    const negativePI = expandDecimals(4, 17); // 0.4 eth 2,000 usd
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.eq(negativePI);

    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey1))).eq(0); // short position decreased by 100% i.e. closed

    await time.increase(10_000); // 0.00002 ETH/sec * 10,000 sec = 0.2 ETH should be distributed

    // User0 creates a long market decrease to balance the pool
    await handleOrder(fixture, {
      create: {
        account: user0,
        market: ethUsdMarket,
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(1, 18), // $5,000
        sizeDeltaUsd: decimalToFloat(10 * 1000), // 2x position
        acceptablePrice: expandDecimals(4100, 12),
        orderType: OrderType.MarketDecrease,
        isLong: true,
      },
    });

    const positivePI = expandDecimals(4, 16); // 0.04 eth 200 usd
    const distributionAmt = expandDecimals(2, 17); // 0.2 eth

    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0))).eq(0); // long position decreased by 100% i.e. closed

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).to.approximately(
      negativePI.sub(distributionAmt).sub(positivePI),
      expandDecimals(1, 14)
    );
  });
});
