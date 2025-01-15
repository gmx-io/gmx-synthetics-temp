import { expect } from "chai";

import { deployFixture } from "../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { handleDeposit } from "../../utils/deposit";
import { OrderType, getOrderCount, handleOrder } from "../../utils/order";
import { getAccountPositionCount } from "../../utils/position";
import { getPoolAmount } from "../../utils/market";
import { getEventData } from "../../utils/event";
import * as keys from "../../utils/keys";

describe("Exchange.SwapOrder", () => {
  let fixture;
  let user0;
  let dataStore, ethUsdMarket, ethUsdSpotOnlyMarket, wnt, usdc;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0 } = fixture.accounts);
    ({ dataStore, ethUsdMarket, ethUsdSpotOnlyMarket, wnt, usdc } = fixture.contracts);

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        shortTokenAmount: expandDecimals(50_000, 6),
      },
    });
  });

  it("executeOrder", async () => {
    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await usdc.balanceOf(user0.address)).eq(0);

    await handleOrder(fixture, {
      create: {
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(10, 18),
        acceptablePrice: 0,
        orderType: OrderType.MarketSwap,
        swapPath: [ethUsdMarket.marketToken],
        gasUsageLabel: "orderHandler.createOrder",
      },
      execute: {
        gasUsageLabel: "orderHandler.executeOrder",
      },
    });

    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await getOrderCount(dataStore)).eq(0);
    expect(await usdc.balanceOf(user0.address)).eq("50000000000");
  });

  it("executeOrder, spot only market", async () => {
    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await usdc.balanceOf(user0.address)).eq(0);

    await handleDeposit(fixture, {
      create: {
        market: ethUsdSpotOnlyMarket,
        shortTokenAmount: expandDecimals(50000, 6),
      },
    });

    await handleOrder(fixture, {
      create: {
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(10, 18),
        acceptablePrice: 0,
        orderType: OrderType.MarketSwap,
        swapPath: [ethUsdSpotOnlyMarket.marketToken],
        gasUsageLabel: "orderHandler.createOrder",
      },
      execute: {
        gasUsageLabel: "orderHandler.executeOrder",
      },
    });

    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await getOrderCount(dataStore)).eq(0);
    expect(await usdc.balanceOf(user0.address)).eq("50000000000");
  });

  it("price impact", async () => {
    // set positive price impact to 0.1% for every $1000 of token imbalance
    // set negative price impact to 0.2% for every $1000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 1000 => 1 * (10 ** -6)
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(1, 6));
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 6));
    await dataStore.setUint(keys.swapImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(0);
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(50_000, 6));

    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, wnt.address))).eq(0);
    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, usdc.address))).eq(0);

    // since the pool has 50,000 USDC, this order should have a positive price impact
    // but since there was no price impact for the initial deposit, the impact pool
    // should be empty and the priceImpactAmount should be zero
    await handleOrder(fixture, {
      create: {
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(5, 18),
        acceptablePrice: 0,
        orderType: OrderType.MarketSwap,
        swapPath: [ethUsdMarket.marketToken],
        gasUsageLabel: "orderHandler.createOrder",
      },
      execute: {
        gasUsageLabel: "orderHandler.executeOrder",
        afterExecution: ({ logs }) => {
          const swapInfoEvent = getEventData(logs, "SwapInfo");
          // since the pool balance is improved by 50,000 USD, the positive price impact should be
          //
          // 50,000 ^ 2 * (10 ** -6) => 2500
          expect(swapInfoEvent.priceImpactUsd).eq("2499999999999999953675116958000000"); // ~2500
          expect(swapInfoEvent.priceImpactAmount).eq(0);
          expect(swapInfoEvent.amountOut).eq(expandDecimals(25_000, 6));
        },
      },
    });

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(5, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(25_000, 6));

    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, wnt.address))).eq(0);
    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, usdc.address))).eq(0);

    // since the pool is mostly balanced, this order should have a negative price impact
    await handleOrder(fixture, {
      create: {
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(1, 18),
        acceptablePrice: 0,
        orderType: OrderType.MarketSwap,
        swapPath: [ethUsdMarket.marketToken],
        gasUsageLabel: "orderHandler.createOrder",
      },
      execute: {
        gasUsageLabel: "orderHandler.executeOrder",
        afterExecution: ({ logs }) => {
          const swapInfoEvent = getEventData(logs, "SwapInfo");
          expect(swapInfoEvent.priceImpactUsd).eq("-199999999999999996247043298000000"); // -200
          expect(swapInfoEvent.priceImpactAmount).eq("-40000000000000000"); // -0.04 ETH, -200 USD
          expect(swapInfoEvent.amountOut).eq(expandDecimals(4800, 6));
        },
      },
    });

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("5960000000000000000"); // 5.96 ETH, 29,800
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(20_200, 6));

    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, wnt.address))).eq(
      "40000000000000000"
    );
    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, usdc.address))).eq(0);

    // this order should have a positive price impact
    await handleOrder(fixture, {
      create: {
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: expandDecimals(5000, 6),
        acceptablePrice: 0,
        orderType: OrderType.MarketSwap,
        swapPath: [ethUsdMarket.marketToken],
        gasUsageLabel: "orderHandler.createOrder",
      },
      execute: {
        gasUsageLabel: "orderHandler.executeOrder",
        afterExecution: ({ logs }) => {
          const swapInfoEvent = getEventData(logs, "SwapInfo");
          expect(swapInfoEvent.priceImpactUsd).eq("91839999999999998574976675000000"); // 91.84 USD
          expect(swapInfoEvent.priceImpactAmount).eq("18367999999999999"); // 0.018367999999999999 ETH, 91.84 USD
          expect(swapInfoEvent.amountOut).eq("1018367999999999999"); // 1.018367999999999999 ETH, 5091.84 USD
        },
      },
    });
  });

  it("positive and negative impact fees", async () => {
    // set positive swap fees to 0.05%
    // set negative swap fees to 0.5%
    await dataStore.setUint(keys.swapFeeFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 4));
    await dataStore.setUint(keys.swapFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 3));

    // set positive price impact to 0.1% for every $1000 of token imbalance
    // set negative price impact to 0.2% for every $1000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 1000 => 1 * (10 ** -6)
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(1, 6));
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(2, 6));
    await dataStore.setUint(keys.swapImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(0);
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(50_000, 6));

    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, wnt.address))).eq(0);
    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, usdc.address))).eq(0);

    // since the pool has 50,000 USDC, this order should have a positive price impact
    // but since there was no price impact for the initial deposit, the impact pool
    // should be empty and the priceImpactAmount should be zero
    await handleOrder(fixture, {
      create: {
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(5, 18),
        acceptablePrice: 0,
        orderType: OrderType.MarketSwap,
        swapPath: [ethUsdMarket.marketToken],
        gasUsageLabel: "orderHandler.createOrder",
      },
      execute: {
        gasUsageLabel: "orderHandler.executeOrder",
        afterExecution: ({ logs }) => {
          const swapInfoEvent = getEventData(logs, "SwapInfo");
          // since the pool balance is improved by 50,000 USD, the positive price impact should be
          //
          // 50,000 ^ 2 * (10 ** -6) = 2500
          // fees: 0.05% * 25,000 = 12.5
          // 25,000 - 12.5 = 24,987.5
          expect(swapInfoEvent.priceImpactUsd).eq("2499999999999999953675116958000000"); // ~2500
          expect(swapInfoEvent.priceImpactAmount).eq(0);
          expect(swapInfoEvent.amountOut).eq("24987500000"); // 24,987.5
        },
      },
    });

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(5, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("25012500000"); // 25,012.5

    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, wnt.address))).eq(0);
    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, usdc.address))).eq(0);

    // since the pool is mostly balanced, this order should have a negative price impact
    await handleOrder(fixture, {
      create: {
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(1, 18),
        acceptablePrice: 0,
        orderType: OrderType.MarketSwap,
        swapPath: [ethUsdMarket.marketToken],
        gasUsageLabel: "orderHandler.createOrder",
      },
      execute: {
        gasUsageLabel: "orderHandler.executeOrder",
        afterExecution: ({ logs }) => {
          const swapInfoEvent = getEventData(logs, "SwapInfo");
          expect(swapInfoEvent.priceImpactUsd).eq("-199500156249999996338625122000000"); // -199.5
          expect(swapInfoEvent.priceImpactAmount).eq("-39900031250000000"); // -0.03990003125 ETH, -199.50015625 USD
          // fees: 5000 * 0.5% = 25 USD
          // 5000 - 25 - 199.50015625 = 4775.49984375 USD
          expect(swapInfoEvent.amountOut).eq("4775499843"); // 4775.499843
        },
      },
    });

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("5960099968750000000"); // 5.96 ETH, 29,800
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("20237000157"); // 20,237.000157

    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, wnt.address))).eq(
      "39900031250000000"
    );
    expect(await dataStore.getUint(keys.swapImpactPoolAmountKey(ethUsdMarket.marketToken, usdc.address))).eq(0);

    // this order should have a positive price impact
    await handleOrder(fixture, {
      create: {
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: expandDecimals(5000, 6),
        acceptablePrice: 0,
        orderType: OrderType.MarketSwap,
        swapPath: [ethUsdMarket.marketToken],
        gasUsageLabel: "orderHandler.createOrder",
      },
      execute: {
        gasUsageLabel: "orderHandler.executeOrder",
        afterExecution: ({ logs }) => {
          const swapInfoEvent = getEventData(logs, "SwapInfo");
          expect(swapInfoEvent.priceImpactUsd).eq("91079461211532650093343730000000"); // 91.0794612115 USD
          expect(swapInfoEvent.priceImpactAmount).eq("18215892242306530"); // 0.01821589224230653 ETH, 91.0794612115 USD
          expect(swapInfoEvent.amountOut).eq("1017715892242306530"); // 1.017715892242306530 ETH, 5088.57946121 USD
        },
      },
    });
  });
});
