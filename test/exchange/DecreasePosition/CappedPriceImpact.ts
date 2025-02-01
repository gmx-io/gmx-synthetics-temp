import { expect } from "chai";

import { usingResult } from "../../../utils/use";
import { scenes } from "../../scenes";
import { deployFixture } from "../../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../../utils/math";
import { getPositionKey, getPendingImpactAmountKey } from "../../../utils/position";
import { getPoolAmount, getMarketTokenPriceWithPoolValue } from "../../../utils/market";
import { prices } from "../../../utils/prices";
import { getClaimableCollateralTimeKey } from "../../../utils/collateral";
import * as keys from "../../../utils/keys";

describe("Exchange.DecreasePosition", () => {
  let fixture;
  let user0, user1;
  let exchangeRouter, reader, dataStore, referralStorage, ethUsdMarket, wnt, usdc;

  beforeEach(async () => {
    fixture = await deployFixture();

    ({ user0, user1 } = fixture.accounts);
    ({ exchangeRouter, reader, dataStore, referralStorage, ethUsdMarket, wnt, usdc } = fixture.contracts);

    await scenes.deposit(fixture);
  });

  it("uncapped price impact", async () => {
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 8));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 7));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq(decimalToFloat(1));
        expect(poolValueInfo.poolValue).eq(decimalToFloat(6_000_000));
      }
    );

    const positionKey0 = getPositionKey(user0.address, ethUsdMarket.marketToken, usdc.address, true);
    const positionKey0Long = positionKey0;
    const positionKey0Short = getPositionKey(user0.address, ethUsdMarket.marketToken, wnt.address, false);

    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq(0);
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);

    await scenes.increasePosition.long(fixture);

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq("-799999999999999986"); // -0.799999999999999986;
    // positive impact is capped by the pool amount (which is 0 at this phase)
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    await scenes.increasePosition.short(fixture);

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq("-799999999999999986"); // -0.799999999999999986;
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    await usingResult(
      reader.getPositionInfo(
        dataStore.address,
        referralStorage.address,
        positionKey0,
        prices.ethUsdMarket,
        0,
        ethers.constants.AddressZero,
        true
      ),
      (positionInfo) => {
        expect(positionInfo.position.numbers.collateralAmount).eq(expandDecimals(50_000, 6));
        expect(positionInfo.position.numbers.sizeInTokens).eq("40000000000000000000"); // 40.0 does not contain the impact
        expect(positionInfo.position.numbers.sizeInUsd).eq(decimalToFloat(200_000));
        expect(positionInfo.basePnlUsd).eq("0");
      }
    );

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq(decimalToFloat(1));
        expect(poolValueInfo.poolValue).eq(decimalToFloat(6_000_000));
      }
    );

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq("-799999999999999986"); // -0.8 ETH
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_000, 6));

    await scenes.decreasePosition.long(fixture, {
      create: {
        receiver: user1,
        initialCollateralDeltaAmount: 0,
      },
    });

    // the impact pool increased by ~0.08 ETH, 440 USD
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq("80000000000000000"); // 0.08 ETH

    // the impact pending amount for long is increased by ~0.08 ETH, 400 USD
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq("-719999999999999988"); // -0.8 + 0.08 = -0.72 ETH
    // the impact pending amount for short doesn't change
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    // 400 USD was paid from the position's collateral for price impact
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_400, 6));

    await usingResult(
      reader.getPositionInfo(
        dataStore.address,
        referralStorage.address,
        positionKey0,
        prices.ethUsdMarket,
        0,
        ethers.constants.AddressZero,
        true
      ),
      (positionInfo) => {
        expect(positionInfo.position.numbers.collateralAmount).eq(expandDecimals(49_560, 6));
        expect(positionInfo.position.numbers.sizeInTokens).eq("36000000000000000000"); // 36.00 - doesn't contain the impact
        expect(positionInfo.position.numbers.sizeInUsd).eq(decimalToFloat(180_000));
        expect(positionInfo.basePnlUsd).eq("0");
      }
    );

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq("1000000000000000000000000000000");
        expect(poolValueInfo.poolValue).eq("6000000000000000000000000000000000000");
      }
    );
  });

  it("capped price impact", async () => {
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 8));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 7));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    await dataStore.setUint(keys.maxPositionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 4));
    await dataStore.setUint(keys.maxPositionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 3));

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq(decimalToFloat(1));
        expect(poolValueInfo.poolValue).eq(decimalToFloat(6_000_000));
      }
    );

    const positionKey0 = getPositionKey(user0.address, ethUsdMarket.marketToken, usdc.address, true);
    const positionKey0Long = positionKey0;
    const positionKey0Short = getPositionKey(user0.address, ethUsdMarket.marketToken, wnt.address, false);

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq(0);
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    await scenes.increasePosition.long(fixture);

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq("-799999999999999986"); // -0.799999999999999986
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    await scenes.increasePosition.short(fixture);

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);
    // no capping on position increase for negative impact, capped by the pool amount and max factor for positive impact
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq("-799999999999999986"); // -0.799999999999999986
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    await usingResult(
      reader.getPositionInfo(
        dataStore.address,
        referralStorage.address,
        positionKey0,
        prices.ethUsdMarket,
        0,
        ethers.constants.AddressZero,
        true
      ),
      (positionInfo) => {
        expect(positionInfo.position.numbers.collateralAmount).eq(expandDecimals(50_000, 6));
        expect(positionInfo.position.numbers.sizeInTokens).eq("40000000000000000000"); // 40.0
        expect(positionInfo.position.numbers.sizeInUsd).eq(decimalToFloat(200_000));
        expect(positionInfo.basePnlUsd).eq("0"); // no pnl from from position increase
      }
    );

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq(decimalToFloat(1));
        expect(poolValueInfo.poolValue).eq(decimalToFloat(6_000_000));
      }
    );

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_000, 6));

    const timeKey = await getClaimableCollateralTimeKey();

    expect(
      await dataStore.getUint(
        keys.claimableCollateralAmountKey(ethUsdMarket.marketToken, usdc.address, timeKey, user0.address)
      )
    ).eq(0);

    await scenes.decreasePosition.long(fixture, {
      create: {
        receiver: user1,
        initialCollateralDeltaAmount: 0,
      },
    });

    // long position decreased by 10% => impact pending amount is decreased by 10% => 0.8 - 0.08 = 0.72
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq("-719999999999999988"); // -0.719999999999999988
    // short position not decreased => position impact pending amount doesn't change
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    expect(
      await dataStore.getUint(
        keys.claimableCollateralAmountKey(ethUsdMarket.marketToken, usdc.address, timeKey, user0.address)
      )
    ).eq(expandDecimals(420, 6));

    // the impact pool increased from 0 by 0.004 ETH, 20 USD
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq("4000000000000000"); // 0.004 ETH

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    // 20 USD was paid from the position's collateral for price impact
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_020, 6));

    await usingResult(
      reader.getPositionInfo(
        dataStore.address,
        referralStorage.address,
        positionKey0,
        prices.ethUsdMarket,
        0,
        ethers.constants.AddressZero,
        true
      ),
      (positionInfo) => {
        expect(positionInfo.position.numbers.collateralAmount).eq(expandDecimals(49_560, 6));
        expect(positionInfo.position.numbers.sizeInTokens).eq("36000000000000000000"); // 36.00 - price impact not included
        expect(positionInfo.position.numbers.sizeInUsd).eq(decimalToFloat(180_000));
        expect(positionInfo.basePnlUsd).eq("0");
      }
    );

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq("1000000000000000000000000000000");
        expect(poolValueInfo.poolValue).eq("6000000000000000000000000000000000000");
      }
    );

    // allow 80% of collateral to be claimed
    await dataStore.setUint(
      keys.claimableCollateralFactorKey(ethUsdMarket.marketToken, usdc.address, timeKey),
      decimalToFloat(8, 1)
    );

    await exchangeRouter
      .connect(user0)
      .claimCollateral([ethUsdMarket.marketToken], [usdc.address], [timeKey], user1.address);

    expect(await usdc.balanceOf(user1.address)).eq(expandDecimals(336, 6));
  });
});
