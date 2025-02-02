import { expect } from "chai";

import { usingResult } from "../../utils/use";
import { deployFixture } from "../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { hashString } from "../../utils/hash";
import { errorsContract } from "../../utils/error";
import { getSubaccounts } from "../../utils/subaccount";
import { handleDeposit } from "../../utils/deposit";
import { OrderType, DecreasePositionSwapType, getOrderKeys, createOrder, executeOrder } from "../../utils/order";
import { getPositionKeys } from "../../utils/position";
import { createAccount } from "../../utils/account";
import { prices } from "../../utils/prices";
import * as keys from "../../utils/keys";

describe("SubaccountRouter", () => {
  let fixture;
  let user0, user1, user2;
  let reader, dataStore, referralStorage, router, subaccountRouter, orderVault, ethUsdMarket, wnt, usdc;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0, user1, user2 } = fixture.accounts);
    ({ reader, dataStore, referralStorage, router, subaccountRouter, orderVault, ethUsdMarket, wnt, usdc } =
      fixture.contracts);

    await wnt.mint(user0.address, expandDecimals(1, 18));
    await wnt.connect(user0).approve(router.address, expandDecimals(1000, 18));

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(1000, 18),
        shortTokenAmount: expandDecimals(1000 * 1000, 6),
      },
    });
  });

  it("addSubaccount", async () => {
    expect(await getSubaccounts(dataStore, user0.address, 0, 10)).eql([]);
    await subaccountRouter.connect(user0).addSubaccount(user1.address);
    expect(await getSubaccounts(dataStore, user0.address, 0, 10)).eql([user1.address]);
  });

  it("removeSubaccount", async () => {
    expect(await getSubaccounts(dataStore, user0.address, 0, 10)).eql([]);
    await subaccountRouter.connect(user0).addSubaccount(user1.address);
    expect(await getSubaccounts(dataStore, user0.address, 0, 10)).eql([user1.address]);
    await subaccountRouter.connect(user0).removeSubaccount(user2.address);
    expect(await getSubaccounts(dataStore, user0.address, 0, 10)).eql([user1.address]);
    await subaccountRouter.connect(user0).removeSubaccount(user1.address);
    expect(await getSubaccounts(dataStore, user0.address, 0, 10)).eql([]);
  });

  it("setMaxAllowedSubaccountActionCount", async () => {
    expect(
      await dataStore.getUint(
        keys.maxAllowedSubaccountActionCountKey(user0.address, user1.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(0);

    await subaccountRouter
      .connect(user0)
      .setMaxAllowedSubaccountActionCount(user1.address, keys.SUBACCOUNT_ORDER_ACTION, 21);

    expect(
      await dataStore.getUint(
        keys.maxAllowedSubaccountActionCountKey(user0.address, user1.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(21);
  });

  it("setSubaccountAutoTopUpAmount", async () => {
    expect(await dataStore.getUint(keys.subaccountAutoTopUpAmountKey(user0.address, user1.address))).eq(0);

    await subaccountRouter.connect(user0).setSubaccountAutoTopUpAmount(user1.address, 101);

    expect(await dataStore.getUint(keys.subaccountAutoTopUpAmountKey(user0.address, user1.address))).eq(101);
  });

  it("MarketIncrease order", async () => {
    const subaccount = createAccount();

    expect(await subaccount.getBalance()).eq(0);
    expect(await getSubaccounts(dataStore, user0.address, 0, 10)).eql([]);
    expect(
      await dataStore.getUint(
        keys.maxAllowedSubaccountActionCountKey(user0.address, user1.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(0);

    expect(await dataStore.getUint(keys.subaccountAutoTopUpAmountKey(user0.address, user1.address))).eq(0);

    await subaccountRouter
      .connect(user0)
      .multicall(
        [
          subaccountRouter.interface.encodeFunctionData("sendNativeToken", [subaccount.address, expandDecimals(1, 18)]),
          subaccountRouter.interface.encodeFunctionData("addSubaccount", [subaccount.address]),
          subaccountRouter.interface.encodeFunctionData("setMaxAllowedSubaccountActionCount", [
            subaccount.address,
            keys.SUBACCOUNT_ORDER_ACTION,
            20,
          ]),
          subaccountRouter.interface.encodeFunctionData("setSubaccountExpiresAt", [
            subaccount.address,
            keys.SUBACCOUNT_ORDER_ACTION,
            9999999999,
          ]),
          subaccountRouter.interface.encodeFunctionData("setSubaccountAutoTopUpAmount", [
            subaccount.address,
            expandDecimals(2, 17),
          ]),
        ],
        { value: expandDecimals(1, 18) }
      );

    expect(await subaccount.getBalance()).eq(expandDecimals(1, 18));
    expect(await getSubaccounts(dataStore, user0.address, 0, 10)).eql([subaccount.address]);
    expect(
      await dataStore.getUint(
        keys.maxAllowedSubaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(20);
    expect(await dataStore.getUint(keys.subaccountAutoTopUpAmountKey(user0.address, subaccount.address))).eq(
      expandDecimals(2, 17)
    );

    await subaccountRouter.connect(user0).removeSubaccount(subaccount.address);

    await subaccountRouter
      .connect(user0)
      .setMaxAllowedSubaccountActionCount(subaccount.address, keys.SUBACCOUNT_ORDER_ACTION, 0);

    const referralCode = hashString("referralCode");
    await dataStore.setUint(keys.MAX_DATA_LENGTH, 256);
    const dataList = [ethers.utils.formatBytes32String("customData")];
    const params = {
      addresses: {
        receiver: subaccount.address,
        cancellationReceiver: subaccount.address,
        callbackContract: user2.address,
        uiFeeReceiver: user1.address,
        market: ethUsdMarket.marketToken,
        initialCollateralToken: usdc.address,
        swapPath: [ethUsdMarket.marketToken],
      },
      numbers: {
        sizeDeltaUsd: decimalToFloat(1000),
        initialCollateralDeltaAmount: expandDecimals(100, 6),
        triggerPrice: decimalToFloat(4800),
        acceptablePrice: decimalToFloat(4900),
        executionFee: expandDecimals(1, 17),
        callbackGasLimit: "200000",
        minOutputAmount: 700,
        validFromTime: 0,
      },
      orderType: OrderType.Liquidation,
      decreasePositionSwapType: DecreasePositionSwapType.SwapCollateralTokenToPnlToken,
      isLong: true,
      shouldUnwrapNativeToken: true,
      referralCode,
      dataList,
    };

    await expect(subaccountRouter.connect(subaccount).createOrder(user0.address, { ...params }))
      .to.be.revertedWithCustomError(errorsContract, "SubaccountNotAuthorized")
      .withArgs(user0.address, subaccount.address);

    await subaccountRouter.connect(user0).addSubaccount(subaccount.address);

    await expect(subaccountRouter.connect(subaccount).createOrder(user0.address, params))
      .to.be.revertedWithCustomError(errorsContract, "MaxSubaccountActionCountExceeded")
      .withArgs(user0.address, subaccount.address, 1, 0);

    await subaccountRouter
      .connect(user0)
      .setMaxAllowedSubaccountActionCount(subaccount.address, keys.SUBACCOUNT_ORDER_ACTION, 1);

    await expect(subaccountRouter.connect(subaccount).createOrder(user0.address, params))
      .to.be.revertedWithCustomError(errorsContract, "InvalidReceiverForSubaccountOrder")
      .withArgs(subaccount.address, user0.address);

    await expect(
      subaccountRouter.connect(subaccount).createOrder(user0.address, {
        ...params,
        addresses: { ...params.addresses, receiver: user0.address },
      })
    ).to.be.revertedWithCustomError(errorsContract, "OrderTypeCannotBeCreated");

    await expect(
      subaccountRouter.connect(subaccount).createOrder(user0.address, {
        ...params,
        addresses: { ...params.addresses, receiver: user0.address },
        orderType: OrderType.MarketIncrease,
      })
    ).to.be.revertedWith("ERC20: insufficient allowance");

    await usdc.connect(user0).approve(router.address, expandDecimals(200, 6));

    await expect(
      subaccountRouter.connect(subaccount).createOrder(user0.address, {
        ...params,
        addresses: { ...params.addresses, receiver: user0.address },
        orderType: OrderType.MarketIncrease,
      })
    ).to.be.revertedWith("ERC20: transfer amount exceeds balance");

    await usdc.mint(user0.address, expandDecimals(101, 6));

    await expect(
      subaccountRouter.connect(subaccount).createOrder(user0.address, {
        ...params,
        addresses: { ...params.addresses, receiver: user0.address },
        orderType: OrderType.MarketIncrease,
      })
    ).to.be.revertedWithCustomError(errorsContract, "InsufficientWntAmountForExecutionFee");

    expect(
      await dataStore.getUint(
        keys.subaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(0);

    const initialWntBalance0 = await wnt.balanceOf(user0.address);

    await subaccountRouter.connect(subaccount).multicall(
      [
        subaccountRouter.interface.encodeFunctionData("sendWnt", [orderVault.address, expandDecimals(1, 17)]),
        subaccountRouter.interface.encodeFunctionData("createOrder", [
          user0.address,
          {
            ...params,
            addresses: { ...params.addresses, receiver: user0.address },
            orderType: OrderType.MarketIncrease,
          },
        ]),
      ],
      { value: expandDecimals(1, 17) }
    );

    expect(initialWntBalance0.sub(await wnt.balanceOf(user0.address))).closeTo(
      "101679245508955976",
      "1000000000000000"
    ); // 0.101679245508955976 ETH

    const orderKeys = await getOrderKeys(dataStore, 0, 1);
    const order = await reader.getOrder(dataStore.address, orderKeys[0]);
    expect(order.addresses.account).eq(user0.address);
    expect(order.addresses.receiver).eq(user0.address);
    expect(order.numbers.initialCollateralDeltaAmount).eq(expandDecimals(100, 6));
    expect(order._dataList).deep.eq(dataList);

    expect(
      await dataStore.getUint(
        keys.subaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(1);

    await executeOrder(fixture, { orderKey: orderKeys[0] });

    const positionKeys = await getPositionKeys(dataStore, 0, 10);

    const position0 = await reader.getPositionInfo(
      dataStore.address,
      referralStorage.address,
      positionKeys[0],
      prices.ethUsdMarket,
      0, // sizeDeltaUsd
      ethers.constants.AddressZero,
      true // usePositionSizeAsSizeDeltaUsd
    );

    expect(position0.position.numbers.sizeInUsd).eq(decimalToFloat(1000));
  });

  it("MarketDecrease order", async () => {
    const subaccount = createAccount();

    await subaccountRouter
      .connect(user0)
      .multicall(
        [
          subaccountRouter.interface.encodeFunctionData("sendNativeToken", [subaccount.address, expandDecimals(1, 18)]),
          subaccountRouter.interface.encodeFunctionData("addSubaccount", [subaccount.address]),
          subaccountRouter.interface.encodeFunctionData("setMaxAllowedSubaccountActionCount", [
            subaccount.address,
            keys.SUBACCOUNT_ORDER_ACTION,
            20,
          ]),
          subaccountRouter.interface.encodeFunctionData("setSubaccountExpiresAt", [
            subaccount.address,
            keys.SUBACCOUNT_ORDER_ACTION,
            9999999999,
          ]),
          subaccountRouter.interface.encodeFunctionData("setSubaccountAutoTopUpAmount", [
            subaccount.address,
            expandDecimals(1, 17),
          ]),
        ],
        { value: expandDecimals(1, 18) }
      );

    await usdc.mint(user0.address, expandDecimals(101, 6));
    await usdc.connect(user0).approve(router.address, expandDecimals(200, 6));

    const referralCode = hashString("referralCode");
    const params = {
      addresses: {
        receiver: user0.address,
        cancellationReceiver: user0.address,
        callbackContract: user2.address,
        uiFeeReceiver: user1.address,
        market: ethUsdMarket.marketToken,
        initialCollateralToken: usdc.address,
        swapPath: [],
      },
      numbers: {
        sizeDeltaUsd: decimalToFloat(1000),
        initialCollateralDeltaAmount: expandDecimals(100, 6),
        triggerPrice: decimalToFloat(4800),
        acceptablePrice: expandDecimals(5010, 12),
        executionFee: expandDecimals(1, 17),
        callbackGasLimit: "200000",
        minOutputAmount: 700,
        validFromTime: 0,
      },
      orderType: OrderType.MarketIncrease,
      decreasePositionSwapType: DecreasePositionSwapType.SwapCollateralTokenToPnlToken,
      isLong: true,
      shouldUnwrapNativeToken: true,
      referralCode,
      dataList: [],
    };

    await subaccountRouter
      .connect(subaccount)
      .multicall(
        [
          subaccountRouter.interface.encodeFunctionData("sendWnt", [orderVault.address, expandDecimals(1, 17)]),
          subaccountRouter.interface.encodeFunctionData("createOrder", [user0.address, params]),
        ],
        { value: expandDecimals(1, 17) }
      );

    expect(
      await dataStore.getUint(
        keys.subaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(1);

    await executeOrder(fixture);

    const positionKeys = await getPositionKeys(dataStore, 0, 10);

    await usingResult(
      reader.getPositionInfo(
        dataStore.address,
        referralStorage.address,
        positionKeys[0],
        prices.ethUsdMarket,
        0, // sizeDeltaUsd
        ethers.constants.AddressZero,
        true // usePositionSizeAsSizeDeltaUsd
      ),
      (positionInfo) => {
        expect(positionInfo.position.numbers.sizeInUsd).eq(decimalToFloat(1000));
        expect(positionInfo.position.numbers.collateralAmount).eq(expandDecimals(100, 6));
      }
    );

    await subaccountRouter.connect(subaccount).multicall(
      [
        subaccountRouter.interface.encodeFunctionData("sendWnt", [orderVault.address, expandDecimals(1, 17)]),
        subaccountRouter.interface.encodeFunctionData("createOrder", [
          user0.address,
          {
            ...params,
            numbers: {
              ...params.numbers,
              sizeDeltaUsd: decimalToFloat(500),
              initialCollateralDeltaAmount: expandDecimals(50, 6),
              acceptablePrice: expandDecimals(4990, 12),
            },
            orderType: OrderType.MarketDecrease,
          },
        ]),
      ],
      { value: expandDecimals(1, 17) }
    );

    expect(
      await dataStore.getUint(
        keys.subaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(2);

    await executeOrder(fixture);

    await usingResult(
      reader.getPositionInfo(
        dataStore.address,
        referralStorage.address,
        positionKeys[0],
        prices.ethUsdMarket,
        0, // sizeDeltaUsd
        ethers.constants.AddressZero,
        true // usePositionSizeAsSizeDeltaUsd
      ),
      (positionInfo) => {
        expect(positionInfo.position.numbers.sizeInUsd).eq(decimalToFloat(500));
        expect(positionInfo.position.numbers.collateralAmount).eq(expandDecimals(50, 6));
      }
    );
  });

  it("update order", async () => {
    const subaccount = createAccount();

    await subaccountRouter
      .connect(user0)
      .multicall(
        [
          subaccountRouter.interface.encodeFunctionData("sendNativeToken", [subaccount.address, expandDecimals(1, 18)]),
          subaccountRouter.interface.encodeFunctionData("addSubaccount", [subaccount.address]),
          subaccountRouter.interface.encodeFunctionData("setMaxAllowedSubaccountActionCount", [
            subaccount.address,
            keys.SUBACCOUNT_ORDER_ACTION,
            20,
          ]),
          subaccountRouter.interface.encodeFunctionData("setSubaccountExpiresAt", [
            subaccount.address,
            keys.SUBACCOUNT_ORDER_ACTION,
            9999999999,
          ]),
          subaccountRouter.interface.encodeFunctionData("setSubaccountAutoTopUpAmount", [
            subaccount.address,
            expandDecimals(1, 17),
          ]),
        ],
        { value: expandDecimals(1, 18) }
      );

    await usdc.mint(user0.address, expandDecimals(101, 6));
    await usdc.connect(user0).approve(router.address, expandDecimals(200, 6));

    const referralCode = hashString("referralCode");
    await dataStore.setUint(keys.MAX_DATA_LENGTH, 256);
    const dataList = [ethers.utils.formatBytes32String("customData")];
    const params = {
      addresses: {
        receiver: user0.address,
        cancellationReceiver: user0.address,
        callbackContract: user2.address,
        uiFeeReceiver: user1.address,
        market: ethUsdMarket.marketToken,
        initialCollateralToken: usdc.address,
        swapPath: [],
      },
      numbers: {
        sizeDeltaUsd: decimalToFloat(1000),
        initialCollateralDeltaAmount: expandDecimals(100, 6),
        triggerPrice: expandDecimals(4800, 12),
        acceptablePrice: expandDecimals(5010, 12),
        executionFee: expandDecimals(1, 17),
        callbackGasLimit: "200000",
        minOutputAmount: 700,
        validFromTime: 800,
      },
      orderType: OrderType.LimitIncrease,
      decreasePositionSwapType: DecreasePositionSwapType.SwapCollateralTokenToPnlToken,
      isLong: true,
      shouldUnwrapNativeToken: true,
      referralCode,
      dataList,
    };

    await subaccountRouter
      .connect(subaccount)
      .multicall(
        [
          subaccountRouter.interface.encodeFunctionData("sendWnt", [orderVault.address, expandDecimals(1, 17)]),
          subaccountRouter.interface.encodeFunctionData("createOrder", [user0.address, params]),
        ],
        { value: expandDecimals(1, 17) }
      );

    expect(
      await dataStore.getUint(
        keys.subaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(1);

    let orderKeys = await getOrderKeys(dataStore, 0, 1);
    const orderKey = orderKeys[0];
    await usingResult(reader.getOrder(dataStore.address, orderKey), (order) => {
      expect(order.addresses.account).eq(user0.address);
      expect(order.addresses.receiver).eq(user0.address);
      expect(order.numbers.initialCollateralDeltaAmount).eq(expandDecimals(100, 6));
      expect(order.numbers.sizeDeltaUsd).eq(decimalToFloat(1000));
      expect(order.numbers.acceptablePrice).eq(expandDecimals(5010, 12));
      expect(order.numbers.triggerPrice).eq(expandDecimals(4800, 12));
      expect(order.numbers.minOutputAmount).eq(700);
      expect(order.numbers.validFromTime).eq(800);
      expect(order._dataList).deep.eq(dataList);
    });

    const initialWntBalance0 = await wnt.balanceOf(user0.address);

    await subaccountRouter.connect(subaccount).updateOrder(
      orderKey, // key
      decimalToFloat(1200), // sizeDeltaUsd
      expandDecimals(5020, 12), // acceptablePrice
      expandDecimals(4850, 12), // triggerPrice
      800, // minOutputAmount
      0, // validFromTime
      false // autoCancel
    );

    expect(initialWntBalance0.sub(await wnt.balanceOf(user0.address))).closeTo("588774003140128", "100000000000000"); // 0.000588774003140128 ETH

    expect(
      await dataStore.getUint(
        keys.subaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(2);

    await usingResult(reader.getOrder(dataStore.address, orderKey), (order) => {
      expect(order.addresses.account).eq(user0.address);
      expect(order.addresses.receiver).eq(user0.address);
      expect(order.numbers.initialCollateralDeltaAmount).eq(expandDecimals(100, 6));
      expect(order.numbers.sizeDeltaUsd).eq(decimalToFloat(1200));
      expect(order.numbers.acceptablePrice).eq(expandDecimals(5020, 12));
      expect(order.numbers.triggerPrice).eq(expandDecimals(4850, 12));
      expect(order.numbers.minOutputAmount).eq(800);
    });

    await createOrder(fixture, {
      account: user1,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      orderType: OrderType.MarketIncrease,
      sizeDeltaUsd: decimalToFloat(10),
      receiver: user1,
    });

    orderKeys = await getOrderKeys(dataStore, 0, 2);

    await expect(
      subaccountRouter.connect(subaccount).updateOrder(
        orderKeys[1], // key
        decimalToFloat(1200), // sizeDeltaUsd
        expandDecimals(5020, 12), // acceptablePrice
        expandDecimals(4850, 12), // triggerPrice
        800, // minOutputAmount
        0, // validFromTime
        false // autoCancel
      )
    ).to.be.revertedWithCustomError(errorsContract, "SubaccountNotAuthorized");
  });

  it("cancel order", async () => {
    const subaccount = createAccount();

    await subaccountRouter
      .connect(user0)
      .multicall(
        [
          subaccountRouter.interface.encodeFunctionData("sendNativeToken", [subaccount.address, expandDecimals(1, 18)]),
          subaccountRouter.interface.encodeFunctionData("addSubaccount", [subaccount.address]),
          subaccountRouter.interface.encodeFunctionData("setMaxAllowedSubaccountActionCount", [
            subaccount.address,
            keys.SUBACCOUNT_ORDER_ACTION,
            20,
          ]),
          subaccountRouter.interface.encodeFunctionData("setSubaccountExpiresAt", [
            subaccount.address,
            keys.SUBACCOUNT_ORDER_ACTION,
            9999999999,
          ]),
          subaccountRouter.interface.encodeFunctionData("setSubaccountAutoTopUpAmount", [
            subaccount.address,
            expandDecimals(1, 17),
          ]),
        ],
        { value: expandDecimals(1, 18) }
      );

    await usdc.mint(user0.address, expandDecimals(101, 6));
    await usdc.connect(user0).approve(router.address, expandDecimals(200, 6));

    const referralCode = hashString("referralCode");
    await dataStore.setUint(keys.MAX_DATA_LENGTH, 256);
    const dataList = [ethers.utils.formatBytes32String("customData")];
    const params = {
      addresses: {
        receiver: user0.address,
        cancellationReceiver: user0.address,
        callbackContract: user2.address,
        uiFeeReceiver: user1.address,
        market: ethUsdMarket.marketToken,
        initialCollateralToken: usdc.address,
        swapPath: [],
      },
      numbers: {
        sizeDeltaUsd: decimalToFloat(1000),
        initialCollateralDeltaAmount: expandDecimals(100, 6),
        triggerPrice: expandDecimals(4800, 12),
        acceptablePrice: expandDecimals(5010, 12),
        executionFee: expandDecimals(1, 17),
        callbackGasLimit: "200000",
        minOutputAmount: 700,
        validFromTime: 800,
      },
      orderType: OrderType.LimitIncrease,
      decreasePositionSwapType: DecreasePositionSwapType.SwapCollateralTokenToPnlToken,
      isLong: true,
      shouldUnwrapNativeToken: true,
      referralCode,
      dataList,
    };

    await subaccountRouter
      .connect(subaccount)
      .multicall(
        [
          subaccountRouter.interface.encodeFunctionData("sendWnt", [orderVault.address, expandDecimals(1, 17)]),
          subaccountRouter.interface.encodeFunctionData("createOrder", [user0.address, params]),
        ],
        { value: expandDecimals(1, 17) }
      );

    expect(
      await dataStore.getUint(
        keys.subaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(1);

    let orderKeys = await getOrderKeys(dataStore, 0, 1);
    const orderKey = orderKeys[0];
    await usingResult(reader.getOrder(dataStore.address, orderKey), (order) => {
      expect(order.addresses.account).eq(user0.address);
      expect(order.addresses.receiver).eq(user0.address);
      expect(order.numbers.initialCollateralDeltaAmount).eq(expandDecimals(100, 6));
      expect(order.numbers.sizeDeltaUsd).eq(decimalToFloat(1000));
      expect(order.numbers.acceptablePrice).eq(expandDecimals(5010, 12));
      expect(order.numbers.triggerPrice).eq(expandDecimals(4800, 12));
      expect(order.numbers.minOutputAmount).eq(700);
      expect(order.numbers.validFromTime).eq(800);
      expect(order._dataList).deep.eq(dataList);
    });

    expect(await usdc.balanceOf(user0.address)).eq(expandDecimals(1, 6));

    const initialWntBalance0 = await wnt.balanceOf(user0.address);

    await subaccountRouter.connect(subaccount).cancelOrder(orderKey);

    expect(initialWntBalance0.sub(await wnt.balanceOf(user0.address))).closeTo("1156293006166896", "10000000000000"); // 0.001156293006166896 ETH

    expect(await usdc.balanceOf(user0.address)).eq(expandDecimals(101, 6));

    expect(
      await dataStore.getUint(
        keys.subaccountActionCountKey(user0.address, subaccount.address, keys.SUBACCOUNT_ORDER_ACTION)
      )
    ).eq(2);

    await usingResult(reader.getOrder(dataStore.address, orderKey), (order) => {
      expect(order.addresses.account).eq(ethers.constants.AddressZero);
    });

    await createOrder(fixture, {
      account: user1,
      market: ethUsdMarket,
      initialCollateralToken: usdc,
      orderType: OrderType.MarketIncrease,
      sizeDeltaUsd: decimalToFloat(10),
      receiver: user1,
    });

    orderKeys = await getOrderKeys(dataStore, 0, 2);

    await expect(subaccountRouter.connect(subaccount).cancelOrder(orderKeys[0])).to.be.revertedWithCustomError(
      errorsContract,
      "SubaccountNotAuthorized"
    );
  });
});
