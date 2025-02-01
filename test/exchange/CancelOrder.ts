import { expect } from "chai";

import { increaseTime } from "../../utils/time";
import { deployFixture } from "../../utils/fixture";
import { deployContract } from "../../utils/deploy";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { printGasUsage } from "../../utils/gas";
import { handleDeposit } from "../../utils/deposit";
import { errorsContract } from "../../utils/error";
import { OrderType, getOrderCount, getOrderKeys, getAutoCancelOrderKeys, createOrder } from "../../utils/order";
import { getPositionKey } from "../../utils/position";
import * as keys from "../../utils/keys";

describe("Exchange.CancelOrder", () => {
  const { provider } = ethers;

  let fixture;
  let user0, user1;
  let reader, dataStore, exchangeRouter, orderHandler, ethUsdMarket, wnt;
  let executionFee;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0, user1 } = fixture.accounts);
    ({ reader, dataStore, exchangeRouter, orderHandler, ethUsdMarket, wnt } = fixture.contracts);
    ({ executionFee } = fixture.props);

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(1000, 18),
      },
    });
  });

  it("cancelOrder validations", async () => {
    const revertingCallbackReceiver = await deployContract("RevertingCallbackReceiver", []);

    await dataStore.setUint(keys.REQUEST_EXPIRATION_TIME, 300);

    expect(await getOrderCount(dataStore)).eq(0);
    const params = {
      market: ethUsdMarket,
      callbackContract: revertingCallbackReceiver,
      initialCollateralToken: wnt,
      initialCollateralDeltaAmount: expandDecimals(10, 18),
      swapPath: [ethUsdMarket.marketToken],
      sizeDeltaUsd: decimalToFloat(200 * 1000),
      triggerPrice: expandDecimals(5000, 12),
      acceptablePrice: expandDecimals(5001, 12),
      executionFee,
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.MarketIncrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
    };

    await createOrder(fixture, params);

    expect(await getOrderCount(dataStore)).eq(1);

    const orderKeys = await getOrderKeys(dataStore, 0, 1);

    const _cancelOrderFeatureDisabledKey = keys.cancelOrderFeatureDisabledKey(
      orderHandler.address,
      OrderType.MarketIncrease
    );

    await dataStore.setBool(_cancelOrderFeatureDisabledKey, true);

    await expect(exchangeRouter.connect(user1).cancelOrder(orderKeys[0]))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user1.address, "account for cancelOrder");

    expect(await getOrderCount(dataStore)).eq(1);

    await expect(exchangeRouter.connect(user0).cancelOrder(orderKeys[0]))
      .to.be.revertedWithCustomError(errorsContract, "DisabledFeature")
      .withArgs(_cancelOrderFeatureDisabledKey);

    expect(await getOrderCount(dataStore)).eq(1);

    await dataStore.setBool(_cancelOrderFeatureDisabledKey, false);

    await expect(exchangeRouter.connect(user0).cancelOrder(orderKeys[0])).to.be.revertedWithCustomError(
      errorsContract,
      "RequestNotYetCancellable"
    );
  });

  it("cancelOrder", async () => {
    expect(await getOrderCount(dataStore)).eq(0);
    const params = {
      market: ethUsdMarket,
      initialCollateralToken: wnt,
      initialCollateralDeltaAmount: expandDecimals(10, 18),
      swapPath: [ethUsdMarket.marketToken],
      sizeDeltaUsd: decimalToFloat(200 * 1000),
      triggerPrice: expandDecimals(5000, 12),
      acceptablePrice: expandDecimals(5001, 12),
      executionFee,
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.LimitIncrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
    };

    await createOrder(fixture, params);

    expect(await getOrderCount(dataStore)).eq(1);

    const orderKeys = await getOrderKeys(dataStore, 0, 1);
    const order = await reader.getOrder(dataStore.address, orderKeys[0]);

    expect(order.addresses.account).eq(user0.address);
    expect(order.addresses.market).eq(ethUsdMarket.marketToken);
    expect(order.addresses.initialCollateralToken).eq(wnt.address);
    expect(order.addresses.swapPath).eql([ethUsdMarket.marketToken]);
    expect(order.addresses.cancellationReceiver).eq(user0.address);
    expect(order.numbers.orderType).eq(OrderType.LimitIncrease);
    expect(order.numbers.sizeDeltaUsd).eq(decimalToFloat(200 * 1000));
    expect(order.numbers.initialCollateralDeltaAmount).eq(expandDecimals(10, 18));
    expect(order.numbers.acceptablePrice).eq(expandDecimals(5001, 12));
    expect(order.numbers.triggerPrice).eq(expandDecimals(5000, 12));
    expect(order.numbers.executionFee).eq(expandDecimals(1, 15));
    expect(order.numbers.minOutputAmount).eq(expandDecimals(50000, 6));
    expect(order.flags.isLong).eq(true);
    expect(order.flags.shouldUnwrapNativeToken).eq(false);

    const refTime = (await ethers.provider.getBlock()).timestamp;
    await increaseTime(refTime, 300);

    const txn = await exchangeRouter.connect(user0).cancelOrder(orderKeys[0]);

    await printGasUsage(provider, txn, "cancelOrder");
    expect(await getOrderCount(dataStore)).eq(0);

    await expect(exchangeRouter.connect(user0).cancelOrder(orderKeys[0])).to.be.revertedWithCustomError(
      errorsContract,
      "EmptyOrder"
    );
  });

  it("cancelOrder, autoCancel: true", async () => {
    expect(await getOrderCount(dataStore)).eq(0);
    const params = {
      market: ethUsdMarket,
      initialCollateralToken: wnt,
      initialCollateralDeltaAmount: expandDecimals(10, 18),
      swapPath: [ethUsdMarket.marketToken],
      sizeDeltaUsd: decimalToFloat(200 * 1000),
      triggerPrice: expandDecimals(5000, 12),
      acceptablePrice: expandDecimals(5001, 12),
      executionFee,
      minOutputAmount: expandDecimals(50000, 6),
      orderType: OrderType.LimitDecrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
      autoCancel: true,
    };

    await createOrder(fixture, params);

    expect(await getOrderCount(dataStore)).eq(1);

    const orderKeys = await getOrderKeys(dataStore, 0, 1);
    const order = await reader.getOrder(dataStore.address, orderKeys[0]);

    expect(order.addresses.account).eq(user0.address);
    expect(order.addresses.market).eq(ethUsdMarket.marketToken);
    expect(order.addresses.initialCollateralToken).eq(wnt.address);
    expect(order.addresses.swapPath).eql([ethUsdMarket.marketToken]);
    expect(order.numbers.orderType).eq(OrderType.LimitDecrease);
    expect(order.numbers.sizeDeltaUsd).eq(decimalToFloat(200 * 1000));
    expect(order.numbers.initialCollateralDeltaAmount).eq(expandDecimals(10, 18));
    expect(order.numbers.acceptablePrice).eq(expandDecimals(5001, 12));
    expect(order.numbers.triggerPrice).eq(expandDecimals(5000, 12));
    expect(order.numbers.executionFee).eq(expandDecimals(1, 15));
    expect(order.numbers.minOutputAmount).eq(expandDecimals(50000, 6));
    expect(order.flags.isLong).eq(true);
    expect(order.flags.shouldUnwrapNativeToken).eq(false);

    const positionKey = getPositionKey(
      order.addresses.account,
      order.addresses.market,
      order.addresses.initialCollateralToken,
      order.flags.isLong
    );

    expect(await getAutoCancelOrderKeys(dataStore, positionKey, 0, 10)).eql([orderKeys[0]]);

    const refTime = (await ethers.provider.getBlock()).timestamp;
    await increaseTime(refTime, 300);

    const txn = await exchangeRouter.connect(user0).cancelOrder(orderKeys[0]);
    expect(await getAutoCancelOrderKeys(dataStore, positionKey, 0, 10)).eql([]);

    await printGasUsage(provider, txn, "cancelOrder");
    expect(await getOrderCount(dataStore)).eq(0);

    await expect(exchangeRouter.connect(user0).cancelOrder(orderKeys[0])).to.be.revertedWithCustomError(
      errorsContract,
      "EmptyOrder"
    );
  });
});
