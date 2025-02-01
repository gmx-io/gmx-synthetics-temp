// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./GlvDeposit.sol";
import "../GlvUtils.sol";

library GlvDepositCalc {
    using GlvDeposit for GlvDeposit.Props;
    using SafeCast for int256;

    address public constant RECEIVER_FOR_FIRST_GLV_DEPOSIT = address(1);

    function validateFirstGlvDeposit(
        DataStore dataStore,
        GlvDeposit.Props memory glvDeposit
    ) external view {
        address glv = glvDeposit.glv();
        uint256 initialGlvTokenSupply = GlvToken(payable(glv)).totalSupply();

        // return if this is not the first glv deposit
        if (initialGlvTokenSupply != 0) {
            return;
        }

        uint256 minGlvTokens = dataStore.getUint(Keys.minGlvTokensForFirstGlvDepositKey(glv));

        // return if there is no minGlvTokens requirement
        if (minGlvTokens == 0) {
            return;
        }

        if (glvDeposit.receiver() != RECEIVER_FOR_FIRST_GLV_DEPOSIT) {
            revert Errors.InvalidReceiverForFirstGlvDeposit(glvDeposit.receiver(), RECEIVER_FOR_FIRST_GLV_DEPOSIT);
        }

        if (glvDeposit.minGlvTokens() < minGlvTokens) {
            revert Errors.InvalidMinGlvTokensForFirstGlvDeposit(glvDeposit.minGlvTokens(), minGlvTokens);
        }
    }

    function getMintAmount(
        DataStore dataStore,
        Oracle oracle,
        GlvDeposit.Props memory glvDeposit,
        uint256 receivedMarketTokens,
        uint256 glvValue,
        uint256 glvSupply
    ) external view returns (uint256) {
        Market.Props memory market = MarketUtils.getEnabledMarket(dataStore, glvDeposit.market());
        MarketPoolValueInfo.Props memory poolValueInfo = MarketUtils.getPoolValueInfo(
            dataStore,
            market,
            oracle.getPrimaryPrice(market.indexToken),
            oracle.getPrimaryPrice(market.longToken),
            oracle.getPrimaryPrice(market.shortToken),
            Keys.MAX_PNL_FACTOR_FOR_DEPOSITS,
            false // maximize
        );
        uint256 marketTokenSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(market.marketToken)));
        uint256 receivedMarketTokensUsd = MarketUtils.marketTokenAmountToUsd(
            receivedMarketTokens,
            poolValueInfo.poolValue.toUint256(),
            marketTokenSupply
        );
        return GlvUtils.usdToGlvTokenAmount(receivedMarketTokensUsd, glvValue, glvSupply);
    }
}
