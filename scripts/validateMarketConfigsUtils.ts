import { decimalToFloat, exponentToFloat, bigNumberify, formatAmount, pow, FLOAT_PRECISION } from "../utils/math";
import { createMarketConfigByKey, getMarketKey } from "../utils/market";
import { performMulticall } from "../utils/multicall";
import { SECONDS_PER_YEAR } from "../utils/constants";
import * as keys from "../utils/keys";

const priceImpactBpsList = [1, 5, 10, 40];

const stablecoinSymbols = {
  USDC: true,
  "USDC.e": true,
  USDT: true,
  "USDT.e": true,
  DAI: true,
  "DAI.e": true,
  USDe: true,
};

const BASIS_POINTS_DIVISOR = 10_000;

const recommendedStablecoinSwapConfig = {
  negativeSwapImpactFactor: decimalToFloat(1, 9).div(2),
  negativePositionImpactFactor: decimalToFloat(1, 9).div(2),
  expectedSwapImpactRatio: 10_000,
};

// negativePositionImpactFactor: the recommended negative position impact factor
// negativeSwapImpactFactor: the recommended negative swap impact factor
// the market config should be validated to have a higher or equal value to the recommended value
//
// expectedSwapImpactRatio: expected ratio of negative to positive swap price impact
// a ratio of 20_000 means that the negative swap price price impact is twice the positive swap price impact
//
// expectedPositionImpactRatio: expected ratio of negative to positive position price impact
// a ratio of 20_000 means that the negative position price price impact is twice the positive position price impact
const recommendedMarketConfig = {
  arbitrum: {
    APE: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("3e-8"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    BTC: {
      negativePositionImpactFactor: exponentToFloat("5e-11"),
      negativeSwapImpactFactor: exponentToFloat("5e-11"),
      expectedSwapImpactRatio: 10_000,
      expectedPositionImpactRatio: 20_000,
    },
    "BTC:WBTC.e:WBTC.e": {
      negativePositionImpactFactor: 0,
      negativeSwapImpactFactor: 0,
      expectedSwapImpactRatio: 10_000,
      expectedPositionImpactRatio: 20_000,
    },
    WETH: {
      negativePositionImpactFactor: exponentToFloat("5e-11"),
      negativeSwapImpactFactor: exponentToFloat("5e-11"),
      expectedSwapImpactRatio: 10_000,
      expectedPositionImpactRatio: 20_000,
    },
    "WETH:WETH:WETH": {
      negativePositionImpactFactor: 0,
      negativeSwapImpactFactor: 0,
      expectedSwapImpactRatio: 10_000,
      expectedPositionImpactRatio: 20_000,
    },
    BNB: {
      negativePositionImpactFactor: exponentToFloat("3.8e-11"),
      negativeSwapImpactFactor: exponentToFloat("3.8e-11"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    LINK: {
      negativePositionImpactFactor: exponentToFloat("3e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    ARB: {
      negativePositionImpactFactor: exponentToFloat("3.75e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    UNI: {
      negativePositionImpactFactor: exponentToFloat("3.15e-8"),
      negativeSwapImpactFactor: exponentToFloat("3e-8"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    LTC: {
      negativePositionImpactFactor: exponentToFloat("8e-9"),
      negativeSwapImpactFactor: exponentToFloat("8e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    DOGE: {
      negativePositionImpactFactor: exponentToFloat("8e-9"),
      negativeSwapImpactFactor: exponentToFloat("8e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    EIGEN: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    SHIB: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    SOL: {
      negativePositionImpactFactor: decimalToFloat(65, 12),
      negativeSwapImpactFactor: decimalToFloat(65, 12),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    "SOL:SOL:SOL": {
      negativePositionImpactFactor: exponentToFloat("1.35e-09"),
      negativeSwapImpactFactor: 0,
      expectedSwapImpactRatio: 10_000,
      expectedPositionImpactRatio: 20_000,
    },
    STX: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    SATS: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    XRP: {
      negativePositionImpactFactor: exponentToFloat("5e-9"),
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    AAVE: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    AVAX: {
      negativePositionImpactFactor: exponentToFloat("5e-9"),
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    ATOM: {
      negativePositionImpactFactor: exponentToFloat("2.6e-8"),
      negativeSwapImpactFactor: exponentToFloat("2.6e-8"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    NEAR: {
      negativePositionImpactFactor: exponentToFloat("1.95e-8"),
      negativeSwapImpactFactor: exponentToFloat("2.6e-8"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    OP: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    ORDI: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    GMX: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("8e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    "GMX:GMX:GMX": {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: 0,
      expectedSwapImpactRatio: 10_000,
      expectedPositionImpactRatio: 20_000,
    },
    PEPE: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("3e-8"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    WIF: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("3e-8"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    POL: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    SUI: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    SEI: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    APT: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    TIA: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    TRX: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    TAO: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    BONK: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    WLD: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    TON: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    PENDLE: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    BOME: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    MEME: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    FLOKI: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    MEW: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    ADA: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    XLM: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    BCH: {
      negativePositionImpactFactor: exponentToFloat("2.5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    DOT: {
      negativePositionImpactFactor: exponentToFloat("2.5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    ICP: {
      negativePositionImpactFactor: exponentToFloat("2.5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    RENDER: {
      negativePositionImpactFactor: exponentToFloat("2.5e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    FIL: {
      negativePositionImpactFactor: exponentToFloat("5e-10"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    INJ: {
      negativePositionImpactFactor: exponentToFloat("9e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    DYDX: {
      negativePositionImpactFactor: exponentToFloat("9e-9"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    TRUMP: {
      negativePositionImpactFactor: exponentToFloat("5e-7"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 15_000,
    },
    MELANIA: {
      negativePositionImpactFactor: exponentToFloat("5e-7"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 15_000,
    },
    ENA: {
      negativePositionImpactFactor: exponentToFloat("8e-7"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    FARTCOIN: {
      negativePositionImpactFactor: exponentToFloat("5e-7"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    AI16Z: {
      negativePositionImpactFactor: exponentToFloat("5e-7"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    ANIME: {
      negativePositionImpactFactor: exponentToFloat("5e-7"),
      negativeSwapImpactFactor: exponentToFloat("3e-8"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    wstETH: {
      negativeSwapImpactFactor: exponentToFloat("1e-8"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    "wstETH-WETH": {
      negativeSwapImpactFactor: exponentToFloat("5e-9"),
      expectedSwapImpactRatio: 10_000,
    },
  },
  avalanche: {
    "BTC.b": {
      negativePositionImpactFactor: exponentToFloat("5e-11").div(2),
      negativeSwapImpactFactor: exponentToFloat("5e-11").div(2),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 16_666,
    },
    "WETH.e": {
      negativePositionImpactFactor: exponentToFloat("5e-11").div(2),
      negativeSwapImpactFactor: exponentToFloat("5e-11").div(2),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 16_666,
    },
    WAVAX: {
      negativePositionImpactFactor: exponentToFloat("1e-8").div(2),
      negativeSwapImpactFactor: exponentToFloat("5e-9").div(2),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    LTC: {
      negativePositionImpactFactor: exponentToFloat("8e-9").div(2),
      negativeSwapImpactFactor: exponentToFloat("8e-9").div(2),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    DOGE: {
      negativePositionImpactFactor: exponentToFloat("8e-9").div(2),
      negativeSwapImpactFactor: exponentToFloat("8e-9").div(2),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    SOL: {
      negativePositionImpactFactor: exponentToFloat("5e-9").div(2),
      negativeSwapImpactFactor: exponentToFloat("5e-9").div(2),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    XRP: {
      negativePositionImpactFactor: exponentToFloat("5e-9").div(2),
      negativeSwapImpactFactor: exponentToFloat("5e-9").div(2),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    TRUMP: {
      negativePositionImpactFactor: exponentToFloat("5e-7"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
    MELANIA: {
      negativePositionImpactFactor: exponentToFloat("5e-7"),
      expectedSwapImpactRatio: 20_000,
      expectedPositionImpactRatio: 20_000,
    },
  },
};

const configTokenMapping = {
  arbitrum: {
    "WBTC.e": "BTC",
  },
};

function getTradeSizeForImpact({ priceImpactBps, impactExponentFactor, impactFactor }) {
  if (bigNumberify(0).eq(impactFactor)) {
    return bigNumberify(0);
  }
  const exponent = 1 / (impactExponentFactor.div(decimalToFloat(1, 2)).toNumber() / 100 - 1);
  const base = bigNumberify(priceImpactBps).mul(decimalToFloat(1)).div(10_000).div(impactFactor).toNumber();

  const tradeSize = Math.pow(base, exponent);

  if (tradeSize === Infinity) {
    return 0;
  }

  return tradeSize.toFixed(0);
}

async function validatePerpConfig({
  market = undefined,
  marketConfig,
  longTokenSymbol,
  shortTokenSymbol,
  indexTokenSymbol,
  dataStore,
  errors,
}) {
  if (!marketConfig.tokens.indexToken) {
    return;
  }

  const marketLabel = `${indexTokenSymbol} [${longTokenSymbol}-${shortTokenSymbol}]`;

  console.log("validatePerpConfig", indexTokenSymbol);
  const recommendedPerpConfig =
    recommendedMarketConfig[hre.network.name][`${indexTokenSymbol}:${longTokenSymbol}:${shortTokenSymbol}`] ??
    recommendedMarketConfig[hre.network.name][indexTokenSymbol];

  if (!recommendedPerpConfig || recommendedPerpConfig.negativePositionImpactFactor === undefined) {
    throw new Error(`Empty recommendedPerpConfig for ${indexTokenSymbol}`);
  }

  let negativePositionImpactFactor = bigNumberify(marketConfig.negativePositionImpactFactor);
  let positivePositionImpactFactor = bigNumberify(marketConfig.positivePositionImpactFactor);
  let positionImpactExponentFactor = bigNumberify(marketConfig.positionImpactExponentFactor);
  let openInterestReserveFactorLongs = bigNumberify(marketConfig.openInterestReserveFactorLongs);
  let openInterestReserveFactorShorts = bigNumberify(marketConfig.openInterestReserveFactorShorts);
  let borrowingFactorForLongs = bigNumberify(marketConfig.borrowingFactorForLongs);
  let borrowingExponentFactorForLongs = bigNumberify(marketConfig.borrowingExponentFactorForLongs);
  let borrowingFactorForShorts = bigNumberify(marketConfig.borrowingFactorForShorts);
  let borrowingExponentFactorForShorts = bigNumberify(marketConfig.borrowingExponentFactorForShorts);
  const optimalUsageFactorForLongs = bigNumberify(marketConfig.optimalUsageFactorForLongs);
  const optimalUsageFactorForShorts = bigNumberify(marketConfig.optimalUsageFactorForShorts);
  const baseBorrowingFactorForLongs = bigNumberify(marketConfig.baseBorrowingFactorForLongs);
  const baseBorrowingFactorForShorts = bigNumberify(marketConfig.baseBorrowingFactorForShorts);
  const aboveOptimalUsageBorrowingFactorForLongs = bigNumberify(marketConfig.aboveOptimalUsageBorrowingFactorForLongs);
  const aboveOptimalUsageBorrowingFactorForShorts = bigNumberify(
    marketConfig.aboveOptimalUsageBorrowingFactorForShorts
  );
  let fundingFactor = bigNumberify(marketConfig.fundingFactor);
  let fundingExponentFactor = bigNumberify(marketConfig.fundingExponentFactor);
  const maxOpenInterestForLongs = bigNumberify(marketConfig.maxOpenInterestForLongs);
  const maxOpenInterestForShorts = bigNumberify(marketConfig.maxOpenInterestForShorts);

  if (maxOpenInterestForLongs === undefined) {
    throw new Error(`Empty maxOpenInterestForLongs for ${marketLabel}`);
  }

  if (maxOpenInterestForShorts === undefined) {
    throw new Error(`Empty maxOpenInterestForShorts for ${marketLabel}`);
  }

  if (process.env.READ_FROM_CHAIN === "true") {
    const multicallReadParams = [];

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.positionImpactFactorKey(market.marketToken, false),
      ]),
      label: "negativePositionImpactFactor",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.positionImpactFactorKey(market.marketToken, true),
      ]),
      label: "positivePositionImpactFactor",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.positionImpactExponentFactorKey(market.marketToken),
      ]),
      label: "positionImpactExponentFactor",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.openInterestReserveFactorKey(market.marketToken, true),
      ]),
      label: "openInterestReserveFactorLongs",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.openInterestReserveFactorKey(market.marketToken, false),
      ]),
      label: "openInterestReserveFactorShorts",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [keys.borrowingFactorKey(market.marketToken, true)]),
      label: "borrowingFactorForLongs",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.borrowingExponentFactorKey(market.marketToken, true),
      ]),
      label: "borrowingExponentFactorForLongs",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [keys.borrowingFactorKey(market.marketToken, false)]),
      label: "borrowingFactorForShorts",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.borrowingExponentFactorKey(market.marketToken, false),
      ]),
      label: "borrowingExponentFactorForShorts",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [keys.fundingFactorKey(market.marketToken)]),
      label: "fundingFactor",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [keys.fundingExponentFactorKey(market.marketToken)]),
      label: "fundingExponentFactor",
    });

    const { bigNumberResults } = await performMulticall({ multicallReadParams });
    ({
      negativePositionImpactFactor,
      positivePositionImpactFactor,
      positionImpactExponentFactor,
      openInterestReserveFactorLongs,
      openInterestReserveFactorShorts,
      borrowingFactorForLongs,
      borrowingExponentFactorForLongs,
      borrowingFactorForShorts,
      borrowingExponentFactorForShorts,
      fundingFactor,
      fundingExponentFactor,
    } = bigNumberResults);
  }

  if (bigNumberify(recommendedPerpConfig.negativePositionImpactFactor).gt(0)) {
    const percentageOfPerpImpactRecommendation = bigNumberify(negativePositionImpactFactor)
      .mul(100)
      .div(recommendedPerpConfig.negativePositionImpactFactor);

    console.log(
      `    Position impact compared to recommendation: ${
        percentageOfPerpImpactRecommendation.toNumber() / 100
      }x smallest safe value`
    );
  }

  for (const priceImpactBps of priceImpactBpsList) {
    console.log(
      `    Negative (${formatAmount(priceImpactBps, 2, 2)}%): $${formatAmount(
        getTradeSizeForImpact({
          priceImpactBps,
          impactExponentFactor: positionImpactExponentFactor,
          impactFactor: negativePositionImpactFactor,
        }),
        0,
        0,
        true
      )}, Positive (${formatAmount(priceImpactBps, 2, 2)}%): $${formatAmount(
        getTradeSizeForImpact({
          priceImpactBps,
          impactExponentFactor: positionImpactExponentFactor,
          impactFactor: positivePositionImpactFactor,
        }),
        0,
        0,
        true
      )}`
    );
  }

  if (negativePositionImpactFactor.eq(0)) {
    console.warn(`Position price impact for ${marketLabel} is zero`);
  }

  if (negativePositionImpactFactor.gt(0) && positivePositionImpactFactor.gt(0)) {
    const impactRatio = negativePositionImpactFactor.mul(BASIS_POINTS_DIVISOR).div(positivePositionImpactFactor);
    if (impactRatio.lt(recommendedPerpConfig.expectedPositionImpactRatio)) {
      console.error(
        "invalid position impact factors ratio is %s expected ratio %s",
        impactRatio,
        recommendedPerpConfig.expectedPositionImpactRatio
      );
      throw new Error(`Invalid position impact factors for ${marketLabel}`);
    }
  }

  if (negativePositionImpactFactor.lt(recommendedPerpConfig.negativePositionImpactFactor)) {
    errors.push({
      message: `Invalid negativePositionImpactFactor for ${marketLabel}`,
      expected: recommendedPerpConfig.negativePositionImpactFactor,
      actual: negativePositionImpactFactor,
    });
  }

  if (
    borrowingExponentFactorForLongs.lt(decimalToFloat(1)) ||
    borrowingExponentFactorForLongs.gt(decimalToFloat(15, 1))
  ) {
    throw new Error(
      `borrowingExponentFactorForLongs should be in range 1 – 1.5, provided ${formatAmount(
        borrowingExponentFactorForLongs,
        30
      )}`
    );
  }

  if (
    borrowingExponentFactorForShorts.lt(decimalToFloat(1)) ||
    borrowingExponentFactorForShorts.gt(decimalToFloat(15, 1))
  ) {
    throw new Error(
      `borrowingExponentFactorForShorts should be in range 1 – 1.5, provided ${formatAmount(
        borrowingExponentFactorForShorts,
        30
      )}`
    );
  }

  const maxLongTokenPoolUsdBasedOnMaxOpenInterest = maxOpenInterestForLongs
    .mul(FLOAT_PRECISION)
    .div(openInterestReserveFactorLongs);
  const maxBorrowingFactorForLongsPerYear = pow(maxOpenInterestForLongs, borrowingExponentFactorForLongs)
    .mul(borrowingFactorForLongs)
    .div(maxLongTokenPoolUsdBasedOnMaxOpenInterest)
    .mul(SECONDS_PER_YEAR);

  if (maxBorrowingFactorForLongsPerYear.gt(decimalToFloat(15, 1))) {
    throw new Error("maxBorrowingFactorForLongsPerYear is more than 150%");
  }

  console.log(`    maxBorrowingFactorForLongsPerYear: ${formatAmount(maxBorrowingFactorForLongsPerYear, 28)}%`);

  const maxShortTokenPoolUsdBasedOnMaxOpenInterest = maxOpenInterestForShorts
    .mul(FLOAT_PRECISION)
    .div(openInterestReserveFactorShorts);
  const maxBorrowingFactorForShortsPerYear = pow(maxOpenInterestForShorts, borrowingExponentFactorForShorts)
    .mul(borrowingFactorForShorts)
    .div(maxShortTokenPoolUsdBasedOnMaxOpenInterest)
    .mul(SECONDS_PER_YEAR);

  if (maxBorrowingFactorForShortsPerYear.gt(decimalToFloat(15, 1))) {
    throw new Error("maxBorrowingFactorForShortsPerYear is more than 150%");
  }

  console.log(`    maxBorrowingFactorForShortsPerYear: ${formatAmount(maxBorrowingFactorForShortsPerYear, 28)}%`);

  for (const [key, value] of Object.entries({
    optimalUsageFactorForLongs,
    optimalUsageFactorForShorts,
  })) {
    if (value.gt(decimalToFloat(1))) {
      throw new Error(`${key} is more than 100% annualized`);
    }
  }

  for (const [key, value] of Object.entries({
    baseBorrowingFactorForLongs,
    baseBorrowingFactorForShorts,
  })) {
    if (value.mul(SECONDS_PER_YEAR).gt(decimalToFloat(1))) {
      throw new Error(`${key} is more than 100% annualized`);
    }
  }

  for (const [key, value] of Object.entries({
    aboveOptimalUsageBorrowingFactorForLongs,
    aboveOptimalUsageBorrowingFactorForShorts,
  })) {
    if (value.mul(SECONDS_PER_YEAR).gt(decimalToFloat(3))) {
      throw new Error(`${key} is more than 300% annualized`);
    }
  }

  if (!fundingExponentFactor.eq(decimalToFloat(1))) {
    throw new Error("fundingExponentFactor != 1");
  }

  const maxFundingFactorPerYear = fundingFactor.mul(SECONDS_PER_YEAR);

  if (maxFundingFactorPerYear.gt(decimalToFloat(1))) {
    throw new Error("maxFundingFactorPerYear is more than 100%");
  }

  console.log(`    maxFundingFactorPerYear: ${formatAmount(maxFundingFactorPerYear, 28)}%`);
}

async function validateSwapConfig({
  market = undefined,
  marketConfig,
  indexTokenSymbol,
  longTokenSymbol,
  shortTokenSymbol,
  dataStore,
  errors,
}) {
  const isStablecoinMarket = stablecoinSymbols[longTokenSymbol] && stablecoinSymbols[shortTokenSymbol];

  let recommendedSwapConfig;

  if (longTokenSymbol === shortTokenSymbol) {
    if (!marketConfig.negativeSwapImpactFactor.eq(0)) {
      throw new Error("negativeSwapImpactFactor should be zero");
    }

    if (!marketConfig.positiveSwapImpactFactor.eq(0)) {
      throw new Error("negativeSwapImpactFactor should be zero");
    }

    return;
  }

  if (isStablecoinMarket) {
    recommendedSwapConfig = recommendedStablecoinSwapConfig;
  } else {
    // first try to get config for longToken
    // if that is empty try to get config for longToken after re-mapping it using configTokenMapping
    recommendedSwapConfig =
      recommendedMarketConfig[hre.network.name][longTokenSymbol] ||
      recommendedMarketConfig[hre.network.name][configTokenMapping[hre.network.name][longTokenSymbol]];
  }

  const recommendedSwapConfigOverride =
    recommendedMarketConfig[hre.network.name][`${longTokenSymbol}-${shortTokenSymbol}`];
  if (recommendedSwapConfigOverride) {
    recommendedSwapConfig = recommendedSwapConfigOverride;
  }

  if (!recommendedSwapConfig) {
    throw new Error(`Empty recommendedSwapConfig for ${longTokenSymbol}`);
  }

  let negativeSwapImpactFactor = marketConfig.negativeSwapImpactFactor;
  let positiveSwapImpactFactor = marketConfig.positiveSwapImpactFactor;
  let swapImpactExponentFactor = marketConfig.swapImpactExponentFactor;

  if (process.env.READ_FROM_CHAIN === "true") {
    const multicallReadParams = [];

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.swapImpactFactorKey(market.marketToken, false),
      ]),
      label: "negativeSwapImpactFactor",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [keys.swapImpactFactorKey(market.marketToken, true)]),
      label: "positiveSwapImpactFactor",
    });

    multicallReadParams.push({
      target: dataStore.address,
      allowFailure: false,
      callData: dataStore.interface.encodeFunctionData("getUint", [
        keys.swapImpactExponentFactorKey(market.marketToken),
      ]),
      label: "swapImpactExponentFactor",
    });

    const { bigNumberResults } = await performMulticall({ multicallReadParams });
    ({ negativeSwapImpactFactor, positiveSwapImpactFactor, swapImpactExponentFactor } = bigNumberResults);
  }

  const percentageOfSwapImpactRecommendation = negativeSwapImpactFactor
    .mul(100)
    .div(recommendedSwapConfig.negativeSwapImpactFactor);

  console.log(
    `    Swap impact compared to recommendation: ${
      parseFloat(percentageOfSwapImpactRecommendation.toNumber()) / 100
    }x smallest safe value`
  );

  for (const priceImpactBps of priceImpactBpsList) {
    console.log(
      `    Negative (${formatAmount(priceImpactBps, 2, 2)}%): $${formatAmount(
        getTradeSizeForImpact({
          priceImpactBps,
          impactExponentFactor: swapImpactExponentFactor,
          impactFactor: negativeSwapImpactFactor,
        }),
        0,
        0,
        true
      )}, Positive: (${formatAmount(priceImpactBps, 2, 2)}%): $${formatAmount(
        getTradeSizeForImpact({
          priceImpactBps,
          impactExponentFactor: swapImpactExponentFactor,
          impactFactor: positiveSwapImpactFactor,
        }),
        0,
        0,
        true
      )}`
    );
  }

  const impactRatio = negativeSwapImpactFactor.mul(BASIS_POINTS_DIVISOR).div(positiveSwapImpactFactor);
  if (impactRatio.lt(recommendedSwapConfig.expectedSwapImpactRatio)) {
    throw new Error(
      `Invalid swap impact factors for ${indexTokenSymbol}[${longTokenSymbol}-${shortTokenSymbol}]: ${impactRatio} expected ${recommendedSwapConfig.expectedSwapImpactRatio} negativeSwapImpactFactor ${negativeSwapImpactFactor} positiveSwapImpactFactor ${positiveSwapImpactFactor}`
    );
  }

  if (negativeSwapImpactFactor.lt(recommendedSwapConfig.negativeSwapImpactFactor)) {
    errors.push({
      message: `Invalid negativeSwapImpactFactor for ${indexTokenSymbol}[${longTokenSymbol}-${shortTokenSymbol}]`,
      expected: recommendedSwapConfig.negativeSwapImpactFactor,
      actual: negativeSwapImpactFactor,
    });
  }
}

export async function validateMarketConfigs() {
  const tokens = await hre.gmx.getTokens();
  const marketConfigs = await hre.gmx.getMarkets();
  const marketConfigByKey = createMarketConfigByKey({ marketConfigs, tokens });

  const addressToSymbol: { [address: string]: string } = {};
  for (const [tokenSymbol, tokenConfig] of Object.entries(tokens)) {
    let address = tokenConfig.address;
    if (!address) {
      address = (await hre.ethers.getContract(tokenSymbol)).address;
    }
    addressToSymbol[address] = tokenSymbol;
  }

  const reader = await hre.ethers.getContract("Reader");
  const dataStore = await hre.ethers.getContract("DataStore");
  console.log("reading data from DataStore %s Reader %s", dataStore.address, reader.address);
  const markets = [...(await reader.getMarkets(dataStore.address, 0, 100))];
  markets.sort((a, b) => a.indexToken.localeCompare(b.indexToken));

  const errors = [];

  // validate market configs as some markets may not be created on-chain yet
  for (const marketConfig of marketConfigs) {
    const indexTokenSymbol = marketConfig.tokens.indexToken;
    const longTokenSymbol = marketConfig.tokens.longToken;
    const shortTokenSymbol = marketConfig.tokens.shortToken;

    console.log(
      "index: %s long: %s short: %s",
      indexTokenSymbol?.padEnd(5) || "(swap only)",
      longTokenSymbol?.padEnd(5),
      shortTokenSymbol?.padEnd(5)
    );

    if (
      !marketConfig.maxLongTokenPoolAmount ||
      !marketConfig.maxShortTokenPoolAmount ||
      !marketConfig.maxLongTokenPoolUsdForDeposit ||
      !marketConfig.maxShortTokenPoolUsdForDeposit
    ) {
      throw new Error(`Missing configs for ${indexTokenSymbol}[${longTokenSymbol}-${shortTokenSymbol}]`);
    }

    await validatePerpConfig({ marketConfig, indexTokenSymbol, longTokenSymbol, shortTokenSymbol, dataStore, errors });
    await validateSwapConfig({ marketConfig, indexTokenSymbol, longTokenSymbol, shortTokenSymbol, dataStore, errors });
  }

  const marketKeysToSkip = {
    "0x74885b4D524d497261259B38900f54e6dbAd2210:0x74885b4D524d497261259B38900f54e6dbAd2210:0xaf88d065e77c8cC2239327C5EDb3A432268e5831":
      true, // old APE market
  };

  for (const market of markets) {
    const indexTokenSymbol = addressToSymbol[market.indexToken];
    const longTokenSymbol = addressToSymbol[market.longToken];
    const shortTokenSymbol = addressToSymbol[market.shortToken];
    const marketKey = getMarketKey(market.indexToken, market.longToken, market.shortToken);

    if (marketKeysToSkip[marketKey]) {
      continue;
    }

    const marketConfig = marketConfigByKey[marketKey];

    console.log(
      "%s index: %s long: %s short: %s",
      market.marketToken,
      indexTokenSymbol?.padEnd(5) || "(swap only)",
      longTokenSymbol?.padEnd(5),
      shortTokenSymbol?.padEnd(5)
    );

    await validatePerpConfig({
      market,
      marketConfig,
      longTokenSymbol,
      shortTokenSymbol,
      indexTokenSymbol,
      dataStore,
      errors,
    });
    await validateSwapConfig({
      market,
      marketConfig,
      longTokenSymbol,
      shortTokenSymbol,
      indexTokenSymbol,
      dataStore,
      errors,
    });
  }

  for (const error of errors) {
    console.log(`Error: ${error.message}, expected: ${error.expected.toString()}, actual: ${error.actual.toString()}`);
  }

  return { errors };
}
