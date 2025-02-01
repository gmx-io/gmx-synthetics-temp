// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../event/EventEmitter.sol";
import "../../shift/ShiftUtils.sol";
import "../GlvUtils.sol";
import "../GlvVault.sol";

import "./GlvShiftStoreUtils.sol";
import "./GlvShiftEventUtils.sol";

library GlvShiftUtils {
    using GlvShift for GlvShift.Props;
    using SafeCast for int256;
    using SafeCast for uint256;

    struct CreateGlvShiftParams {
        address glv;
        address fromMarket;
        address toMarket;
        uint256 marketTokenAmount;
        uint256 minMarketTokens;
    }

    struct ExecuteGlvShiftParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        Oracle oracle;
        ShiftVault shiftVault;
        GlvVault glvVault;
        bytes32 key;
        address keeper;
    }

    struct ExecuteGlvShiftCache {
        Market.Props fromMarket;
        Market.Props toMarket;
        Shift.Props shift;
        MarketPoolValueInfo.Props fromMarketPoolValueInfo;
        uint256 fromMarketTokenSupply;
        MarketPoolValueInfo.Props toMarketPoolValueInfo;
        uint256 toMarketTokenSupply;
        uint256 marketTokensUsd;
        uint256 receivedMarketTokens;
        uint256 receivedMarketTokensUsd;
        bytes32 shiftKey;
        uint256 glvValue;
        uint256 glvSupply;
    }

    function createGlvShift(
        DataStore dataStore,
        EventEmitter eventEmitter,
        CreateGlvShiftParams memory params
    ) external returns (bytes32) {
        GlvUtils.validateGlv(dataStore, params.glv);
        GlvUtils.validateGlvMarket(dataStore, params.glv, params.fromMarket, false);
        GlvUtils.validateGlvMarket(dataStore, params.glv, params.toMarket, true);

        validateGlvShiftInterval(dataStore, params.glv);

        uint256 fromMarketTokenBalance = GlvToken(payable(params.glv)).tokenBalances(params.fromMarket);
        if (fromMarketTokenBalance < params.marketTokenAmount) {
            revert Errors.GlvInsufficientMarketTokenBalance(
                params.glv,
                params.fromMarket,
                fromMarketTokenBalance,
                params.marketTokenAmount
            );
        }

        MarketUtils.validateEnabledMarket(dataStore, params.fromMarket);
        MarketUtils.validateEnabledMarket(dataStore, params.toMarket);

        GlvShift.Props memory glvShift = GlvShift.Props(
            GlvShift.Addresses({glv: params.glv, fromMarket: params.fromMarket, toMarket: params.toMarket}),
            GlvShift.Numbers({
                marketTokenAmount: params.marketTokenAmount,
                minMarketTokens: params.minMarketTokens,
                updatedAtTime: Chain.currentTimestamp()
            })
        );

        bytes32 key = NonceUtils.getNextKey(dataStore);

        GlvShiftStoreUtils.set(dataStore, key, glvShift);

        GlvShiftEventUtils.emitGlvShiftCreated(eventEmitter, key, glvShift);

        return key;
    }

    function validateGlvShiftInterval(DataStore dataStore, address glv) internal view {
        uint256 glvShiftMinInterval = dataStore.getUint(Keys.glvShiftMinIntervalKey(glv));
        if (glvShiftMinInterval == 0) {
            return;
        }

        uint256 glvShiftLastExecutedAt = dataStore.getUint(Keys.glvShiftLastExecutedAtKey(glv));
        if (Chain.currentTimestamp() < glvShiftLastExecutedAt + glvShiftMinInterval) {
            revert Errors.GlvShiftIntervalNotYetPassed(
                Chain.currentTimestamp(),
                glvShiftLastExecutedAt,
                glvShiftMinInterval
            );
        }
    }

    function executeGlvShift(
        ExecuteGlvShiftParams memory params,
        GlvShift.Props memory glvShift
    ) external returns (uint256) {
        GlvShiftStoreUtils.remove(params.dataStore, params.key);

        validateGlvShiftInterval(params.dataStore, glvShift.glv());
        params.dataStore.setUint(Keys.glvShiftLastExecutedAtKey(glvShift.glv()), Chain.currentTimestamp());

        Bank(payable(glvShift.glv())).transferOut(
            glvShift.fromMarket(),
            address(params.shiftVault),
            glvShift.marketTokenAmount()
        );
        params.shiftVault.syncTokenBalance(glvShift.fromMarket());

        ExecuteGlvShiftCache memory cache;
        cache.shift = Shift.Props(
            Shift.Addresses({
                account: glvShift.glv(),
                receiver: glvShift.glv(),
                callbackContract: address(0),
                uiFeeReceiver: address(0),
                fromMarket: glvShift.fromMarket(),
                toMarket: glvShift.toMarket()
            }),
            Shift.Numbers({
                minMarketTokens: glvShift.minMarketTokens(),
                marketTokenAmount: glvShift.marketTokenAmount(),
                updatedAtTime: glvShift.updatedAtTime(),
                executionFee: 0,
                callbackGasLimit: 0
            }),
            new bytes32[](0)
        );

        cache.shiftKey = NonceUtils.getNextKey(params.dataStore);
        params.dataStore.addBytes32(Keys.SHIFT_LIST, cache.shiftKey);
        ShiftEventUtils.emitShiftCreated(params.eventEmitter, cache.shiftKey, cache.shift);

        ShiftUtils.ExecuteShiftParams memory executeShiftParams = ShiftUtils.ExecuteShiftParams({
            dataStore: params.dataStore,
            eventEmitter: params.eventEmitter,
            shiftVault: params.shiftVault,
            oracle: params.oracle,
            key: cache.shiftKey,
            keeper: params.keeper,

            // executionFee is not used for GlvShift's
            // pass gasleft() not to break startGas calculations inside ShiftUtils
            startingGas: gasleft()
        });

        cache.receivedMarketTokens = ShiftUtils.executeShift(executeShiftParams, cache.shift);

        GlvToken(payable(glvShift.glv())).syncTokenBalance(glvShift.toMarket());

        cache.toMarket = MarketStoreUtils.get(params.dataStore, glvShift.toMarket());

        cache.toMarketPoolValueInfo = MarketUtils.getPoolValueInfo(
            params.dataStore,
            cache.toMarket,
            params.oracle.getPrimaryPrice(cache.toMarket.indexToken),
            params.oracle.getPrimaryPrice(cache.toMarket.longToken),
            params.oracle.getPrimaryPrice(cache.toMarket.shortToken),
            Keys.MAX_PNL_FACTOR_FOR_DEPOSITS,
            true // maximize
        );
        cache.toMarketTokenSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(glvShift.toMarket())));

        GlvUtils.validateGlvMarketTokenBalance(
            params.dataStore,
            glvShift.glv(),
            cache.toMarket,
            cache.toMarketPoolValueInfo.poolValue.toUint256(),
            cache.toMarketTokenSupply
        );
        cache.receivedMarketTokensUsd = MarketUtils.marketTokenAmountToUsd(
            cache.receivedMarketTokens,
            cache.toMarketPoolValueInfo.poolValue.toUint256(),
            cache.toMarketTokenSupply
        );

        cache.fromMarket = MarketStoreUtils.get(params.dataStore, glvShift.fromMarket());
        cache.fromMarketPoolValueInfo = MarketUtils.getPoolValueInfo(
            params.dataStore,
            cache.fromMarket,
            params.oracle.getPrimaryPrice(cache.fromMarket.indexToken),
            params.oracle.getPrimaryPrice(cache.fromMarket.longToken),
            params.oracle.getPrimaryPrice(cache.fromMarket.shortToken),
            Keys.MAX_PNL_FACTOR_FOR_DEPOSITS,
            true // maximize
        );
        cache.fromMarketTokenSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(glvShift.fromMarket())));

        cache.marketTokensUsd = MarketUtils.marketTokenAmountToUsd(
            glvShift.marketTokenAmount(),
            cache.fromMarketPoolValueInfo.poolValue.toUint256(),
            cache.fromMarketTokenSupply
        );

        validatePriceImpact(params.dataStore, glvShift.glv(), cache.marketTokensUsd, cache.receivedMarketTokensUsd);

        GlvShiftEventUtils.emitGlvShiftExecuted(params.eventEmitter, params.key, cache.receivedMarketTokens);

        cache.glvValue = GlvUtils.getGlvValue(
            params.dataStore,
            params.oracle,
            glvShift.glv(),
            true // maximize
        );
        cache.glvSupply = GlvToken(payable(glvShift.glv())).totalSupply();
        GlvEventUtils.emitGlvValueUpdated(params.eventEmitter, glvShift.glv(), cache.glvValue, cache.glvSupply);

        return cache.receivedMarketTokens;
    }

    function cancelGlvShift(
        DataStore dataStore,
        EventEmitter eventEmitter,
        bytes32 key,
        string memory reason,
        bytes memory reasonBytes
    ) external {
        GlvShiftStoreUtils.remove(dataStore, key);

        GlvShiftEventUtils.emitGlvShiftCancelled(eventEmitter, key, reason, reasonBytes);
    }

    function validatePriceImpact(
        DataStore dataStore,
        address glv,
        uint256 marketTokensUsd,
        uint256 receivedMarketTokensUsd
    ) internal view {
        if (marketTokensUsd < receivedMarketTokensUsd) {
            // price impact is positive, no need to validate it
            return;
        }

        uint256 glvMaxShiftPriceImpactFactor = dataStore.getUint(Keys.glvShiftMaxPriceImpactFactorKey(glv));

        uint256 effectivePriceImpactFactor = Precision.toFactor(
            marketTokensUsd - receivedMarketTokensUsd,
            marketTokensUsd
        );
        if (effectivePriceImpactFactor > glvMaxShiftPriceImpactFactor) {
            revert Errors.GlvShiftMaxPriceImpactExceeded(effectivePriceImpactFactor, glvMaxShiftPriceImpactFactor);
        }
    }
}
