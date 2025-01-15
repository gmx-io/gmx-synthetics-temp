import { deployFixture } from "../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { OrderType, getOrderCount, createOrder, executeOrder } from "../../utils/order";
import { handleDeposit } from "../../utils/deposit";
import { getPositionCount } from "../../utils/position";
import { expect } from "chai";
import { getSyntheticTokenAddress } from "../../utils/token";
import { encodeDataStreamData, TOKEN_ORACLE_TYPES } from "../../utils/oracle";
import hre from "hardhat";
import * as keys from "../../utils/keys";
import { hashString } from "../../utils/hash";

describe("Guardian.DataStreamFeeds", () => {
  const { provider } = ethers;

  let fixture;
  let user1;
  let dataStore, solUsdMarket, solAddr, ethUsdMarket, wnt, usdc;

  const getBaseDataStreamData = (block) => {
    const buffer = 2;
    const timestamp = block.timestamp + buffer;
    return {
      feedId: hashString("feedId"),
      validFromTimestamp: timestamp,
      observationsTimestamp: timestamp,
      nativeFee: 0,
      linkFee: 0,
      expiresAt: timestamp,
      price: expandDecimals(5000, 8),
      bid: expandDecimals(5000, 8),
      ask: expandDecimals(5000, 8),
    };
  };

  beforeEach(async () => {
    fixture = await deployFixture();

    ({ user1 } = fixture.accounts);
    ({ dataStore, solUsdMarket, ethUsdMarket, wnt, usdc } = fixture.contracts);

    solAddr = getSyntheticTokenAddress(hre.network.config.chainId, "SOL");

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10000000, 18),
        shortTokenAmount: expandDecimals(10000000 * 5000, 6),
      },
    });

    await handleDeposit(fixture, {
      create: {
        market: solUsdMarket,
        longTokenAmount: expandDecimals(10000000, 18), // ETH
        shortTokenAmount: expandDecimals(10000000 * 5000, 6), // USDC
      },
      execute: {
        tokens: [wnt.address, usdc.address, solAddr],
        tokenOracleTypes: [TOKEN_ORACLE_TYPES.DEFAULT, TOKEN_ORACLE_TYPES.DEFAULT, TOKEN_ORACLE_TYPES.DEFAULT],
        precisions: [8, 18, 18],
        minPrices: [expandDecimals(2500, 4), expandDecimals(1, 6), expandDecimals(15, 6)],
        maxPrices: [expandDecimals(2500, 4), expandDecimals(1, 6), expandDecimals(15, 6)],
      },
    });
  });

  it("Order executes with data stream feed tokens only", async () => {
    const initialUSDCBalance = expandDecimals(50 * 1000, 6); // 50,000 USDC
    expect(await getOrderCount(dataStore)).eq(0);
    await dataStore.setBytes32(keys.dataStreamIdKey(wnt.address), hashString("WNT"));
    await dataStore.setUint(keys.dataStreamMultiplierKey(wnt.address), expandDecimals(1, 34));
    await dataStore.setBytes32(keys.dataStreamIdKey(usdc.address), hashString("USDC"));
    await dataStore.setUint(keys.dataStreamMultiplierKey(usdc.address), expandDecimals(1, 46));

    const increaseParams = {
      account: user1,
      market: ethUsdMarket,
      minOutputAmount: 0,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: initialUSDCBalance,
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(200 * 1000), // 4x leverage -- position size is 40 ETH @ $5,000/ETH
      acceptablePrice: expandDecimals(5001, 12),
      orderType: OrderType.MarketIncrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
    };

    await createOrder(fixture, increaseParams);

    let block = await provider.getBlock();
    let baseDataStreamData = getBaseDataStreamData(block);

    await executeOrder(fixture, {
      tokens: [],
      dataStreamTokens: [wnt.address, usdc.address],
      dataStreamData: [
        encodeDataStreamData({
          ...baseDataStreamData,
          feedId: hashString("WNT"),
          bid: expandDecimals(5000, 8),
          ask: expandDecimals(5002, 8),
        }),
        encodeDataStreamData({
          ...baseDataStreamData,
          feedId: hashString("USDC"),
          bid: expandDecimals(1, 8),
          ask: expandDecimals(1, 8),
        }),
      ],
      expectedCancellationReason: "OrderNotFulfillableAtAcceptablePrice",
    });

    expect(await getOrderCount(dataStore)).to.eq(0);
    expect(await getPositionCount(dataStore)).to.eq(0);

    await createOrder(fixture, increaseParams);
    block = await provider.getBlock();

    expect(await getOrderCount(dataStore)).to.eq(1);
    expect(await getPositionCount(dataStore)).to.eq(0);

    baseDataStreamData = getBaseDataStreamData(block);

    await executeOrder(fixture, {
      tokens: [],
      dataStreamTokens: [wnt.address, usdc.address],
      dataStreamData: [
        encodeDataStreamData({
          ...baseDataStreamData,
          feedId: hashString("WNT"),
          bid: expandDecimals(5000, 8),
          ask: expandDecimals(5000, 8),
        }),
        encodeDataStreamData({
          ...baseDataStreamData,
          feedId: hashString("USDC"),
          bid: expandDecimals(1, 8),
          ask: expandDecimals(1, 8),
        }),
      ],
    });

    expect(await getOrderCount(dataStore)).to.eq(0);
    expect(await getPositionCount(dataStore)).to.eq(1);
  });

  it("Order executes with regular and data stream feed tokens", async () => {
    const initialUSDCBalance = expandDecimals(50 * 1000, 6); // 50,000 USDC
    expect(await getOrderCount(dataStore)).eq(0);
    await dataStore.setBytes32(keys.dataStreamIdKey(wnt.address), hashString("WNT"));
    await dataStore.setUint(keys.dataStreamMultiplierKey(wnt.address), expandDecimals(1, 34));
    const increaseParams = {
      account: user1,
      market: ethUsdMarket,
      minOutputAmount: 0,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: initialUSDCBalance,
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(200 * 1000), // 4x leverage -- position size is 40 ETH @ $5,000/ETH
      acceptablePrice: expandDecimals(5001, 12),
      orderType: OrderType.MarketIncrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
    };

    await createOrder(fixture, increaseParams);

    let block = await provider.getBlock();
    let baseDataStreamData = getBaseDataStreamData(block);

    await executeOrder(fixture, {
      tokens: [usdc.address],
      dataStreamTokens: [wnt.address],
      dataStreamData: [
        encodeDataStreamData({
          ...baseDataStreamData,
          feedId: hashString("WNT"),
          bid: expandDecimals(5000, 8),
          ask: expandDecimals(5002, 8),
        }),
      ],
      minPrices: [expandDecimals(1, 6)],
      maxPrices: [expandDecimals(1, 6)],
      precisions: [18],
      expectedCancellationReason: "OrderNotFulfillableAtAcceptablePrice",
    });

    expect(await getOrderCount(dataStore)).to.eq(0);
    expect(await getPositionCount(dataStore)).to.eq(0);

    await createOrder(fixture, increaseParams);
    block = await provider.getBlock();

    expect(await getOrderCount(dataStore)).to.eq(1);
    expect(await getPositionCount(dataStore)).to.eq(0);

    baseDataStreamData = getBaseDataStreamData(block);

    await executeOrder(fixture, {
      tokens: [usdc.address],
      dataStreamTokens: [wnt.address],
      dataStreamData: [
        encodeDataStreamData({
          ...baseDataStreamData,
          feedId: hashString("WNT"),
          bid: expandDecimals(5000, 8),
          ask: expandDecimals(5000, 8),
        }),
      ],
      minPrices: [expandDecimals(1, 6)],
      maxPrices: [expandDecimals(1, 6)],
      precisions: [18],
    });

    expect(await getOrderCount(dataStore)).to.eq(0);
    expect(await getPositionCount(dataStore)).to.eq(1);
  });

  it("Order executes with regular CL feeds and data stream feed tokens", async () => {
    const initialUSDCBalance = expandDecimals(50 * 1000, 6); // 50,000 USDC
    expect(await getOrderCount(dataStore)).eq(0);
    await dataStore.setBytes32(keys.dataStreamIdKey(wnt.address), hashString("WNT"));
    await dataStore.setUint(keys.dataStreamMultiplierKey(wnt.address), expandDecimals(1, 34));

    const increaseParams = {
      account: user1,
      market: ethUsdMarket,
      minOutputAmount: 0,
      initialCollateralToken: usdc,
      initialCollateralDeltaAmount: initialUSDCBalance,
      swapPath: [],
      sizeDeltaUsd: decimalToFloat(200 * 1000), // 4x leverage -- position size is 40 ETH @ $5,000/ETH
      acceptablePrice: expandDecimals(5001, 12),
      orderType: OrderType.MarketIncrease,
      isLong: true,
      shouldUnwrapNativeToken: false,
    };

    await createOrder(fixture, increaseParams);
    let block = await provider.getBlock();

    let baseDataStreamData = getBaseDataStreamData(block);

    await executeOrder(fixture, {
      tokens: [],
      priceFeedTokens: [usdc.address],
      dataStreamTokens: [wnt.address],
      dataStreamData: [
        encodeDataStreamData({
          ...baseDataStreamData,
          feedId: hashString("WNT"),
          bid: expandDecimals(5000, 8),
          ask: expandDecimals(5002, 8),
        }),
      ],
      expectedCancellationReason: "OrderNotFulfillableAtAcceptablePrice",
    });

    expect(await getOrderCount(dataStore)).to.eq(0);
    expect(await getPositionCount(dataStore)).to.eq(0);

    await createOrder(fixture, increaseParams);
    block = await provider.getBlock();

    expect(await getOrderCount(dataStore)).to.eq(1);
    expect(await getPositionCount(dataStore)).to.eq(0);

    baseDataStreamData = getBaseDataStreamData(block);

    await executeOrder(fixture, {
      priceFeedTokens: [usdc.address],
      tokens: [],
      dataStreamTokens: [wnt.address],
      dataStreamData: [
        encodeDataStreamData({
          ...baseDataStreamData,
          feedId: hashString("WNT"),
          bid: expandDecimals(5000, 8),
          ask: expandDecimals(5000, 8),
        }),
      ],
    });

    expect(await getOrderCount(dataStore)).to.eq(0);
    expect(await getPositionCount(dataStore)).to.eq(1);
  });
});
