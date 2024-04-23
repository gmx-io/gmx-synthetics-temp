import { expandDecimals } from "../utils/math";
import * as keys from "../utils/keys";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { setAddressIfDifferent, setBytes32IfDifferent, setUintIfDifferent } from "../utils/dataStore";

const func = async ({ gmx, deployments }: HardhatRuntimeEnvironment) => {
  const oracleConfig = await gmx.getOracle();
  const tokens = await gmx.getTokens();
  const { get } = deployments;

  const chainlinkDataStreamProvider = await get("ChainlinkDataStreamProvider");

  if (oracleConfig) {
    for (const tokenSymbol of Object.keys(oracleConfig.tokens)) {
      const token = tokens[tokenSymbol];
      if (!token) {
        throw new Error(`Missing token for ${tokenSymbol}`);
      }
      const { priceFeed, oracleType } = oracleConfig.tokens[tokenSymbol];

      const oracleTypeKey = keys.oracleTypeKey(token.address);
      await setBytes32IfDifferent(oracleTypeKey, oracleType, "oracle type");

      await setAddressIfDifferent(
        keys.oracleProviderForTokenKey(token.address),
        chainlinkDataStreamProvider.address,
        `oracle provider for ${tokenSymbol}`
      );

      if (!priceFeed) {
        continue;
      }

      const priceFeedAddress = priceFeed.deploy ? (await get(`${tokenSymbol}PriceFeed`)).address : priceFeed.address;

      const priceFeedKey = keys.priceFeedKey(token.address);
      await setAddressIfDifferent(priceFeedKey, priceFeedAddress, `${tokenSymbol} price feed`);

      const priceFeedMultiplierKey = keys.priceFeedMultiplierKey(token.address);
      const priceFeedMultiplier = expandDecimals(1, 60 - priceFeed.decimals - token.decimals);
      await setUintIfDifferent(priceFeedMultiplierKey, priceFeedMultiplier, `${tokenSymbol} price feed multiplier`);

      if (priceFeed.stablePrice) {
        const stablePriceKey = keys.stablePriceKey(token.address);
        const stablePrice = priceFeed.stablePrice.div(expandDecimals(1, token.decimals));
        await setUintIfDifferent(stablePriceKey, stablePrice, `${tokenSymbol} stable price`);
      }

      await setUintIfDifferent(
        keys.priceFeedHeartbeatDurationKey(token.address),
        priceFeed.heartbeatDuration,
        `${tokenSymbol} heartbeat duration`
      );
    }
  }
};

// func.dependencies = ["Tokens", "PriceFeeds", "DataStore", "ChainlinkPriceFeedProvider"];
func.tags = ["ConfigurePriceFeeds"];
export default func;
