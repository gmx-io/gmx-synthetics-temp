import { expect } from "chai";
import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { prices } from "../../utils/prices";
import { handleOrder, OrderType } from "../../utils/order";
import { decimalToFloat, expandDecimals, percentageToFloat } from "../../utils/math";
import * as keys from "../../utils/keys";
import { handleDeposit } from "../../utils/deposit";
import { scenes } from "../scenes";
import { getClaimableCollateralTimeKey } from "../../utils/collateral";
import { errorsContract } from "../../utils/error";
import { increaseTime } from "../../utils/time";

describe("MarketUtils", () => {
  let fixture;
  let user0, user1;
  let dataStore, exchangeRouter, ethUsdMarket, wnt, usdc;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0, user1 } = fixture.accounts);
    ({ dataStore, exchangeRouter, ethUsdMarket, wnt, usdc } = fixture.contracts);

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(1000, 18),
        shortTokenAmount: expandDecimals(1_000_000, 6),
      },
    });
  });

  it("getUsageFactor doesn't account for open interest", async () => {
    await handleOrder(fixture, {
      create: {
        account: user0,
        market: ethUsdMarket,
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(10, 18),
        swapPath: [],
        sizeDeltaUsd: decimalToFloat(200_000),
        acceptablePrice: expandDecimals(5050, 12),
        executionFee: expandDecimals(1, 15),
        minOutputAmount: 0,
        orderType: OrderType.MarketIncrease,
        isLong: true,
        shouldUnwrapNativeToken: false,
      },
    });

    const marketUtilsTest = await deployContract("MarketUtilsTest", []);
    const poolUsd = await marketUtilsTest.getPoolUsdWithoutPnl(
      dataStore.address,
      ethUsdMarket,
      prices.ethUsdMarket,
      true,
      true
    );
    const reservedUsd = await marketUtilsTest.getReservedUsd(
      dataStore.address,
      ethUsdMarket,
      prices.ethUsdMarket,
      true
    );
    let usageFactor = await marketUtilsTest.getUsageFactor(dataStore.address, ethUsdMarket, true, reservedUsd, poolUsd);

    const openInterest = await dataStore.getUint(keys.openInterestKey(ethUsdMarket.marketToken, wnt.address, true));
    let maxOpenInterest = await dataStore.getUint(keys.maxOpenInterestKey(ethUsdMarket.marketToken, true));

    expect(usageFactor).eq(percentageToFloat("8%"));
    expect(openInterest).eq(decimalToFloat(200_000));
    expect(maxOpenInterest).eq(decimalToFloat(1_000_000_000));

    await dataStore.setUint(keys.maxOpenInterestKey(ethUsdMarket.marketToken, true), decimalToFloat(400_000));

    usageFactor = await marketUtilsTest.getUsageFactor(dataStore.address, ethUsdMarket, true, reservedUsd, poolUsd);
    maxOpenInterest = await dataStore.getUint(keys.maxOpenInterestKey(ethUsdMarket.marketToken, true));
    expect(usageFactor).eq(percentageToFloat("8%"));
    expect(maxOpenInterest).eq(decimalToFloat(400_000));

    usageFactor = await marketUtilsTest.getUsageFactor(dataStore.address, ethUsdMarket, true, reservedUsd, poolUsd);
    maxOpenInterest = await dataStore.getUint(keys.maxOpenInterestKey(ethUsdMarket.marketToken, true));

    expect(usageFactor).eq(percentageToFloat("8%"));
    expect(openInterest).eq(decimalToFloat(200_000));
    expect(maxOpenInterest).eq(decimalToFloat(400_000));
    expect(usageFactor).eq(percentageToFloat("8%"));
  });

  it("claimCollateral applies claimableReductionFactor correctly before timeDelay", async () => {
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 7));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));
    await dataStore.setUint(keys.maxPositionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 3));

    const timeKey = await getClaimableCollateralTimeKey();
    const timeDelay = 24 * 60 * 60; // 1 day = 86400 seconds
    const claimableAmountKey = keys.claimableCollateralAmountKey(
      ethUsdMarket.marketToken,
      usdc.address,
      timeKey,
      user0.address
    );
    const claimableFactorKey = keys.claimableCollateralFactorForAccountKey(
      ethUsdMarket.marketToken,
      usdc.address,
      timeKey,
      user0.address
    );
    const claimableReductionFactorKey = keys.claimableCollateralReductionFactorForAccountKey(
      ethUsdMarket.marketToken,
      usdc.address,
      timeKey,
      user0.address
    );

    const claimableDelayKey = keys.CLAIMABLE_COLLATERAL_DELAY;
    await dataStore.setUint(claimableDelayKey, timeDelay); // 1 day

    await scenes.increasePosition.long(fixture);
    await scenes.decreasePosition.long(fixture);

    expect(await dataStore.getUint(claimableAmountKey)).eq(expandDecimals(380, 6)); // $380 can be claimed

    // Scenario 1:
    // claimableFactor = 0, claimableReductionFactor = 0, claimableCollateralDelay = 1 day
    expect(await dataStore.getUint(claimableFactorKey)).eq(0);
    expect(await dataStore.getUint(claimableReductionFactorKey)).eq(0);
    expect(await dataStore.getUint(claimableDelayKey)).eq(timeDelay); // 1 day

    // time delay has NOT passed yet
    // claimableFactor = 0
    await expect(
      exchangeRouter
        .connect(user0)
        .claimCollateral([ethUsdMarket.marketToken], [usdc.address], [timeKey], user1.address)
    ).to.be.revertedWithCustomError(errorsContract, "CollateralAlreadyClaimed");

    // Scenario 2:
    // claimableFactor = 0, claimableReductionFactor = 80%, claimableCollateralDelay = 1 day
    await dataStore.setUint(claimableReductionFactorKey, decimalToFloat(8, 1)); // 80%
    expect(await dataStore.getUint(claimableReductionFactorKey)).eq(decimalToFloat(8, 1));

    // time delay has NOT passed yet AND claimableFactor < claimableReductionFactor
    // claimableFactor = 0
    await expect(
      exchangeRouter
        .connect(user0)
        .claimCollateral([ethUsdMarket.marketToken], [usdc.address], [timeKey], user1.address)
    ).to.be.revertedWithCustomError(errorsContract, "CollateralAlreadyClaimed");

    // Scenario 3:
    // claimableFactor = 100%, claimableReductionFactor = 80%, claimableCollateralDelay = 1 day
    await dataStore.setUint(claimableFactorKey, decimalToFloat(1)); // 100%
    await dataStore.setUint(claimableReductionFactorKey, decimalToFloat(8, 1)); // 80%
    expect(await dataStore.getUint(claimableReductionFactorKey)).eq(decimalToFloat(8, 1));

    // time delay has NOT passed yet AND claimableFactor > claimableReductionFactor
    // claimableFactor = claimableReductionFactor (i.e. 80%)
    // $380 is the claimableAmount, but it's reduced by 80%
    // 380 - 0.8 * 380 = 380 - 304 = 76
    expect(await usdc.balanceOf(user1.address)).eq(0);
    await exchangeRouter
      .connect(user0)
      .claimCollateral([ethUsdMarket.marketToken], [usdc.address], [timeKey], user1.address);
    expect(await usdc.balanceOf(user1.address)).eq(expandDecimals(76, 6));

    // Scenario 4:
    // claimableFactor = 100%, claimableReductionFactor = 80%, claimableCollateralDelay = 1 day, time advanced by 1 day
    await dataStore.setUint(claimableFactorKey, decimalToFloat(1)); // 100%
    await dataStore.setUint(claimableReductionFactorKey, decimalToFloat(8, 1)); // 80%
    expect(await dataStore.getUint(claimableReductionFactorKey)).eq(decimalToFloat(8, 1));

    // advance time by 1 day
    const refTime = timeKey * 60 * 60;
    await increaseTime(refTime, timeDelay);

    // time delay HAS passed but claimableFactor and claimableReductionFactor have not changed
    // all available collataral was already claimed
    await expect(
      exchangeRouter
        .connect(user0)
        .claimCollateral([ethUsdMarket.marketToken], [usdc.address], [timeKey], user1.address)
    ).to.be.revertedWithCustomError(errorsContract, "CollateralAlreadyClaimed");
  });

  it("claimCollateral applies claimableReductionFactor correctly after timeDelay", async () => {
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 7));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));
    await dataStore.setUint(keys.maxPositionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 3));

    const timeKey = await getClaimableCollateralTimeKey();
    const timeDelay = 24 * 60 * 60; // 1 day = 86400 seconds
    const claimableAmountKey = keys.claimableCollateralAmountKey(
      ethUsdMarket.marketToken,
      usdc.address,
      timeKey,
      user0.address
    );
    const claimableFactorKey = keys.claimableCollateralFactorForAccountKey(
      ethUsdMarket.marketToken,
      usdc.address,
      timeKey,
      user0.address
    );
    const claimableReductionFactorKey = keys.claimableCollateralReductionFactorForAccountKey(
      ethUsdMarket.marketToken,
      usdc.address,
      timeKey,
      user0.address
    );

    const claimableDelayKey = keys.CLAIMABLE_COLLATERAL_DELAY;
    await dataStore.setUint(claimableDelayKey, timeDelay); // 1 day

    await scenes.increasePosition.long(fixture);
    await scenes.decreasePosition.long(fixture);

    expect(await dataStore.getUint(claimableAmountKey)).eq(expandDecimals(380, 6)); // $380 can be claimed

    // Scenario 1:
    // claimableFactor = 0, claimableReductionFactor = 0, claimableCollateralDelay = 1 day
    expect(await dataStore.getUint(claimableFactorKey)).eq(0);
    expect(await dataStore.getUint(claimableReductionFactorKey)).eq(0);
    expect(await dataStore.getUint(claimableDelayKey)).eq(timeDelay); // 1 day

    // time delay has NOT passed yet
    // claimableFactor = 0
    await expect(
      exchangeRouter
        .connect(user0)
        .claimCollateral([ethUsdMarket.marketToken], [usdc.address], [timeKey], user1.address)
    ).to.be.revertedWithCustomError(errorsContract, "CollateralAlreadyClaimed");

    // Scenario 2:
    // claimableFactor = 0, claimableReductionFactor = 0, claimableCollateralDelay = 1 day
    // advance time by 1 day
    const refTime = timeKey * 60 * 60;
    await increaseTime(refTime, timeDelay);

    // claimable factors are 0, but timeDelay has passed => all available collateral is claimed
    expect(await usdc.balanceOf(user1.address)).eq(0);
    await exchangeRouter
      .connect(user0)
      .claimCollateral([ethUsdMarket.marketToken], [usdc.address], [timeKey], user1.address);
    expect(await usdc.balanceOf(user1.address)).eq(expandDecimals(380, 6));
  });
});
