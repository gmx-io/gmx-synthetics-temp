import { expect } from "chai";

import { scenes } from "../scenes";
import { deployFixture } from "../../utils/fixture";
import { DecreasePositionSwapType } from "../../utils/order";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { getPoolAmount } from "../../utils/market";
import * as keys from "../../utils/keys";
import { usingResult } from "../../utils/use";
import { getEventData } from "../../utils/event";
import { OrderType, handleOrder } from "../../utils/order";
import { getPositionCount, getPositionKeys } from "../../utils/position";
import { getBalanceOf } from "../../utils/token";
import { handleDeposit } from "../../utils/deposit";
import { executeLiquidation } from "../../utils/liquidation";

describe("Guardian.DecreasePositionCollateralUtils", () => {
  let fixture;
  let user0, user1;
  let dataStore, ethUsdMarket, wnt, usdc, reader;

  beforeEach(async () => {
    fixture = await deployFixture();

    ({ user0, user1 } = fixture.accounts);
    ({ dataStore, ethUsdMarket, wnt, usdc, reader } = fixture.contracts);

    await scenes.deposit(fixture);
  });

  it("OrderSizeDeltaAutoUpdated: Estimated Position Value Less Than MIN_COLLATERAL_USD", async () => {
    // Set the MIN_COLLATERAL_USD extremely high so that:
    // (estimatedRemainingCollateralUsd + cache.estimatedRemainingPnlUsd) < params.contracts.dataStore.getUint(Keys.MIN_COLLATERAL_USD).toInt256()
    await dataStore.setUint(keys.MIN_COLLATERAL_USD, decimalToFloat(50_000));

    await handleOrder(fixture, {
      create: {
        market: ethUsdMarket,
        initialCollateralToken: wnt,
        initialCollateralDeltaAmount: expandDecimals(10, 18),
        sizeDeltaUsd: decimalToFloat(200 * 1000),
        acceptablePrice: expandDecimals(5001, 12),
        orderType: OrderType.MarketIncrease,
        isLong: true,
      },
    });

    // Decrease position and verify the order size is auto-updated
    // from $100,000 to $200,000
    await usingResult(
      handleOrder(fixture, {
        create: {
          market: ethUsdMarket,
          initialCollateralToken: wnt,
          initialCollateralDeltaAmount: expandDecimals(9, 18),
          sizeDeltaUsd: decimalToFloat(100 * 1000),
          acceptablePrice: expandDecimals(4000, 12),
          orderType: OrderType.MarketDecrease,
          isLong: true,
        },
      }),
      (result) => {
        const event = getEventData(result.executeResult.logs, "OrderSizeDeltaAutoUpdated");
        expect(event.sizeDeltaUsd).eq(decimalToFloat(100 * 1000));
        expect(event.nextSizeDeltaUsd).eq(decimalToFloat(200 * 1000));
      }
    );

    // No positions remains
    expect(await getPositionCount(dataStore)).eq(0);
  });

  it("getEmptyFees and execution succeeds", async () => {
    // Goal: Get to else case of
    // (collateralCache.result.remainingCostUsd == 0 && collateralCache.result.amountPaidInSecondaryOutputToken == 0)
    // and pass execution (avoid liquidation check failure)

    // This can be done by having a profit, so that even if collateral remaining is 0,
    // validatePosition passes.

    // User creates a long for $700,000
    await scenes.increasePosition.long(fixture, {
      create: {
        sizeDeltaUsd: decimalToFloat(700_000),
        initialCollateralDeltaAmount: expandDecimals(20_000, 6),
      },
    });

    const positionKeys = await getPositionKeys(dataStore, 0, 10);
    const position0 = await reader.getPosition(dataStore.address, positionKeys[0]);

    expect(position0.numbers.sizeInUsd).eq(decimalToFloat(700 * 1000));
    // 700,000 / 5000  => 140
    expect(position0.numbers.sizeInTokens).eq("140000000000000000000"); // 140 ETH

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_000, 6));

    // Position fee factor set which will be emptied on getEmptyFees. Balance was improved, positive fee factor is used.
    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 2)); // 5%

    // Because of Positive PnL, order passes validatePosition
    // even if entire collateral was used to pay fees.
    await scenes.decreasePosition.long.positivePnl(fixture, {
      create: {
        receiver: user1,
        initialCollateralDeltaAmount: 0,
        decreasePositionSwapType: DecreasePositionSwapType.NoSwap,
        sizeDeltaUsd: decimalToFloat(500_000),
      },
      execute: {
        tokens: [wnt.address, usdc.address],
        minPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        maxPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        precisions: [8, 18],
        afterExecution: async ({ logs }) => {
          const feeInfo = getEventData(logs, "PositionFeesCollected");
          // Fees are emptied.
          expect(feeInfo.protocolFeeAmount).eq("0");
          expect(feeInfo.positionFeeFactor).eq("0");
          expect(feeInfo.positionFeeAmountForPool).eq("0");
        },
      },
    });

    expect(await getBalanceOf(usdc.address, user1.address)).to.eq("0");
    // 140 tokens with each token profiting $500
    // 140 * $500 = $70,000
    // (5/7) * $70,000 = $50,000 profit = 9.090909 ETH of profit
    // Position Fee: $500,000 * 0.05 = $25,000 in fees = 20,000 USDC (entire collateral) + 0.90909 ETH

    // ETH Pool Amount = 1,000 ETH - 9.090909 ETH + 0.90909 ETH = 991.818181 ETH
    // USDC Pool Amount = 1,000,000 USDC + 20,000 USDC = 1,020,000 USDC
    // Receiver gets sent: 9.090909 ETH - 0.90909 ETH = 8.181818 ETH
    expect(await getBalanceOf(wnt.address, user1.address)).to.eq("8181818181818181819");
    expect(await getBalanceOf(usdc.address, user1.address)).to.eq("0");
    // Verify Pool Amounts
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("991818181818181818181"); // 991.818181 ETH
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_020_000, 6));

    expect(await getPositionCount(dataStore)).eq(1);
  });

  it("Collateral Delta Auto-Update: initialCollateralDelta > remaining collateral", async () => {
    // Goal: Get to (params.order.initialCollateralDeltaAmount() > values.remainingCollateralAmount) case
    // and pass execution (avoid liquidation check failure)

    // User creates a long for $700,000
    await scenes.increasePosition.long(fixture, {
      create: {
        sizeDeltaUsd: decimalToFloat(700_000),
        initialCollateralDeltaAmount: expandDecimals(20_000, 6),
      },
    });

    const positionKeys = await getPositionKeys(dataStore, 0, 10);
    const position0 = await reader.getPosition(dataStore.address, positionKeys[0]);

    expect(position0.numbers.sizeInUsd).eq(decimalToFloat(700 * 1000));
    // 700,000 / 5000  => 140
    expect(position0.numbers.sizeInTokens).eq("140000000000000000000"); // 140 ETH

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_000, 6));

    // Position fee factor set which will be emptied on getEmptyFees. Balance was improved, positive fee factor is used.
    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 2)); // 5%

    // Entire collateral used to pay fees,
    // so initialCollateralDeltaAmount of 1 USDC will be enough to trigger auto-update
    await scenes.decreasePosition.long.positivePnl(fixture, {
      create: {
        receiver: user1,
        initialCollateralDeltaAmount: expandDecimals(1, 6),
        decreasePositionSwapType: DecreasePositionSwapType.NoSwap,
        sizeDeltaUsd: decimalToFloat(500_000),
      },
      execute: {
        tokens: [wnt.address, usdc.address],
        minPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        maxPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        precisions: [8, 18],
        afterExecution: async ({ logs }) => {
          const autoUpdate = getEventData(logs, "OrderCollateralDeltaAmountAutoUpdated");
          expect(autoUpdate.collateralDeltaAmount).to.eq(expandDecimals(1, 6));
          expect(autoUpdate.nextCollateralDeltaAmount).to.eq(0);
        },
      },
    });

    expect(await getBalanceOf(usdc.address, user1.address)).to.eq("0");
    // 140 tokens with each token profiting $500
    // 140 * $500 = $70,000
    // (5/7) * $70,000 = $50,000 profit = 9.090909 ETH of profit
    // Position Fee: $500,000 * 0.05 = $25,000 in fees = 20,000 USDC (entire collateral) + 0.90909 ETH

    // ETH Pool Amount = 1,000 ETH - 9.090909 ETH + 0.90909 ETH = 991.818181 ETH
    // USDC Pool Amount = 1,000,000 USDC + 20,000 USDC = 1,020,000 USDC
    // Receiver gets sent: 9.090909 ETH - 0.90909 ETH = 8.181818 ETH
    expect(await getBalanceOf(wnt.address, user1.address)).to.eq("8181818181818181819");
    expect(await getBalanceOf(usdc.address, user1.address)).to.eq("0");
    // Verify Pool Amounts
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("991818181818181818181"); // 991.818181 ETH
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_020_000, 6));

    expect(await getPositionCount(dataStore)).eq(1);
  });

  it("Collateral Delta Auto-Update: initialCollateralDelta > price impact diff", async () => {
    // Goal: Get to (params.order.initialCollateralDeltaAmount() > 0 && values.priceImpactDiffUsd > 0) case
    // and pass execution

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        shortTokenAmount: expandDecimals(1_000_000, 6),
      },
    });

    // User creates a long for $700,000
    await scenes.increasePosition.long(fixture, {
      create: {
        sizeDeltaUsd: decimalToFloat(700_000),
        initialCollateralDeltaAmount: expandDecimals(20_000, 6),
      },
    });
    await scenes.increasePosition.short(fixture, {
      create: {
        sizeDeltaUsd: decimalToFloat(700_000),
        initialCollateralDeltaAmount: expandDecimals(4, 18),
      },
    });

    const positionKeys = await getPositionKeys(dataStore, 0, 10);
    const position0 = await reader.getPosition(dataStore.address, positionKeys[0]);

    expect(position0.numbers.sizeInUsd).eq(decimalToFloat(700 * 1000));
    // 700,000 / 5000  => 140
    expect(position0.numbers.sizeInTokens).eq("140000000000000000000"); // 140 ETH

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(2_000_000, 6));

    // Position fee factor set which will be emptied on getEmptyFees
    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 2)); // 5%
    await dataStore.setUint(keys.maxPositionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 3));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    // Entire collateral used to pay fees,
    // so initialCollateralDeltaAmount of 1 USDC will be enough to trigger auto-update
    await scenes.decreasePosition.long.positivePnl(fixture, {
      create: {
        receiver: user1,
        initialCollateralDeltaAmount: expandDecimals(2000, 6),
        decreasePositionSwapType: DecreasePositionSwapType.NoSwap,
        sizeDeltaUsd: decimalToFloat(500_000),
      },
      execute: {
        tokens: [wnt.address, usdc.address],
        minPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        maxPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        precisions: [8, 18],
      },
      afterExecution: async ({ logs }) => {
        const autoUpdate = getEventData(logs, "OrderCollateralDeltaAmountAutoUpdated");
        expect(autoUpdate.collateralDeltaAmount).to.eq(expandDecimals(2000, 6));
        expect(autoUpdate.nextCollateralDeltaAmount).to.eq(0);
      },
    });

    expect(await getBalanceOf(usdc.address, user1.address)).to.eq("0");

    // 140 tokens with each token profiting $500
    // 140 * $500 = $70,000
    // (5/7) * $70,000 = $50,000 profit = 9.090909 ETH of profit
    // Position Fee: $500,000 * 0.05 = $25,000 in fees = 20,000 USDC (entire collateral) + 0.90909 ETH

    // Min Price Impact USD: 0.1% * 500,000 = $500
    // PriceImpact = $500 / $5500 = 0.090909 ETH
    // ETH Pool Amount = 1,000 ETH - 9.090909 ETH (profit) + 0.90909 ETH (fee) + 0.090909 ETH (PI) = 991.90909 ETH
    // USDC Pool Amount = 1,000,000 USDC + 20,000 USDC = 1,020,000 USDC
    // PriceImpactDiff = ~$2000 / $5500 = 0.363636 ETH
    // Receiver gets sent: 9.090909 ETH - 0.90909 ETH (fee) - 0.090909 ETH (PI) - 0.363636 ETH (PI Diff)= 7.7272 ETH
    expect(await getBalanceOf(wnt.address, user1.address)).to.eq("7727272727272727274");
    expect(await getBalanceOf(usdc.address, user1.address)).to.eq("0");
    // Verify Pool Amounts
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("991909090909090909090"); // 991.909 ETH
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(2_020_000, 6));

    expect(await getPositionCount(dataStore)).eq(2);
  });

  it("Liquidatable Position: Negative pnl, positive PI in secondary token, fees paid off", async () => {
    // Goal: Get to else case of
    // (collateralCache.result.remainingCostUsd == 0 && collateralCache.result.amountPaidInSecondaryOutputToken == 0)
    // where fees were paid off but the secondary amount was used (from +PI)

    await dataStore.setUint(keys.MIN_COLLATERAL_USD, decimalToFloat(0));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(7, 9));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    // reserve short tokens to cause decrease position swap to fail
    await scenes.increasePosition.short(fixture, {
      create: {
        sizeDeltaUsd: decimalToFloat(500_000),
      },
    });

    // User creates a long for $700,000
    await scenes.increasePosition.long(fixture, {
      create: {
        sizeDeltaUsd: decimalToFloat(700_000),
        initialCollateralDeltaAmount: expandDecimals(20_700, 6),
      },
    });

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_000, 6));

    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(75, 3));

    // User decreases long by $200,000 to experience positive price impact. Because of the reserves in the market,
    // the swap will fail and the price impact will go to the secondaryOutputAmount.

    // Because there was no collateral remaining  and the PnL is negative, the position
    // will be deemed liquidatable even though all the fees were paid off (and some secondaryOutputAmount may remain).
    await scenes.decreasePosition.long.negativePnl(fixture, {
      create: {
        receiver: user1,
        initialCollateralDeltaAmount: 0,
        decreasePositionSwapType: DecreasePositionSwapType.SwapPnlTokenToCollateralToken,
        sizeDeltaUsd: decimalToFloat(200_000),
      },
      execute: {
        expectedCancellationReason: "LiquidatablePosition",
        tokens: [wnt.address, usdc.address],
        minPrices: [expandDecimals(4858, 4), expandDecimals(1, 6)],
        maxPrices: [expandDecimals(4858, 4), expandDecimals(1, 6)],
        precisions: [8, 18],
      },
    });
  });

  it("Early Return: Fees", async () => {
    // reserve short tokens to cause decrease position swap to fail
    await scenes.increasePosition.short(fixture, {
      create: {
        sizeDeltaUsd: decimalToFloat(500_000),
      },
    });

    // User creates a long for $700,000
    await scenes.increasePosition.long(fixture, {
      create: {
        sizeDeltaUsd: decimalToFloat(700_000),
        initialCollateralDeltaAmount: expandDecimals(7000, 6),
      },
    });

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(1000, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(1_000_000, 6));

    // Make fees very high to force early return for fees
    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 1)); // 50%

    // User will have insufficient funds to pay for fees
    const params = {
      account: user0,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: 0,
      swapPath: [],
      decreasePositionSwapType: DecreasePositionSwapType.SwapPnlTokenToCollateralToken,
      sizeDeltaUsd: decimalToFloat(500_000),
      acceptablePrice: expandDecimals(4800, 12),
      executionFee: expandDecimals(1, 15),
      minOutputAmount: 0,
      orderType: OrderType.MarketDecrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
    };
    await expect(
      handleOrder(fixture, {
        create: params,
        execute: {
          expectedCancellationReason: "InsufficientFundsToPayForCosts",
        },
      })
    );

    // Liquidation goes through
    await executeLiquidation(fixture, {
      account: user0.address,
      market: ethUsdMarket,
      collateralToken: usdc,
      isLong: true,
      minPrices: [expandDecimals(5000, 4), expandDecimals(1, 6)],
      maxPrices: [expandDecimals(5000, 4), expandDecimals(1, 6)],
    });

    expect(await getPositionCount(dataStore)).to.eq(1);
  });
});
