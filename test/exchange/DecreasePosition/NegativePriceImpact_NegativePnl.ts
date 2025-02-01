import { expect } from "chai";

import { usingResult } from "../../../utils/use";
import { scenes } from "../../scenes";
import { deployFixture } from "../../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../../utils/math";
import { getPositionKey, getPendingImpactAmountKey } from "../../../utils/position";
import { getPoolAmount, getMarketTokenPriceWithPoolValue } from "../../../utils/market";
import { prices } from "../../../utils/prices";
import * as keys from "../../../utils/keys";

describe("Exchange.DecreasePosition", () => {
  let fixture;
  let user0, user1;
  let reader, dataStore, referralStorage, ethUsdMarket, wnt, usdc;

  beforeEach(async () => {
    fixture = await deployFixture();

    ({ user0, user1 } = fixture.accounts);
    ({ reader, dataStore, referralStorage, ethUsdMarket, wnt, usdc } = fixture.contracts);

    await scenes.deposit(fixture);
  });

  it("negative price impact, negative pnl", async () => {
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 9));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq(decimalToFloat(1));
        expect(poolValueInfo.poolValue).eq(decimalToFloat(6_000_000));
      }
    );

    await scenes.increasePosition.long(fixture);
    await scenes.increasePosition.short(fixture);

    const positionKey0 = getPositionKey(user0.address, ethUsdMarket.marketToken, usdc.address, true);

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

    const positionKey0Long = getPositionKey(user0.address, ethUsdMarket.marketToken, usdc.address, true);
    const positionKey0Short = getPositionKey(user0.address, ethUsdMarket.marketToken, wnt.address, false);

    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq(0);
    const positionImpactPendingAmount0Long = await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long));
    const positionImpactPendingAmount0Short = await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short));
    expect(positionImpactPendingAmount0Long).eq("-79999999999999999"); // -0.079999999999999999;
    expect(positionImpactPendingAmount0Short).eq(0);
    expect(positionImpactPendingAmount0Long.add(positionImpactPendingAmount0Short).toString()).eq("-79999999999999999"); // -0.079999999999999999

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

    // the impact pool increased by 0.0088 ETH, 44 USD
    expect(await dataStore.getUint(keys.positionImpactPoolAmountKey(ethUsdMarket.marketToken))).eq("8800000000000000"); // 0.0088 ETH
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Long))).eq("-72000000000000000"); // -0.072 (position decreased by 10%)
    expect(await dataStore.getInt(getPendingImpactAmountKey(positionKey0Short))).eq(0);

    // since there is no pnl from position increase/decrease and initialCollateralDeltaAmount for decrease was set to 0, user1 doesn't receive any tokens
    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    // the positive price impact is in WNT, and was deducted from user's collateral (poolAmount increased by $44, collateralAmount decreased by $44)
    // the DecreasePositionCollateralUtils.payForCost function deducts from the collateral first before the secondaryOutputAmount
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_044, 6));

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
        expect(positionInfo.position.numbers.collateralAmount).eq(expandDecimals(49_956, 6));
        expect(positionInfo.position.numbers.sizeInTokens).eq("36000000000000000000"); // 36.00
        expect(positionInfo.position.numbers.sizeInUsd).eq(decimalToFloat(180_000));
        expect(positionInfo.basePnlUsd).eq(decimalToFloat(0));
      }
    );

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq("1000000000000000000000000000000");
        expect(poolValueInfo.poolValue).eq("6000000000000000000000000000000000000");
        expect(poolValueInfo.longPnl).eq(0);
        expect(poolValueInfo.shortPnl).eq(0);
        expect(poolValueInfo.netPnl).eq(0);
      }
    );

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, { prices: prices.ethUsdMarket.increased }),
      ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq("1003346637333333333333333333333");
        expect(poolValueInfo.poolValue).eq("6020079824000000000000000000000000000");
        expect(poolValueInfo.longPnl).eq("720000000000000000000000000000000"); // 720
        expect(poolValueInfo.shortPnl).eq("-800000000000000000000000000000000"); // -800
        expect(poolValueInfo.netPnl).eq("-80000000000000000000000000000000"); // -80
      }
    );
  });
});
