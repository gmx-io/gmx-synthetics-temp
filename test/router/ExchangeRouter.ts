import { expect } from "chai";

import { contractAt } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { logGasUsage } from "../../utils/gas";
import { getDepositKeys } from "../../utils/deposit";
import { getWithdrawalKeys } from "../../utils/withdrawal";
import { handleDeposit } from "../../utils/deposit";
import { hashString } from "../../utils/hash";
import { getNextKey } from "../../utils/nonce";
import { errorsContract } from "../../utils/error";
import { OrderType, DecreasePositionSwapType, getOrderKeys } from "../../utils/order";
import * as keys from "../../utils/keys";

describe("ExchangeRouter", () => {
  let fixture;
  let user0, user1, user2, user3;
  let reader,
    dataStore,
    depositVault,
    orderVault,
    withdrawalVault,
    router,
    exchangeRouter,
    ethUsdMarket,
    ethUsdSpotOnlyMarket,
    wnt,
    usdc;
  const executionFee = expandDecimals(1, 18);

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0, user1, user2, user3 } = fixture.accounts);
    ({
      reader,
      dataStore,
      depositVault,
      orderVault,
      withdrawalVault,
      router,
      exchangeRouter,
      ethUsdMarket,
      ethUsdSpotOnlyMarket,
      wnt,
      usdc,
    } = fixture.contracts);
  });

  it("createDeposit", async () => {
    await dataStore.setUint(keys.MAX_DATA_LENGTH, 256);
    const dataList = [ethers.utils.formatBytes32String("customData")];
    await usdc.mint(user0.address, expandDecimals(50 * 1000, 6));
    await usdc.connect(user0).approve(router.address, expandDecimals(50 * 1000, 6));
    const tx = await exchangeRouter.connect(user0).multicall(
      [
        exchangeRouter.interface.encodeFunctionData("sendWnt", [depositVault.address, expandDecimals(11, 18)]),
        exchangeRouter.interface.encodeFunctionData("sendTokens", [
          usdc.address,
          depositVault.address,
          expandDecimals(50 * 1000, 6),
        ]),
        exchangeRouter.interface.encodeFunctionData("createDeposit", [
          {
            receiver: user1.address,
            callbackContract: user2.address,
            uiFeeReceiver: user3.address,
            market: ethUsdMarket.marketToken,
            initialLongToken: ethUsdMarket.longToken,
            initialShortToken: ethUsdMarket.shortToken,
            longTokenSwapPath: [ethUsdMarket.marketToken, ethUsdSpotOnlyMarket.marketToken],
            shortTokenSwapPath: [ethUsdSpotOnlyMarket.marketToken, ethUsdMarket.marketToken],
            minMarketTokens: 100,
            shouldUnwrapNativeToken: true,
            executionFee,
            callbackGasLimit: "200000",
            chainId: 0,
            dataList,
          },
        ]),
      ],
      { value: expandDecimals(11, 18) }
    );

    const depositKeys = await getDepositKeys(dataStore, 0, 1);
    const deposit = await reader.getDeposit(dataStore.address, depositKeys[0]);

    expect(deposit.addresses.account).eq(user0.address);
    expect(deposit.addresses.receiver).eq(user1.address);
    expect(deposit.addresses.callbackContract).eq(user2.address);
    expect(deposit.addresses.market).eq(ethUsdMarket.marketToken);
    expect(deposit.addresses.initialLongToken).eq(ethUsdMarket.longToken);
    expect(deposit.addresses.initialShortToken).eq(ethUsdMarket.shortToken);
    expect(deposit.addresses.longTokenSwapPath).deep.eq([ethUsdMarket.marketToken, ethUsdSpotOnlyMarket.marketToken]);
    expect(deposit.addresses.shortTokenSwapPath).deep.eq([ethUsdSpotOnlyMarket.marketToken, ethUsdMarket.marketToken]);
    expect(deposit.numbers.initialLongTokenAmount).eq(expandDecimals(10, 18));
    expect(deposit.numbers.initialShortTokenAmount).eq(expandDecimals(10 * 5000, 6));
    expect(deposit.numbers.minMarketTokens).eq(100);
    expect(deposit.numbers.executionFee).eq(expandDecimals(1, 18));
    expect(deposit.numbers.callbackGasLimit).eq("200000");
    expect(deposit.numbers.chainId).eq(0);
    expect(deposit.flags.shouldUnwrapNativeToken).eq(true);
    expect(deposit._dataList).deep.eq(dataList);

    await logGasUsage({
      tx,
      label: "exchangeRouter.createDeposit",
    });
  });

  it("createOrder", async () => {
    const referralCode = hashString("referralCode");
    await dataStore.setUint(keys.MAX_DATA_LENGTH, 256);
    const dataList = [ethers.utils.formatBytes32String("customData")];
    await usdc.mint(user0.address, expandDecimals(50 * 1000, 6));
    await usdc.connect(user0).approve(router.address, expandDecimals(50 * 1000, 6));
    const tx = await exchangeRouter.connect(user0).multicall(
      [
        exchangeRouter.interface.encodeFunctionData("sendWnt", [orderVault.address, expandDecimals(11, 18)]),
        exchangeRouter.interface.encodeFunctionData("createOrder", [
          {
            addresses: {
              receiver: user1.address,
              cancellationReceiver: user1.address,
              callbackContract: user2.address,
              uiFeeReceiver: user3.address,
              market: ethUsdMarket.marketToken,
              initialCollateralToken: ethUsdMarket.longToken,
              swapPath: [ethUsdMarket.marketToken],
            },
            numbers: {
              sizeDeltaUsd: decimalToFloat(1000),
              initialCollateralDeltaAmount: 0,
              triggerPrice: decimalToFloat(4800),
              acceptablePrice: decimalToFloat(4900),
              executionFee,
              callbackGasLimit: "200000",
              minOutputAmount: 700,
              validFromTime: 0,
            },
            orderType: OrderType.LimitIncrease,
            decreasePositionSwapType: DecreasePositionSwapType.SwapCollateralTokenToPnlToken,
            isLong: true,
            shouldUnwrapNativeToken: true,
            referralCode,
            dataList,
          },
        ]),
      ],
      { value: expandDecimals(11, 18) }
    );

    const orderKeys = await getOrderKeys(dataStore, 0, 1);
    const order = await reader.getOrder(dataStore.address, orderKeys[0]);

    expect(order.addresses.account).eq(user0.address);
    expect(order.addresses.receiver).eq(user1.address);
    expect(order.addresses.callbackContract).eq(user2.address);
    expect(order.addresses.market).eq(ethUsdMarket.marketToken);
    expect(order.addresses.initialCollateralToken).eq(ethUsdMarket.longToken);
    expect(order.addresses.swapPath).deep.eq([ethUsdMarket.marketToken]);
    expect(order.numbers.orderType).eq(OrderType.LimitIncrease);
    expect(order.numbers.decreasePositionSwapType).eq(DecreasePositionSwapType.SwapCollateralTokenToPnlToken);
    expect(order.numbers.sizeDeltaUsd).eq(decimalToFloat(1000));
    expect(order.numbers.initialCollateralDeltaAmount).eq("10000000000000000000");
    expect(order.numbers.triggerPrice).eq(decimalToFloat(4800));
    expect(order.numbers.acceptablePrice).eq(decimalToFloat(4900));
    expect(order.numbers.executionFee).eq(expandDecimals(1, 18));
    expect(order.numbers.callbackGasLimit).eq("200000");
    expect(order.numbers.minOutputAmount).eq(700);

    expect(order.flags.isLong).eq(true);
    expect(order.flags.shouldUnwrapNativeToken).eq(true);
    expect(order.flags.isFrozen).eq(false);

    expect(order._dataList).deep.eq(dataList);

    await logGasUsage({
      tx,
      label: "exchangeRouter.createOrder",
    });
  });

  it("createWithdrawal", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10, 18),
      },
    });

    await dataStore.setUint(keys.MAX_DATA_LENGTH, 256);
    const dataList = [ethers.utils.formatBytes32String("customData")];
    const marketToken = await contractAt("MarketToken", ethUsdMarket.marketToken);
    await marketToken.connect(user0).approve(router.address, expandDecimals(50 * 1000, 18));

    const tx = await exchangeRouter.connect(user0).multicall(
      [
        exchangeRouter.interface.encodeFunctionData("sendWnt", [withdrawalVault.address, expandDecimals(1, 18)]),
        exchangeRouter.interface.encodeFunctionData("sendTokens", [
          ethUsdMarket.marketToken,
          withdrawalVault.address,
          700,
        ]),
        exchangeRouter.interface.encodeFunctionData("createWithdrawal", [
          {
            receiver: user1.address,
            callbackContract: user2.address,
            uiFeeReceiver: user3.address,
            market: ethUsdMarket.marketToken,
            longTokenSwapPath: [],
            shortTokenSwapPath: [],
            marketTokenAmount: 700,
            minLongTokenAmount: 800,
            minShortTokenAmount: 900,
            shouldUnwrapNativeToken: true,
            executionFee,
            callbackGasLimit: "200000",
            dataList,
          },
        ]),
      ],
      { value: expandDecimals(1, 18) }
    );

    const withdrawalKeys = await getWithdrawalKeys(dataStore, 0, 1);
    const withdrawal = await reader.getWithdrawal(dataStore.address, withdrawalKeys[0]);

    expect(withdrawal.addresses.account).eq(user0.address);
    expect(withdrawal.addresses.receiver).eq(user1.address);
    expect(withdrawal.addresses.callbackContract).eq(user2.address);
    expect(withdrawal.addresses.market).eq(ethUsdMarket.marketToken);
    expect(withdrawal.addresses.longTokenSwapPath).deep.eq([]);
    expect(withdrawal.addresses.shortTokenSwapPath).deep.eq([]);

    expect(withdrawal.numbers.marketTokenAmount).eq(700);
    expect(withdrawal.numbers.minLongTokenAmount).eq(800);
    expect(withdrawal.numbers.minShortTokenAmount).eq(900);
    expect(withdrawal.numbers.executionFee).eq(expandDecimals(1, 18));
    expect(withdrawal.numbers.callbackGasLimit).eq("200000");
    expect(withdrawal.flags.shouldUnwrapNativeToken).eq(true);

    expect(withdrawal._dataList).deep.eq(dataList);

    await logGasUsage({
      tx,
      label: "exchangeRouter.createWithdrawal",
    });
  });

  it("simulateExecuteDeposit", async () => {
    await usdc.mint(user0.address, expandDecimals(50 * 1000, 6));
    await usdc.connect(user0).approve(router.address, expandDecimals(50 * 1000, 6));

    const depositKey = await getNextKey(dataStore);

    const currentTimestamp = (await ethers.provider.getBlock()).timestamp + 2;

    await expect(
      exchangeRouter.connect(user0).multicall(
        [
          exchangeRouter.interface.encodeFunctionData("sendWnt", [depositVault.address, expandDecimals(11, 18)]),
          exchangeRouter.interface.encodeFunctionData("sendTokens", [
            usdc.address,
            depositVault.address,
            expandDecimals(50 * 1000, 6),
          ]),
          exchangeRouter.interface.encodeFunctionData("createDeposit", [
            {
              receiver: user1.address,
              callbackContract: user2.address,
              uiFeeReceiver: user3.address,
              market: ethUsdMarket.marketToken,
              initialLongToken: ethUsdMarket.longToken,
              initialShortToken: ethUsdMarket.shortToken,
              longTokenSwapPath: [],
              shortTokenSwapPath: [],
              minMarketTokens: 100,
              shouldUnwrapNativeToken: true,
              executionFee,
              callbackGasLimit: "200000",
              chainId: 0,
              dataList: [],
            },
          ]),
          exchangeRouter.interface.encodeFunctionData("simulateExecuteDeposit", [
            depositKey,
            {
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
            },
          ]),
        ],
        { value: expandDecimals(11, 18) }
      )
    ).to.be.revertedWithCustomError(errorsContract, "EndOfOracleSimulation");
  });
});
