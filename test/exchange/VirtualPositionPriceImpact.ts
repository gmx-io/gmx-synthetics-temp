import { expect } from "chai";

import { usingResult } from "../../utils/use";
import { hashString } from "../../utils/hash";
import { deployFixture } from "../../utils/fixture";
import { getEventData } from "../../utils/event";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { handleDeposit } from "../../utils/deposit";
import { OrderType, handleOrder } from "../../utils/order";
import { getExecuteParams } from "../../utils/exchange";
import * as keys from "../../utils/keys";

describe("Exchange.VirtualPositionPriceImpact", () => {
  let fixture;
  let dataStore, ethUsdcMarket, ethUsdtMarket, wnt, usdt;

  const ethUsdVirtualTokenId = hashString("PERP:ETH/USD");

  beforeEach(async () => {
    fixture = await deployFixture();

    ({ dataStore, ethUsdtMarket, wnt, usdt } = fixture.contracts);

    ethUsdcMarket = fixture.contracts.ethUsdMarket;

    await dataStore.setBytes32(keys.virtualTokenIdKey(wnt.address), ethUsdVirtualTokenId);

    await handleDeposit(fixture, {
      create: {
        market: ethUsdcMarket,
        longTokenAmount: expandDecimals(1000, 18),
        shortTokenAmount: expandDecimals(5_000_000, 6),
      },
    });

    await handleDeposit(fixture, {
      create: {
        market: ethUsdtMarket,
        longTokenAmount: expandDecimals(1000, 18),
        shortTokenAmount: expandDecimals(5_000_000, 6),
      },
      execute: getExecuteParams(fixture, { tokens: [wnt, usdt] }),
    });
  });

  it("uses virtual inventory for price impact", async () => {
    // set positive price impact to 0.05% for every $100,000 of token imbalance
    // set negative price impact to 0.1% for every $100,000 of token imbalance
    // 0.05% => 0.0005
    // 0.0005 / 100,000 => 5 * (10 ** -9)
    // 0.1% => 0.001
    // 0.001 / 100,000 => 1 * (10 ** -8)
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdcMarket.marketToken, true), decimalToFloat(5, 9));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdcMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdcMarket.marketToken), decimalToFloat(2, 0));

    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdtMarket.marketToken, true), decimalToFloat(5, 9));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdtMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdtMarket.marketToken), decimalToFloat(2, 0));

    // check the base price impact for opening a long position in the ethUsdcMarket
    // the ethUsdcMarket should have an imbalance of more longs than shorts after
    await usingResult(
      handleOrder(fixture, {
        create: {
          market: ethUsdcMarket,
          initialCollateralToken: wnt,
          initialCollateralDeltaAmount: expandDecimals(10, 18),
          sizeDeltaUsd: decimalToFloat(200_000),
          acceptablePrice: 0,
          orderType: OrderType.MarketIncrease,
          gasUsageLabel: "orderHandler.createOrder",
        },
        execute: {
          gasUsageLabel: "orderHandler.executeOrder",
        },
      }),
      async ({ executeResult }) => {
        const { logs } = executeResult;
        const positionIncreaseInfo = getEventData(logs, "PositionIncrease");
        expect(positionIncreaseInfo.priceImpactUsd).eq("-399999999999999992588018713340000"); // -400
      }
    );

    // the price impact for opening a long position in the ethUsdtMarket should be higher
    // compared to the previous price impact due to the virtual price impact
    await usingResult(
      handleOrder(fixture, {
        create: {
          market: ethUsdtMarket,
          initialCollateralToken: wnt,
          initialCollateralDeltaAmount: expandDecimals(10, 18),
          sizeDeltaUsd: decimalToFloat(200_000),
          acceptablePrice: 0,
          orderType: OrderType.MarketIncrease,
          gasUsageLabel: "orderHandler.createOrder",
        },
        execute: {
          gasUsageLabel: "orderHandler.executeOrder",
          ...getExecuteParams(fixture, { tokens: [wnt, usdt] }),
        },
      }),
      async ({ executeResult }) => {
        const { logs } = executeResult;
        const positionIncreaseInfo = getEventData(logs, "PositionIncrease");
        expect(positionIncreaseInfo.priceImpactUsd).eq("-1199999999999999977764056140040000"); // -1200
      }
    );
  });

  it("price impact is positive if it improves the pool's balance, even if the virtual price impact might be negative", async () => {
    // set positive price impact to 0.05% for every $100,000 of token imbalance
    // set negative price impact to 0.1% for every $100,000 of token imbalance
    // 0.05% => 0.0005
    // 0.0005 / 100,000 => 5 * (10 ** -9)
    // 0.1% => 0.001
    // 0.001 / 100,000 => 1 * (10 ** -8)
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdcMarket.marketToken, true), decimalToFloat(5, 9));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdcMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdcMarket.marketToken), decimalToFloat(2, 0));

    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdtMarket.marketToken, true), decimalToFloat(5, 9));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdtMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdtMarket.marketToken), decimalToFloat(2, 0));

    // open a long position in the ethUsdcMarket
    // the ethUsdcMarket should have an imbalance of more longs than shorts after
    await usingResult(
      handleOrder(fixture, {
        create: {
          market: ethUsdcMarket,
          initialCollateralToken: wnt,
          initialCollateralDeltaAmount: expandDecimals(10, 18),
          sizeDeltaUsd: decimalToFloat(200_000),
          orderType: OrderType.MarketIncrease,
          gasUsageLabel: "orderHandler.createOrder",
        },
        execute: {
          gasUsageLabel: "orderHandler.executeOrder",
        },
      }),
      async ({ executeResult }) => {
        const { logs } = executeResult;
        const positionIncreaseInfo = getEventData(logs, "PositionIncrease");
        expect(positionIncreaseInfo.priceImpactUsd).eq("-399999999999999992588018713340000"); // -400
      }
    );

    // open a short position in the ethUsdtMarket
    // the ethUsdtMarket should have an imbalance of more shorts than longs after
    await usingResult(
      handleOrder(fixture, {
        create: {
          market: ethUsdtMarket,
          initialCollateralToken: wnt,
          initialCollateralDeltaAmount: expandDecimals(10, 18),
          sizeDeltaUsd: decimalToFloat(200_000),
          acceptablePrice: expandDecimals(4800, 12),
          orderType: OrderType.MarketIncrease,
          isLong: false,
          gasUsageLabel: "orderHandler.createOrder",
        },
        execute: {
          gasUsageLabel: "orderHandler.executeOrder",
          ...getExecuteParams(fixture, { tokens: [wnt, usdt] }),
        },
      }),
      async ({ executeResult }) => {
        const { logs } = executeResult;
        const positionIncreaseInfo = getEventData(logs, "PositionIncrease");
        expect(positionIncreaseInfo.priceImpactUsd).eq("-399999999999999992588018713340000"); // -400
      }
    );

    // close the short position in the ethUsdtMarket
    // the balance of longs and shorts should improve so there should be a positive price impact
    await usingResult(
      handleOrder(fixture, {
        create: {
          market: ethUsdtMarket,
          initialCollateralToken: wnt,
          initialCollateralDeltaAmount: expandDecimals(10, 18),
          sizeDeltaUsd: decimalToFloat(200_000),
          orderType: OrderType.MarketDecrease,
          isLong: false,
          gasUsageLabel: "orderHandler.createOrder",
        },
        execute: {
          gasUsageLabel: "orderHandler.executeOrder",
          ...getExecuteParams(fixture, { tokens: [wnt, usdt] }),
        },
      }),
      async ({ executeResult }) => {
        const { logs } = executeResult;
        const positionIncreaseInfo = getEventData(logs, "PositionDecrease");
        expect(positionIncreaseInfo.priceImpactUsd).eq(0); // positive impact is capped by the impact pool amount which is 0
      }
    );
  });
});
