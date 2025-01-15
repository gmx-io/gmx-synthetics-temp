import { expect } from "chai";
import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { prices } from "../../utils/prices";
import { handleOrder, OrderType } from "../../utils/order";
import { decimalToFloat, expandDecimals, percentageToFloat } from "../../utils/math";
import * as keys from "../../utils/keys";
import { handleDeposit } from "../../utils/deposit";

describe("MarketUtils", () => {
  let fixture;
  let user0;
  let dataStore, ethUsdMarket, wnt;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0 } = fixture.accounts);
    ({ dataStore, ethUsdMarket, wnt } = fixture.contracts);

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
});
