import { expect } from "chai";

import { deployFixture } from "../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { OrderType, handleOrder } from "../../utils/order";
import { getAccountPositionCount, getPositionKeys } from "../../utils/position";
import { getSwapImpactPoolAmount } from "../../utils/market";
import { handleDeposit } from "../../utils/deposit";
import * as keys from "../../utils/keys";
import { getBalanceOf } from "../../utils/token";

describe("Guardian.PriceImpact", () => {
  let fixture;
  let user0, user1;
  let dataStore, ethUsdMarket, wnt, usdc, reader;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0, user1 } = fixture.accounts);
    ({ dataStore, ethUsdMarket, wnt, usdc, reader } = fixture.contracts);

    await handleDeposit(fixture, {
      create: {
        account: user1,
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(1000, 18),
        shortTokenAmount: expandDecimals(1000 * 5000, 6),
      },
    });
  });

  it("Long position receiving positive price impact", async () => {
    // set price impact to 0.1% for every $50,000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 50,000 => 2 * (10 ** -8)
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(2, 8));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await getAccountPositionCount(dataStore, user1.address)).eq(0);

    // User1 creates a market increase unbalancing the pool
    await handleOrder(fixture, {
      create: {
        account: user1,
        market: ethUsdMarket,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: expandDecimals(50 * 1000, 6), // $50,000
        sizeDeltaUsd: decimalToFloat(100 * 1000), // 2x position
        acceptablePrice: expandDecimals(4800, 12),
        orderType: OrderType.MarketIncrease,
        isLong: false,
      },
    });

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

    const positionKeys = await getPositionKeys(dataStore, 0, 2);
    const longPosition = await reader.getPosition(dataStore.address, positionKeys[1]);

    const initialSizeInTokens = expandDecimals(2, 18);

    // Experienced +PI, but size in tokens shold remain the same
    const sizeInTokens = longPosition.numbers.sizeInTokens;
    expect(sizeInTokens).to.eq(initialSizeInTokens);
    expect(sizeInTokens).to.eq("2000000000000000000"); // price impact not applied
  });

  it("Long position receiving negative price impact", async () => {
    // set price impact to 0.1% for every $50,000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 50,000 => 2 * (10 ** -8)
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(2, 8));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await getAccountPositionCount(dataStore, user1.address)).eq(0);

    // User1 creates a market increase unbalancing the pool
    await handleOrder(fixture, {
      create: {
        account: user0,
        market: ethUsdMarket,
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(1, 18), // $5,000
        sizeDeltaUsd: decimalToFloat(10 * 1000), // 2x position
        acceptablePrice: expandDecimals(5005, 12),
        orderType: OrderType.MarketIncrease,
        isLong: true,
      },
    });

    // Check that User0's order got filled
    expect(await getAccountPositionCount(dataStore, user0.address)).eq(1);

    const positionKeys = await getPositionKeys(dataStore, 0, 2);
    const longPosition = await reader.getPosition(dataStore.address, positionKeys[0]);

    const initialSizeInTokens = expandDecimals(2, 18);

    // Experienced -PI, but size in tokens should remain the same
    const sizeInTokens = longPosition.numbers.sizeInTokens;
    expect(sizeInTokens).to.eq(initialSizeInTokens);
    expect(sizeInTokens).to.eq("2000000000000000000"); // price impact not applied
  });

  it("Short position receiving negative price impact", async () => {
    // set price impact to 0.1% for every $50,000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 50,000 => 2 * (10 ** -8)
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(2, 8));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await getAccountPositionCount(dataStore, user1.address)).eq(0);

    // User0 creates a market increase unbalancing the pool
    await handleOrder(fixture, {
      create: {
        account: user0,
        market: ethUsdMarket,
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(1, 18), // $5,000
        sizeDeltaUsd: decimalToFloat(10 * 1000), // 2x position
        acceptablePrice: expandDecimals(5005, 12),
        orderType: OrderType.MarketIncrease,
        isLong: true,
      },
    });

    // Check that User0's order got filled
    expect(await getAccountPositionCount(dataStore, user0.address)).eq(1);

    const positionKeys = await getPositionKeys(dataStore, 0, 2);
    const shortPosition = await reader.getPosition(dataStore.address, positionKeys[0]);

    const initialSizeInTokens = expandDecimals(2, 18);

    // Experienced -PI, but size in tokens should remain the same
    const sizeInTokens = shortPosition.numbers.sizeInTokens;
    expect(sizeInTokens).to.eq(initialSizeInTokens);
    expect(sizeInTokens).to.eq("2000000000000000000"); // price impact not applied
  });

  it("negative price impact for deposit", async () => {
    // set price impact to 0.1% for every $50,000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 50,000 => 2 * (10 ** -8)
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 8));
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(1, 8));
    await dataStore.setUint(keys.swapImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    // User0 creates a deposit unbalancing the market
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(100, 18), // $500,000
      },
    });

    // Check that User0 got negative PI
    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("495000000000000000080000"); // $495,000

    // Check that the pool impact pool got the negative PI
    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("999999999999999984");
  });

  it("Positive price impact for deposit", async () => {
    // set price impact to 0.1% for every $50,000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 50,000 => 2 * (10 ** -8)
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 8));
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(1, 8));
    await dataStore.setUint(keys.swapImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    // User1 creates a deposit unbalancing the market
    await handleDeposit(fixture, {
      create: {
        account: user1,
        market: ethUsdMarket,
        shortTokenAmount: expandDecimals(500 * 1000, 6), // $500,000
      },
    });

    // Check that the price impact pools received tokens from the negative PI
    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("5000000000");

    // User0 creates a deposit to balance the market
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(20, 18), // $100,000
      },
    });

    // Check that User0 got Positive PI
    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("100889999999000000000000"); // $100,889

    // Check that the price impact pools didn't receive anything
    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("0");

    // Check that the impact pool got decreased
    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("4110000001");
  });

  it("0 price impact for deposit", async () => {
    // set price impact to 0.1% for every $50,000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 50,000 => 2 * (10 ** -8)
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 8));
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(1, 8));
    await dataStore.setUint(keys.swapImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    // User0 creates a deposit keeping the market balanced
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(50, 18), // $250,000
        shortTokenAmount: expandDecimals(250 * 1000, 6), // $250,000
      },
    });

    // Check that User0 did not get any PI
    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("500000000000000000000000"); // $500,000

    // Check that the price impact pools didn't receive anything
    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("0");
    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("0");
  });

  it("Deposit both tokens, negative price impact for deposit", async () => {
    // set price impact to 0.1% for every $50,000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 50,000 => 2 * (10 ** -8)
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 8));
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(1, 8));
    await dataStore.setUint(keys.swapImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    // User0 creates a deposit unbalancing the market
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(25, 18), // $125,000
        shortTokenAmount: expandDecimals(250 * 1000, 6), // $250,000
      },
    });

    // Check that User0 got negative PI
    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("374687499999333333335000"); // $374,687

    // Check that the pool impact pool got the negative PI
    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("20833333333333333");
    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("208333334");
  });
});
