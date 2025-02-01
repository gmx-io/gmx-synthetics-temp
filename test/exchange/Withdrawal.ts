import { expect } from "chai";

import { usingResult } from "../../utils/use";
import { deployFixture } from "../../utils/fixture";
import { expandDecimals, decimalToFloat } from "../../utils/math";
import { getBalanceOf, getSupplyOf } from "../../utils/token";
import { errorsContract } from "../../utils/error";
import { getClaimableFeeAmount } from "../../utils/fee";
import {
  getPoolAmount,
  getSwapImpactPoolAmount,
  getMarketTokenPrice,
  getMarketTokenPriceWithPoolValue,
} from "../../utils/market";
import { handleDeposit } from "../../utils/deposit";
import {
  getWithdrawalCount,
  getWithdrawalKeys,
  createWithdrawal,
  executeWithdrawal,
  executeAtomicWithdrawal,
  handleWithdrawal,
} from "../../utils/withdrawal";
import { prices } from "../../utils/prices";
import { SwapPricingType } from "../../utils/swap";
import * as keys from "../../utils/keys";

describe("Exchange.Withdrawal", () => {
  const { AddressZero } = ethers.constants;

  let fixture;
  let user0, user1, user2;
  let reader,
    dataStore,
    withdrawalHandler,
    ethUsdMarket,
    ethUsdSingleTokenMarket,
    ethUsdSpotOnlyMarket,
    chainlinkPriceFeedProvider,
    wnt,
    usdc;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0, user1, user2 } = fixture.accounts);
    ({
      reader,
      dataStore,
      withdrawalHandler,
      ethUsdMarket,
      ethUsdSingleTokenMarket,
      ethUsdSpotOnlyMarket,
      chainlinkPriceFeedProvider,
      wnt,
      usdc,
    } = fixture.contracts);
  });

  it("createWithdrawal", async () => {
    expect(await getWithdrawalCount(dataStore)).eq(0);

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10, 18),
        shortTokenAmount: expandDecimals(10 * 5000, 6),
      },
    });

    await dataStore.setUint(keys.MAX_DATA_LENGTH, 256);
    const dataList = [ethers.utils.formatBytes32String("customData")];
    await createWithdrawal(fixture, {
      account: user0,
      receiver: user1,
      callbackContract: user2,
      market: ethUsdMarket,
      marketTokenAmount: expandDecimals(1000, 18),
      minLongTokenAmount: 100,
      minShortTokenAmount: 50,
      shouldUnwrapNativeToken: true,
      executionFee: 700,
      callbackGasLimit: 100000,
      gasUsageLabel: "createWithdrawal",
      dataList,
    });

    expect(await getWithdrawalCount(dataStore)).eq(1);

    const withdrawalKeys = await getWithdrawalKeys(dataStore, 0, 1);
    const withdrawal = await reader.getWithdrawal(dataStore.address, withdrawalKeys[0]);

    expect(withdrawal.addresses.account).eq(user0.address);
    expect(withdrawal.addresses.receiver).eq(user1.address);
    expect(withdrawal.addresses.callbackContract).eq(user2.address);
    expect(withdrawal.addresses.market).eq(ethUsdMarket.marketToken);
    expect(withdrawal.numbers.marketTokenAmount).eq(expandDecimals(1000, 18));
    expect(withdrawal.numbers.minLongTokenAmount).eq(100);
    expect(withdrawal.numbers.minShortTokenAmount).eq(50);
    expect(withdrawal.numbers.executionFee).eq(700);
    expect(withdrawal.numbers.callbackGasLimit).eq(100000);
    expect(withdrawal.flags.shouldUnwrapNativeToken).eq(true);
    expect(withdrawal._dataList).deep.eq(dataList);
  });

  it("executeWithdrawal", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10, 18),
        shortTokenAmount: expandDecimals(10 * 5000, 6),
      },
    });

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq(expandDecimals(100 * 1000, 18));
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdMarket.marketToken)).eq(expandDecimals(10, 18));
    expect(await usdc.balanceOf(ethUsdMarket.marketToken)).eq(expandDecimals(50 * 1000, 6));
    expect(await wnt.balanceOf(user0.address)).eq(0);
    expect(await usdc.balanceOf(user0.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(10, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(50 * 1000, 6));

    await createWithdrawal(fixture, {
      receiver: user0,
      market: ethUsdMarket,
      marketTokenAmount: expandDecimals(1000, 18),
      minLongTokenAmount: 100,
      minShortTokenAmount: 50,
      shouldUnwrapNativeToken: false,
      gasUsageLabel: "createWithdrawal",
    });

    const withdrawalKeys = await getWithdrawalKeys(dataStore, 0, 1);
    let withdrawal = await reader.getWithdrawal(dataStore.address, withdrawalKeys[0]);

    expect(withdrawal.addresses.account).eq(user0.address);
    expect(await getWithdrawalCount(dataStore)).eq(1);

    await executeWithdrawal(fixture, {
      gasUsageLabel: "executeWithdrawal",
    });

    withdrawal = await reader.getWithdrawal(dataStore.address, withdrawalKeys[0]);
    expect(withdrawal.addresses.account).eq(AddressZero);
    expect(await getWithdrawalCount(dataStore)).eq(0);

    expect(await getMarketTokenPrice(fixture)).eq(expandDecimals(1, 30));

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("99000000000000000000000"); // 99000
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdMarket.marketToken)).eq("9900000000000000000"); // 9.9 ETH
    expect(await usdc.balanceOf(ethUsdMarket.marketToken)).eq("49500000000"); // 49500 USDC
    expect(await wnt.balanceOf(user0.address)).eq("100000000000000000"); // 0.1 ETH, 500 USD
    expect(await usdc.balanceOf(user0.address)).eq("500000000"); // 500

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(
      "9900000000000000000" // 9.9 ETH
    );
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(
      "49500000000" // 49500 USDC
    );
  });

  it("executeWithdrawal, spot only market", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdSpotOnlyMarket,
        longTokenAmount: expandDecimals(10, 18),
      },
    });

    expect(await getBalanceOf(ethUsdSpotOnlyMarket.marketToken, user0.address)).eq("50000000000000000000000"); // 50,000
    expect(await getSupplyOf(ethUsdSpotOnlyMarket.marketToken)).eq("50000000000000000000000"); // 50,000
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdSpotOnlyMarket.marketToken)).eq(expandDecimals(10, 18));
    expect(await usdc.balanceOf(ethUsdSpotOnlyMarket.marketToken)).eq(0);
    expect(await wnt.balanceOf(user0.address)).eq(0);
    expect(await usdc.balanceOf(user0.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdSpotOnlyMarket.marketToken, wnt.address)).eq(expandDecimals(10, 18));
    expect(await getPoolAmount(dataStore, ethUsdSpotOnlyMarket.marketToken, usdc.address)).eq(0);

    await handleWithdrawal(fixture, {
      create: {
        market: ethUsdSpotOnlyMarket,
        marketTokenAmount: expandDecimals(50 * 1000 - 10, 18),
        minLongTokenAmount: 100,
      },
    });

    expect(await getBalanceOf(ethUsdSpotOnlyMarket.marketToken, user0.address)).eq("10000000000000000000"); // 10
    expect(await getSupplyOf(ethUsdSpotOnlyMarket.marketToken)).eq("10000000000000000000"); // 10
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdSpotOnlyMarket.marketToken)).eq("2000000000000000"); // 0.002 ETH, ~10 USD
    expect(await usdc.balanceOf(ethUsdSpotOnlyMarket.marketToken)).eq(0);
    expect(await wnt.balanceOf(user0.address)).eq("9998000000000000000"); // 9.998 ETH
    expect(await usdc.balanceOf(user0.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdSpotOnlyMarket.marketToken, wnt.address)).eq("2000000000000000"); // 0.002 ETH, ~10 USD
    expect(await getPoolAmount(dataStore, ethUsdSpotOnlyMarket.marketToken, usdc.address)).eq(0);
  });

  it("price impact, fees", async () => {
    // 0.05%: 0.0005
    await dataStore.setUint(keys.depositFeeFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 4));
    await dataStore.setUint(keys.depositFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 4));
    await dataStore.setUint(keys.swapFeeFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 4));
    await dataStore.setUint(keys.swapFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 4));
    await dataStore.setUint(keys.withdrawalFeeFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(5, 4));
    await dataStore.setUint(keys.withdrawalFeeFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(5, 4));

    // set price impact to 0.1% for every $100,000 of token imbalance
    // 0.1% => 0.001
    // 0.001 / 100,000 => 1 * (10 ** -8)
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, true), decimalToFloat(1, 8));
    await dataStore.setUint(keys.swapImpactFactorKey(ethUsdMarket.marketToken, false), decimalToFloat(1, 8));
    await dataStore.setUint(keys.swapImpactExponentFactorKey(ethUsdMarket.marketToken), decimalToFloat(2, 0));

    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10, 18),
      },
    });

    expect(await getMarketTokenPrice(fixture)).eq("1000500500500500500500500500500"); // 1.0005005

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("49950000000000000000000"); // 49950
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdMarket.marketToken)).eq(expandDecimals(10, 18));
    expect(await usdc.balanceOf(ethUsdMarket.marketToken)).eq(0);
    expect(await wnt.balanceOf(user0.address)).eq(0);
    expect(await usdc.balanceOf(user0.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(
      "9995000000000000000" // 9.995
    );
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(0);

    expect(await getClaimableFeeAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("0");
    expect(await getClaimableFeeAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("0");

    // 30%
    await dataStore.setUint(keys.SWAP_FEE_RECEIVER_FACTOR, decimalToFloat(3, 1));

    const withdrawalAmountOut = await reader.getWithdrawalAmountOut(
      dataStore.address,
      ethUsdMarket,
      prices.ethUsdMarket,
      expandDecimals(49940, 18), // marketTokenAmount
      AddressZero,
      SwapPricingType.TwoStep
    );

    expect(withdrawalAmountOut[0]).eq("9988002499499499499");
    expect(withdrawalAmountOut[1]).eq(0);

    await handleWithdrawal(fixture, {
      create: {
        market: ethUsdMarket,
        marketTokenAmount: expandDecimals(49940, 18),
        minLongTokenAmount: 100,
      },
      execute: {
        gasUsageLabel: "executeWithdrawal",
      },
    });

    expect(await getClaimableFeeAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("1498949849849849"); // 0.0014989
    expect(await getClaimableFeeAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("0");

    expect(await getMarketTokenPrice(fixture)).eq("2749275325325326000000000000000"); // 2.74927532533

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("10000000000000000000"); // 10
    expect(await getSupplyOf(ethUsdMarket.marketToken)).eq("10000000000000000000"); // 10
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdMarket.marketToken)).eq("11997500500500501"); // 0.011997500500500501 ETH, ~60 USD
    expect(await usdc.balanceOf(ethUsdMarket.marketToken)).eq(0);
    expect(await wnt.balanceOf(user0.address)).eq("9988002499499499499"); // 9.988002499499499499 ETH
    expect(await usdc.balanceOf(user0.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("5498550650650652"); // 0.005498550650650652, 27.5 USD
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(0);

    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(
      "5000000000000000" // 0.005, 25 USD
    );

    await handleWithdrawal(fixture, {
      create: {
        market: ethUsdMarket,
        marketTokenAmount: expandDecimals(10, 18),
      },
      execute: {
        gasUsageLabel: "executeWithdrawal",
      },
    });

    expect(await getClaimableFeeAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("1499774632447446"); // 0.001499774632447446
    expect(await getClaimableFeeAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq("0");

    await usingResult(getMarketTokenPrice(fixture), (marketTokenPrice) => {
      expect(marketTokenPrice).eq(decimalToFloat(1));
    });

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("0");
    expect(await getSupplyOf(ethUsdMarket.marketToken)).eq("0");
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdMarket.marketToken)).eq("6501699125175174"); // 0.006501699125175174 ETH, ~32 USD
    expect(await usdc.balanceOf(ethUsdMarket.marketToken)).eq(0);
    expect(await wnt.balanceOf(user0.address)).eq("9993498300874824826"); // 9.993498300874824826 ETH
    expect(await usdc.balanceOf(user0.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq("1924492727728"); // 0.000001924492727728, 0.0096 USD
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(0);

    expect(await getSwapImpactPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(
      "5000000000000000" // 0.005, 25 USD
    );
  });

  it("handle withdrawal error", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10, 18),
      },
    });

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq(expandDecimals(50 * 1000, 18));

    await handleWithdrawal(fixture, {
      create: {
        market: ethUsdMarket,
        marketTokenAmount: expandDecimals(49940, 18),
        minLongTokenAmount: expandDecimals(11, 18),
      },
      execute: {
        gasUsageLabel: "executeWithdrawal",
        expectedCancellationReason: "InsufficientOutputAmount",
      },
    });

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq(expandDecimals(50 * 1000, 18));
  });

  it("single token market", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdSingleTokenMarket,
        shortTokenAmount: expandDecimals(20 * 1000, 6),
      },
      execute: {
        gasUsageLabel: "executeDeposit",
      },
    });

    expect(await getBalanceOf(ethUsdSingleTokenMarket.marketToken, user0.address)).eq(expandDecimals(20 * 1000, 18));
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

    await handleDeposit(fixture, {
      create: {
        market: ethUsdSingleTokenMarket,
        longTokenAmount: expandDecimals(30 * 1000, 6),
      },
      execute: {
        gasUsageLabel: "executeDeposit",
      },
    });

    expect(await getBalanceOf(ethUsdSingleTokenMarket.marketToken, user0.address)).eq(expandDecimals(50 * 1000, 18));
    expect(await getSupplyOf(ethUsdSingleTokenMarket.marketToken)).eq(expandDecimals(50 * 1000, 18));

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
        expect(poolValueInfo.poolValue).eq(expandDecimals(50 * 1000, 30));
      }
    );

    expect(await usdc.balanceOf(ethUsdSingleTokenMarket.marketToken)).eq(expandDecimals(50 * 1000, 6));
    expect(await usdc.balanceOf(user2.address)).eq(0);

    await handleWithdrawal(fixture, {
      create: {
        market: ethUsdSingleTokenMarket,
        marketTokenAmount: expandDecimals(5000, 18),
        receiver: user2,
      },
      execute: {
        gasUsageLabel: "executeWithdrawal",
      },
    });

    expect(await getBalanceOf(ethUsdSingleTokenMarket.marketToken, user0.address)).eq(expandDecimals(45 * 1000, 18));
    expect(await getSupplyOf(ethUsdSingleTokenMarket.marketToken)).eq(expandDecimals(45 * 1000, 18));

    expect(await usdc.balanceOf(ethUsdSingleTokenMarket.marketToken)).eq(expandDecimals(45 * 1000, 6));
    expect(await usdc.balanceOf(user2.address)).eq(expandDecimals(5 * 1000, 6));

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
        expect(poolValueInfo.poolValue).eq(expandDecimals(45 * 1000, 30));
      }
    );
  });

  it("withdraw with longTokenSwapPath", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10, 18),
        shortTokenAmount: expandDecimals(50_000, 6),
      },
    });

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    await createWithdrawal(fixture, {
      account: user0,
      receiver: user1,
      callbackContract: user2,
      market: ethUsdMarket,
      marketTokenAmount: expandDecimals(1000, 18),
      longTokenSwapPath: [ethUsdMarket.marketToken],
      minLongTokenAmount: 100,
      minShortTokenAmount: 50,
      shouldUnwrapNativeToken: false,
      executionFee: 700,
      callbackGasLimit: 100000,
      gasUsageLabel: "createWithdrawal",
    });

    await executeWithdrawal(fixture, {
      gasUsageLabel: "executeWithdrawal",
    });

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(expandDecimals(1000, 6));
  });

  it("withdraw with shortTokenSwapPath", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10, 18),
        shortTokenAmount: expandDecimals(50_000, 6),
      },
    });

    expect(await wnt.balanceOf(user1.address)).eq(0);
    expect(await usdc.balanceOf(user1.address)).eq(0);

    await createWithdrawal(fixture, {
      account: user0,
      receiver: user1,
      callbackContract: user2,
      market: ethUsdMarket,
      marketTokenAmount: expandDecimals(1000, 18),
      shortTokenSwapPath: [ethUsdMarket.marketToken],
      minLongTokenAmount: 100,
      minShortTokenAmount: 50,
      shouldUnwrapNativeToken: false,
      executionFee: 700,
      callbackGasLimit: 100000,
      gasUsageLabel: "createWithdrawal",
    });

    await executeWithdrawal(fixture, {
      gasUsageLabel: "executeWithdrawal",
    });

    expect(await wnt.balanceOf(user1.address)).eq(expandDecimals(2, 17)); // 0.2 ETH => $1000
    expect(await usdc.balanceOf(user1.address)).eq(0);
  });

  it("executeAtomicWithdrawal", async () => {
    await handleDeposit(fixture, {
      create: {
        market: ethUsdMarket,
        longTokenAmount: expandDecimals(10, 18),
        shortTokenAmount: expandDecimals(10 * 5000, 6),
      },
    });

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq(expandDecimals(100 * 1000, 18));
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdMarket.marketToken)).eq(expandDecimals(10, 18));
    expect(await usdc.balanceOf(ethUsdMarket.marketToken)).eq(expandDecimals(50 * 1000, 6));
    expect(await wnt.balanceOf(user0.address)).eq(0);
    expect(await usdc.balanceOf(user0.address)).eq(0);

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(expandDecimals(10, 18));
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(expandDecimals(50 * 1000, 6));

    expect(await getWithdrawalCount(dataStore)).eq(0);

    await executeAtomicWithdrawal(fixture, {
      receiver: user0,
      market: ethUsdMarket,
      marketTokenAmount: expandDecimals(1000, 18),
      minLongTokenAmount: 100,
      minShortTokenAmount: 50,
      shouldUnwrapNativeToken: false,
      gasUsageLabel: "executeAtomicWithdrawal",
    });

    expect(await getWithdrawalCount(dataStore)).eq(0);

    expect(await getMarketTokenPrice(fixture)).eq(expandDecimals(1, 30));

    expect(await getBalanceOf(ethUsdMarket.marketToken, user0.address)).eq("99000000000000000000000"); // 99000
    expect(await wnt.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await usdc.balanceOf(withdrawalHandler.address)).eq(0);
    expect(await wnt.balanceOf(ethUsdMarket.marketToken)).eq("9900000000000000000"); // 9.9 ETH
    expect(await usdc.balanceOf(ethUsdMarket.marketToken)).eq("49500000000"); // 49500 USDC
    expect(await wnt.balanceOf(user0.address)).eq("100000000000000000"); // 0.1 ETH, 500 USD
    expect(await usdc.balanceOf(user0.address)).eq("500000000"); // 500

    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, wnt.address)).eq(
      "9900000000000000000" // 9.9 ETH
    );
    expect(await getPoolAmount(dataStore, ethUsdMarket.marketToken, usdc.address)).eq(
      "49500000000" // 49500 USDC
    );

    await expect(
      executeAtomicWithdrawal(fixture, {
        receiver: user0,
        market: ethUsdMarket,
        marketTokenAmount: expandDecimals(1000, 18),
        minLongTokenAmount: 100,
        minShortTokenAmount: 50,
        shouldUnwrapNativeToken: false,
        gasUsageLabel: "executeAtomicWithdrawal",
        oracleParams: {
          tokens: [usdc.address],
          providers: [chainlinkPriceFeedProvider.address],
          data: ["0x"],
        },
      })
    ).to.be.revertedWithCustomError(errorsContract, "EmptyPrimaryPrice");

    expect(await getWithdrawalCount(dataStore)).eq(0);
  });
});
