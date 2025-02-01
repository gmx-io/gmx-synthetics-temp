import { expect } from "chai";

import { deployFixture } from "../../utils/fixture";
import { bigNumberify, expandDecimals, decimalToFloat } from "../../utils/math";
import { handleDeposit } from "../../utils/deposit";
import { OrderType, getOrderCount, getOrderKeys, createOrder, handleOrder } from "../../utils/order";
import { getPositionCount, getAccountPositionCount } from "../../utils/position";
import { hashString } from "../../utils/hash";
import { getExecuteParams } from "../../utils/exchange";
import { errorsContract } from "../../utils/error";
import * as keys from "../../utils/keys";

describe("Exchange.PositionOrder", () => {
  const { AddressZero, HashZero } = ethers.constants;

  let fixture;
  let user0, user1;
  let reader,
    dataStore,
    orderHandler,
    referralStorage,
    ethUsdMarket,
    ethUsdSpotOnlyMarket,
    btcUsdMarket,
    wnt,
    wbtc,
    usdc;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0, user1 } = fixture.accounts);
    ({
      reader,
      dataStore,
      orderHandler,
      referralStorage,
      ethUsdMarket,
      ethUsdSpotOnlyMarket,
      btcUsdMarket,
      wnt,
      wbtc,
      usdc,
    } = fixture.contracts);

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(1000, 18),
        shortTokenAmount: expandDecimals(50 * 1000, 6),
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

  it("createOrder validations", async () => {
    const params = {
      market: ethUsdMarket,
      initialCollateralToken: wnt,
      initialCollateralDeltaAmount: bigNumberify(0),
      swapPath: [ethUsdMarket.marketToken],
      sizeDeltaUsd: decimalToFloat(200 * 1000),
      acceptablePrice: expandDecimals(5001, 12),
      executionFee: bigNumberify(0),
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.MarketIncrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
      gasUsageLabel: "createOrder",
    };

    const _createOrderFeatureDisabledKey = keys.createOrderFeatureDisabledKey(
      orderHandler.address,
      OrderType.MarketIncrease
    );

    await dataStore.setBool(_createOrderFeatureDisabledKey, true);

    await expect(createOrder(fixture, { ...params, sender: user0 }))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user0.address, "CONTROLLER");

    await expect(createOrder(fixture, params))
      .to.be.revertedWithCustomError(errorsContract, "DisabledFeature")
      .withArgs(_createOrderFeatureDisabledKey);

    await dataStore.setBool(_createOrderFeatureDisabledKey, false);

    await expect(createOrder(fixture, { ...params, account: { address: AddressZero } })).to.be.revertedWithCustomError(
      errorsContract,
      "EmptyAccount"
    );

    await expect(
      createOrder(fixture, {
        ...params,
        initialCollateralDeltaAmount: bigNumberify(0),
        executionFee: "100000",
        executionFeeToMint: "200",
      })
    ).to.be.revertedWithCustomError(errorsContract, "InsufficientWntAmountForExecutionFee");

    await expect(
      createOrder(fixture, {
        ...params,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        executionFee: "100000",
        executionFeeToMint: "200",
      })
    ).to.be.revertedWithCustomError(errorsContract, "InsufficientWntAmountForExecutionFee");

    // transaction should be reverted if orderType is invalid
    await expect(
      createOrder(fixture, {
        ...params,
        orderType: 100,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        executionFee: "100000",
        executionFeeToMint: "200",
      })
    ).to.be.reverted;

    await expect(
      createOrder(fixture, {
        ...params,
        orderType: OrderType.Liquidation,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        executionFee: "100000",
        executionFeeToMint: "200",
      })
    )
      .to.be.revertedWithCustomError(errorsContract, "OrderTypeCannotBeCreated")
      .withArgs(OrderType.Liquidation);

    for (const orderType of [OrderType.MarketIncrease, OrderType.MarketDecrease]) {
      await expect(
        createOrder(fixture, {
          ...params,
          orderType,
          validFromTime: 1,
        })
      )
        .to.be.revertedWithCustomError(errorsContract, "UnexpectedValidFromTime")
        .withArgs(orderType);
    }

    await expect(
      createOrder(fixture, {
        ...params,
        market: undefined,
        orderType: OrderType.MarketSwap,
        validFromTime: 1,
      })
    )
      .to.be.revertedWithCustomError(errorsContract, "UnexpectedValidFromTime")
      .withArgs(OrderType.MarketSwap);

    await expect(
      createOrder(fixture, {
        ...params,
        market: { marketToken: user1.address, longToken: wnt.address, shortToken: usdc.address },
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        executionFee: "200",
        executionFeeToMint: "200",
      })
    ).to.be.revertedWithCustomError(errorsContract, "EmptyMarket");

    await expect(
      createOrder(fixture, {
        ...params,
        market: ethUsdSpotOnlyMarket,
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        executionFee: "200",
        executionFeeToMint: "200",
      })
    ).to.be.revertedWithCustomError(errorsContract, "InvalidPositionMarket");

    await expect(
      createOrder(fixture, {
        ...params,
        market: ethUsdMarket,
        swapPath: [user1.address],
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        executionFee: "200",
        executionFeeToMint: "200",
      })
    ).to.be.revertedWithCustomError(errorsContract, "EmptyMarket");

    await expect(
      createOrder(fixture, {
        ...params,
        market: ethUsdMarket,
        swapPath: [],
        receiver: { address: AddressZero },
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        executionFee: "200",
        executionFeeToMint: "200",
      })
    ).to.be.revertedWithCustomError(errorsContract, "EmptyReceiver");

    await expect(
      createOrder(fixture, {
        ...params,
        market: ethUsdMarket,
        swapPath: [],
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        sizeDeltaUsd: bigNumberify(0),
        executionFee: "200",
        executionFeeToMint: "200",
      })
    ).to.be.revertedWithCustomError(errorsContract, "EmptyOrder");

    await expect(
      createOrder(fixture, {
        ...params,
        market: ethUsdMarket,
        swapPath: [],
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        sizeDeltaUsd: bigNumberify(10),
        executionFee: "200",
        executionFeeToMint: "200",
        callbackGasLimit: "3000000",
      })
    )
      .to.be.revertedWithCustomError(errorsContract, "MaxCallbackGasLimitExceeded")
      .withArgs("3000000", "2000000");

    await dataStore.setUint(keys.ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR, decimalToFloat(1));

    await expect(
      createOrder(fixture, {
        ...params,
        market: ethUsdMarket,
        swapPath: [],
        initialCollateralToken: usdc,
        initialCollateralDeltaAmount: bigNumberify(0),
        sizeDeltaUsd: bigNumberify(10),
        executionFee: "200",
        executionFeeToMint: "200",
        callbackGasLimit: "2000000",
      })
    )
      .to.be.revertedWithCustomError(errorsContract, "InsufficientExecutionFee")
      .withArgs("2000000016000000", "2200");

    await createOrder(fixture, {
      ...params,
      market: ethUsdMarket,
      swapPath: [],
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: bigNumberify(0),
      sizeDeltaUsd: bigNumberify(10),
      executionFee: "2000000016000000",
      executionFeeToMint: "3000000000000000",
      callbackGasLimit: "2000000",
    });

    const orderKeys = await getOrderKeys(dataStore, 0, 1);
    const order = await reader.getOrder(dataStore.address, orderKeys[0]);

    // execution fee should include the amounts minted from the previous failed txns
    expect(order.numbers.executionFee).eq("3000000000002200");
  });

  it("stores referral code", async () => {
    const referralCode = hashString("referralCode");

    const params = {
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
      referralCode,
    };

    await referralStorage.connect(user1).registerCode(referralCode);

    expect(await referralStorage.traderReferralCodes(user0.address)).eq(HashZero);

    await createOrder(fixture, params);

    expect(await referralStorage.traderReferralCodes(user0.address)).eq(referralCode);
  });

  it("simulateExecuteOrder", async () => {
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

    const orderKeys = await getOrderKeys(dataStore, 0, 1);

    const currentTimestamp = (await ethers.provider.getBlock()).timestamp;

    await expect(
      orderHandler.connect(user0).simulateExecuteOrder(orderKeys[0], {
        primaryTokens: [],
        primaryPrices: [],
        minTimestamp: currentTimestamp,
        maxTimestamp: currentTimestamp,
      })
    )
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user0.address, "CONTROLLER");

    await expect(
      orderHandler.simulateExecuteOrder(orderKeys[0], {
        primaryTokens: [wnt.address, usdc.address],
        primaryPrices: [
          {
            min: expandDecimals(5000, 12),
            max: expandDecimals(5000, 12),
          },
          {
            min: expandDecimals(1, 24),
            max: expandDecimals(1, 24),
          },
        ],
        minTimestamp: currentTimestamp,
        maxTimestamp: currentTimestamp,
      })
    ).to.be.revertedWithCustomError(errorsContract, "EndOfOracleSimulation");
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

    const _executeOrderFeatureDisabledKey = keys.executeOrderFeatureDisabledKey(
      orderHandler.address,
      OrderType.MarketIncrease
    );

    await dataStore.setBool(_executeOrderFeatureDisabledKey, true);

    await expect(
      handleOrder(fixture, {
        create: params,
      })
    )
      .to.be.revertedWithCustomError(errorsContract, "DisabledFeature")
      .withArgs(_executeOrderFeatureDisabledKey);

    await dataStore.setBool(_executeOrderFeatureDisabledKey, false);
  });
});
