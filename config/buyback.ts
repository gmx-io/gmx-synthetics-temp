import { BigNumberish } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { expandDecimals, percentageToFloat } from "../utils/math";

export type BuybackBatchAmount = {
  token: string;
  amount: BigNumberish;
};

export type BuybackGmxFactor = {
  version: number;
  factor: BigNumberish;
};

export type BuybackConfig = {
  batchAmounts: BuybackBatchAmount[];
  gmxFactors: BuybackGmxFactor[];
  maxPriceAge: number;
};

export default async function (hre: HardhatRuntimeEnvironment): Promise<BuybackConfig> {
  const defaultEmptyConfig = {
    batchAmounts: [],
    gmxFactors: [],
    maxPriceAge: 0,
  };

  const defaultBuybackGmxFactor = [
    {
      version: 1,
      factor: percentageToFloat("30%"),
    },
    {
      version: 2,
      factor: percentageToFloat("72.97%"), // 27 / 37
    },
  ];

  const defaultMaxPriceAge = 30;

  const config: { [network: string]: BuybackConfig } = {
    localhost: defaultEmptyConfig,
    hardhat: defaultEmptyConfig,

    arbitrum: {
      batchAmounts: [
        {
          token: "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a", // GMX
          amount: expandDecimals(100, 18),
        },
        {
          token: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", // WETH
          amount: expandDecimals(1, 18),
        },
      ],
      gmxFactors: defaultBuybackGmxFactor,
      maxPriceAge: defaultMaxPriceAge,
    },

    avalanche: {
      batchAmounts: [
        {
          token: "0x62edc0692BD897D2295872a9FFCac5425011c661", // GMX
          amount: expandDecimals(50, 18),
        },
        {
          token: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7", // WAVAX
          amount: expandDecimals(50, 18),
        },
      ],
      gmxFactors: defaultBuybackGmxFactor,
      maxPriceAge: defaultMaxPriceAge,
    },

    arbitrumSepolia: defaultEmptyConfig,
    arbitrumGoerli: defaultEmptyConfig,

    avalancheFuji: defaultEmptyConfig,
  };

  const networkConfig: BuybackConfig = config[hre.network.name];

  return networkConfig;
}
