import { expect } from "chai";

import { deployContract } from "../../utils/deploy";
import { usingResult } from "../../utils/use";
import { getMarketTokenPriceWithPoolValue } from "../../utils/market";
import { deployFixture } from "../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { getSupplyOf } from "../../utils/token";
import { handleDeposit } from "../../utils/deposit";
import { OrderType, getOrderCount, getOrderKeys, createOrder, executeOrder, handleOrder } from "../../utils/order";
import { getPositionCount, getAccountPositionCount, getPositionKeys } from "../../utils/position";
import { getExecuteParams } from "../../utils/exchange";
import { errorsContract } from "../../utils/error";
import * as keys from "../../utils/keys";

describe("Exchange.MarketIncreaseOrder", () => {
  const { provider } = ethers;

  let fixture;
  let user0, user1;
  let reader,
    dataStore,
    orderVault,
    referralStorage,
    ethUsdMarket,
    ethUsdSingleTokenMarket,
    btcUsdMarket,
    wnt,
    wbtc,
    usdc;
  let executionFee;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0, user1 } = fixture.accounts);
    ({
      reader,
      dataStore,
      orderVault,
      referralStorage,
      ethUsdMarket,
      ethUsdSingleTokenMarket,
      btcUsdMarket,
      wnt,
      wbtc,
      usdc,
    } = fixture.contracts);
    ({ executionFee } = fixture.props);

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(1000, 18),
        shortTokenAmount: expandDecimals(1000 * 1000, 6),
      },
    });

    await handleDeposit(fixture, {
      create: {
        market: btcUsdMarket,
        longTokenAmount: expandDecimals(1, 18),
        shortTokenAmount: expandDecimals(50 * 1000, 6),
      },
      execute: getExecuteParams(fixture, { tokens: [wbtc, usdc] }),
    });
  });

  it("createOrder", async () => {
    expect(await getOrderCount(dataStore)).eq(0);
    await dataStore.setUint(keys.MAX_DATA_LENGTH, 256);
    const dataList = [ethers.utils.formatBytes32String("customData")];
    const params = {
      market: ethUsdMarket,
      initialCollateralToken: wnt,
      initialCollateralDeltaAmount: expandDecimals(10, 18),
      swapPath: [ethUsdMarket.marketToken],
      orderType: OrderType.MarketIncrease,
      sizeDeltaUsd: decimalToFloat(200 * 1000),
      acceptablePrice: expandDecimals(5001, 12),
      executionFee,
      minOutputAmount: expandDecimals(50000, 6),
      isLong: true,
      shouldUnwrapNativeToken: false,
      gasUsageLabel: "createOrder",
      cancellationReceiver: user1,
      dataList,
    };

    await createOrder(fixture, params);

    expect(await getOrderCount(dataStore)).eq(1);

    const orderKeys = await getOrderKeys(dataStore, 0, 1);
    const order = await reader.getOrder(dataStore.address, orderKeys[0]);

    expect(order.addresses.account).eq(user0.address);
    expect(order.addresses.market).eq(ethUsdMarket.marketToken);
    expect(order.addresses.initialCollateralToken).eq(wnt.address);
    expect(order.addresses.swapPath).eql([ethUsdMarket.marketToken]);
    expect(order.addresses.cancellationReceiver).eq(user1.address);
    expect(order.numbers.orderType).eq(OrderType.MarketIncrease);
    expect(order.numbers.sizeDeltaUsd).eq(decimalToFloat(200 * 1000));
    expect(order.numbers.initialCollateralDeltaAmount).eq(expandDecimals(10, 18));
    expect(order.numbers.acceptablePrice).eq(expandDecimals(5001, 12));
    expect(order.numbers.executionFee).eq(expandDecimals(1, 15));
    expect(order.numbers.minOutputAmount).eq(expandDecimals(50000, 6));
    expect(order.flags.isLong).eq(true);
    expect(order.flags.shouldUnwrapNativeToken).eq(false);
    expect(order._dataList).deep.eq(dataList);

    await expect(createOrder(fixture, { ...params, cancellationReceiver: orderVault })).to.be.revertedWithCustomError(
      errorsContract,
      "InvalidReceiver"
    );
  });

  it("executeOrder validations", async () => {
    const params = {
      account: user0,
      market: ethUsdMarket,
      initialCollateralToken: wnt,
      initialCollateralDeltaAmount: expandDecimals(1, 18),
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(1000),
      acceptablePrice: expandDecimals(5001, 12),
      executionFee: expandDecimals(1, 15),
      minOutputAmount: 0,
      orderType: OrderType.MarketIncrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
    };

    await handleOrder(fixture, {
      create: {
        ...params,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: expandDecimals(5000, 6),
        swapPath: [btcUsdMarket.marketToken],
      },
      execute: {
        ...getExecuteParams(fixture, { tokens: [wnt, wbtc, usdc] }),
        expectedCancellationReason: "InvalidCollateralTokenForMarket",
      },
    });
  });

  it("executeOrder", async () => {
    expect(await getOrderCount(dataStore)).eq(0);

    const params = {
      account: user0,
      market: ethUsdMarket,
      initialCollateralToken: wnt,
      initialCollateralDeltaAmount: expandDecimals(10, 18),
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(200 * 1000),
      acceptablePrice: expandDecimals(5001, 12),
      executionFee: expandDecimals(1, 15),
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.MarketIncrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
    };

    await createOrder(fixture, params);

    expect(await getOrderCount(dataStore)).eq(1);
    expect(await getAccountPositionCount(dataStore, user0.address)).eq(0);
    expect(await getPositionCount(dataStore)).eq(0);

    await executeOrder(fixture, {
      gasUsageLabel: "executeOrder",
    });

    expect(await getOrderCount(dataStore)).eq(0);
    expect(await getAccountPositionCount(dataStore, user0.address)).eq(1);
    expect(await getPositionCount(dataStore)).eq(1);

    params.account = user1;

    await handleOrder(fixture, {
      create: params,
      execute: {
        gasUsageLabel: "executeOrder",
      },
    });

    expect(await getAccountPositionCount(dataStore, user1.address)).eq(1);
    expect(await getPositionCount(dataStore)).eq(2);
  });

  it("validates collateral amount", async () => {
    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 4)); // 0.05%
    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 4)); // 0.05%

    const params = {
      account: user0,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: expandDecimals(1000, 6),
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(20 * 1000),
      acceptablePrice: expandDecimals(4990, 12),
      executionFee: expandDecimals(1, 15),
      minOutputAmount: expandDecimals(900, 6),
      orderType: OrderType.MarketIncrease,
      isLong: false,
      shouldUnwrapNativeToken: false,
    };

    await handleOrder(fixture, { create: params });

    await handleOrder(fixture, {
      create: { ...params, initialCollateralDeltaAmount: 0, minOutputAmount: 0, account: user1 },
      execute: {
        expectedCancellationReason: "InsufficientCollateralAmount",
      },
    });

    await handleOrder(fixture, {
      create: { ...params, initialCollateralDeltaAmount: expandDecimals(1000, 6), account: user0 },
      execute: {
        tokens: [wnt.address, usdc.address],
        precisions: [8, 18],
        minPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        maxPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        expectedCancellationReason: "LiquidatablePosition",
      },
    });

    await handleOrder(fixture, {
      create: { ...params, initialCollateralDeltaAmount: expandDecimals(2000, 6), account: user0 },
      execute: {
        tokens: [wnt.address, usdc.address],
        precisions: [8, 18],
        minPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        maxPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
      },
    });
  });

  it("refunds execution fee", async () => {
    await dataStore.setUint(keys.EXECUTION_GAS_FEE_MULTIPLIER_FACTOR, decimalToFloat(1));

    const params = {
      account: user0,
      receiver: user1,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: expandDecimals(100 * 1000, 6),
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(100 * 1000),
      acceptablePrice: expandDecimals(4990, 12),
      executionFee: expandDecimals(2, 15),
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.MarketIncrease,
      isLong: false,
      shouldUnwrapNativeToken: false,
    };

    const initialBalance = await provider.getBalance(user1.address);

    await handleOrder(fixture, { create: params });

    expect((await provider.getBalance(user1.address)).sub(initialBalance)).closeTo("129042985032344", "10000000000000");
  });

  it("refund execution fee callback", async () => {
    await dataStore.setUint(keys.EXECUTION_GAS_FEE_MULTIPLIER_FACTOR, decimalToFloat(1));
    const mockCallbackReceiver = await deployContract("MockCallbackReceiver", []);

    const params = {
      account: user0,
      receiver: user1,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: expandDecimals(100 * 1000, 6),
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(100 * 1000),
      acceptablePrice: expandDecimals(4990, 12),
      executionFee: expandDecimals(2, 15),
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.MarketIncrease,
      isLong: false,
      shouldUnwrapNativeToken: false,
      callbackContract: mockCallbackReceiver,
    };

    const initialBalance = await provider.getBalance(user1.address);

    expect(await provider.getBalance(mockCallbackReceiver.address)).eq("0");

    await handleOrder(fixture, { create: params });

    expect((await provider.getBalance(user1.address)).sub(initialBalance)).eq(0);

    expect(await provider.getBalance(mockCallbackReceiver.address)).closeTo("109367984874944", "10000000000000");
  });

  it("validates reserve", async () => {
    const params = {
      account: user0,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: expandDecimals(100 * 1000, 6),
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(300 * 1000),
      acceptablePrice: expandDecimals(4990, 12),
      executionFee: expandDecimals(1, 15),
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.MarketIncrease,
      isLong: false,
      shouldUnwrapNativeToken: false,
    };

    await handleOrder(fixture, { create: params });

    await handleOrder(fixture, {
      create: params,
      execute: {
        expectedCancellationReason: "InsufficientReserve",
      },
    });
  });

  it("validates open interest", async () => {
    await dataStore.setUint(keys.maxOpenInterestKey(ethUsdMarket.marketToken, false), decimalToFloat(200 * 1000));

    const params = {
      account: user0,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: expandDecimals(100 * 1000, 6),
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(150 * 1000),
      acceptablePrice: expandDecimals(4990, 12),
      executionFee: expandDecimals(1, 15),
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.MarketIncrease,
      isLong: false,
      shouldUnwrapNativeToken: false,
    };

    await handleOrder(fixture, { create: params });

    await handleOrder(fixture, {
      create: params,
      execute: {
        expectedCancellationReason: "MaxOpenInterestExceeded",
      },
    });
  });

  it("validates position", async () => {
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 9));
    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.positionImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 4)); // 0.05%
    await dataStore.setUint(keys.positionFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 4)); // 0.05%

    await dataStore.setUint(
      keys.maxPositionImpactFactorForLiquidationsKey(ethUsdMarket.marketToken),
      decimalToFloat(1) // 100%
    );

    const params = {
      account: user0,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: expandDecimals(1000, 6),
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(20 * 1000),
      acceptablePrice: 1,
      executionFee: expandDecimals(1, 15),
      minOutputAmount: expandDecimals(900, 6),
      orderType: OrderType.MarketIncrease,
      isLong: false,
      shouldUnwrapNativeToken: false,
    };

    await handleOrder(fixture, { create: params });

    await handleOrder(fixture, {
      create: { ...params, initialCollateralDeltaAmount: expandDecimals(1000, 6), account: user0 },
      execute: {
        tokens: [wnt.address, usdc.address],
        precisions: [8, 18],
        minPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        maxPrices: [expandDecimals(5500, 4), expandDecimals(1, 6)],
        expectedCancellationReason: "LiquidatablePosition",
      },
    });

    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 7));

    await handleOrder(fixture, {
      create: {
        ...params,
        orderType: OrderType.MarketDecrease,
        initialCollateralDeltaAmount: expandDecimals(800, 6),
        sizeDeltaUsd: decimalToFloat(1 * 1000),
        acceptablePrice: expandDecimals(5000, 12),
      },
      execute: {
        expectedCancellationReason: "LiquidatablePosition",
      },
    });

    await dataStore.setUint(
      keys.maxPositionImpactFactorForLiquidationsKey(ethUsdMarket.marketToken),
      decimalToFloat(1, 2) // 1%
    );

    await handleOrder(fixture, {
      create: { ...params, initialCollateralDeltaAmount: expandDecimals(1000, 6), account: user0 },
    });

    await dataStore.setUint(keys.positionImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 8));

    await dataStore.setUint(keys.MIN_COLLATERAL_USD, decimalToFloat(5000));

    await handleOrder(fixture, {
      create: params,
      execute: {
        expectedCancellationReason: "LiquidatablePosition",
      },
    });

    await dataStore.setUint(keys.MIN_COLLATERAL_USD, decimalToFloat(10));

    await handleOrder(fixture, { create: params });

    await dataStore.setUint(keys.minCollateralFactorKey(ethUsdMarket.marketToken), decimalToFloat(1, 1)); // 10x

    await handleOrder(fixture, {
      create: params,
      execute: {
        expectedCancellationReason: "InsufficientCollateralUsd",
      },
    });
  });

  it("swaps tokens", async () => {
    const params = {
      market: ethUsdMarket,
      initialCollateralToken: wnt,
      initialCollateralDeltaAmount: expandDecimals(10, 18),
      swapPath: [ethUsdMarket.marketToken],
      orderType: OrderType.MarketIncrease,
      sizeDeltaUsd: decimalToFloat(200 * 1000),
      acceptablePrice: expandDecimals(5001, 12),
      executionFee,
      minOutputAmount: expandDecimals(50000, 6),
      isLong: true,
      shouldUnwrapNativeToken: false,
    };

    await handleOrder(fixture, { create: params });

    const block = await provider.getBlock();

    const prices = {
      indexTokenPrice: {
        min: expandDecimals(5000, 12),
        max: expandDecimals(5000, 12),
      },
      longTokenPrice: {
        min: expandDecimals(5000, 12),
        max: expandDecimals(5000, 12),
      },
      shortTokenPrice: {
        min: expandDecimals(1, 24),
        max: expandDecimals(1, 24),
      },
    };

    const positionKeys = await getPositionKeys(dataStore, 0, 10);
    const position0 = await reader.getPositionInfo(
      dataStore.address,
      referralStorage.address,
      positionKeys[positionKeys.length - 1],
      prices,
      0, // sizeDeltaUsd
      ethers.constants.AddressZero,
      true // usePositionSizeAsSizeDeltaUsd
    );

    expect(position0.position.addresses.account).eq(user0.address);
    expect(position0.position.addresses.market).eq(ethUsdMarket.marketToken);
    expect(position0.position.addresses.collateralToken).eq(usdc.address);
    expect(position0.position.numbers.sizeInUsd).eq(decimalToFloat(200 * 1000));
    expect(position0.position.numbers.sizeInTokens).eq(expandDecimals(40, 18));
    expect(position0.position.numbers.collateralAmount).eq(expandDecimals(50000, 6));
    expect(position0.position.numbers.borrowingFactor).eq(0);
    expect(position0.position.numbers.fundingFeeAmountPerSize).eq(0);
    expect(position0.position.numbers.longTokenClaimableFundingAmountPerSize).eq(0);
    expect(position0.position.numbers.shortTokenClaimableFundingAmountPerSize).eq(0);
    expect(position0.position.numbers.increasedAtTime).eq(block.timestamp);
    expect(position0.position.numbers.decreasedAtTime).eq(0);
    expect(position0.position.flags.isLong).eq(true);
  });

  it("single token market", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdSingleTokenMarket,
        shortTokenAmount: expandDecimals(20 * 1000, 6),
      },
    });

    expect(await getSupplyOf(ethUsdSingleTokenMarket.marketToken)).eq(expandDecimals(20 * 1000, 18));
    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, {
        market: ethUsdSingleTokenMarket,
        prices: {
          longTokenPrice: {
            min: expandDecimals(1, 6 + 18),
            max: expandDecimals(1, 6 + 18),
          },
        },
      }),
      async ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq(expandDecimals(1, 30));
        expect(poolValueInfo.poolValue).eq(expandDecimals(20 * 1000, 30));
      }
    );

    await handleOrder(fixture, {
      create: {
        market: ethUsdSingleTokenMarket,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: expandDecimals(5000, 6),
        swapPath: [],
        sizeDeltaUsd: decimalToFloat(1000),
        acceptablePrice: expandDecimals(5001, 12),
        orderType: OrderType.MarketIncrease,
        isLong: true,
      },
      execute: {
        ...getExecuteParams(fixture, { tokens: [wnt, usdc] }),
      },
    });

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, {
        market: ethUsdSingleTokenMarket,
        prices: {
          longTokenPrice: {
            min: expandDecimals(1, 6 + 18),
            max: expandDecimals(1, 6 + 18),
          },
        },
      }),
      async ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq(expandDecimals(1, 30));
        expect(poolValueInfo.poolValue).eq(expandDecimals(20 * 1000, 30));
      }
    );

    await usingResult(
      getMarketTokenPriceWithPoolValue(fixture, {
        market: ethUsdSingleTokenMarket,
        prices: {
          indexTokenPrice: {
            min: expandDecimals(6000, 4 + 8),
            max: expandDecimals(6000, 4 + 8),
          },
          longTokenPrice: {
            min: expandDecimals(1, 6 + 18),
            max: expandDecimals(1, 6 + 18),
          },
        },
      }),
      async ([marketTokenPrice, poolValueInfo]) => {
        expect(marketTokenPrice).eq(expandDecimals(99, 28));
        expect(poolValueInfo.poolValue).eq(expandDecimals(19800, 30));
      }
    );
  });
});
