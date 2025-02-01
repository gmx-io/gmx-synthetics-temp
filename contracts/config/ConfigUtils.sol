// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../event/EventEmitter.sol";
import "../utils/Cast.sol";
import "../utils/Precision.sol";
import "../market/MarketUtils.sol";

library ConfigUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.Bytes32Items;

    function setPriceFeed(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address token,
        address priceFeed,
        uint256 priceFeedMultiplier,
        uint256 priceFeedHeartbeatDuration,
        uint256 stablePrice
    ) external {
        if (dataStore.getAddress(Keys.priceFeedKey(token)) != address(0)) {
            revert Errors.PriceFeedAlreadyExistsForToken(token);
        }

        dataStore.setAddress(Keys.priceFeedKey(token), priceFeed);
        dataStore.setUint(Keys.priceFeedMultiplierKey(token), priceFeedMultiplier);
        dataStore.setUint(Keys.priceFeedHeartbeatDurationKey(token), priceFeedHeartbeatDuration);
        dataStore.setUint(Keys.stablePriceKey(token), stablePrice);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "priceFeed", priceFeed);

        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "priceFeedMultiplier", priceFeedMultiplier);
        eventData.uintItems.setItem(1, "priceFeedHeartbeatDuration", priceFeedHeartbeatDuration);
        eventData.uintItems.setItem(2, "stablePrice", stablePrice);

        eventEmitter.emitEventLog1(
            "ConfigSetPriceFeed",
            Cast.toBytes32(token),
            eventData
        );
    }

    function setDataStream(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address token,
        bytes32 feedId,
        uint256 dataStreamMultiplier,
        uint256 dataStreamSpreadReductionFactor,
        uint256 maxAllowedMaxFundingFactorPerSecond,
        uint256 maxAllowedFundingIncreaseFactorPerSecond,
        uint256 maxAllowedFundingDecreaseFactorPerSecond
    ) external {
        if (dataStore.getBytes32(Keys.dataStreamIdKey(token)) != bytes32(0)) {
            revert Errors.DataStreamIdAlreadyExistsForToken(token);
        }

        validateRange(
            dataStore,
            Keys.DATA_STREAM_SPREAD_REDUCTION_FACTOR,
            abi.encode(token),
            dataStreamSpreadReductionFactor,
            maxAllowedMaxFundingFactorPerSecond,
            maxAllowedFundingIncreaseFactorPerSecond,
            maxAllowedFundingDecreaseFactorPerSecond
        );

        dataStore.setBytes32(Keys.dataStreamIdKey(token), feedId);
        dataStore.setUint(Keys.dataStreamMultiplierKey(token), dataStreamMultiplier);
        dataStore.setUint(Keys.dataStreamSpreadReductionFactorKey(token), dataStreamSpreadReductionFactor);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "token", token);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "feedId", feedId);
        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "dataStreamMultiplier", dataStreamMultiplier);
        eventData.uintItems.setItem(1, "dataStreamSpreadReductionFactor", dataStreamSpreadReductionFactor);
        eventEmitter.emitEventLog1(
            "ConfigSetDataStream",
            Cast.toBytes32(token),
            eventData
        );
    }

    function setClaimableCollateralFactorForTime(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 timeKey,
        uint256 factor
    ) external {
        if (factor > Precision.FLOAT_PRECISION) { revert Errors.InvalidClaimableFactor(factor); }

        bytes32 key = Keys.claimableCollateralFactorKey(market, token, timeKey);
        dataStore.setUint(key, factor);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "timeKey", timeKey);
        eventData.uintItems.setItem(1, "factor", factor);

        eventEmitter.emitEventLog2(
            "SetClaimableCollateralFactorForTime",
            Cast.toBytes32(market),
            Cast.toBytes32(token),
            eventData
        );
    }

    function setClaimableCollateralFactorForAccount(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 timeKey,
        address account,
        uint256 factor
    ) external {
        if (factor > Precision.FLOAT_PRECISION) { revert Errors.InvalidClaimableFactor(factor); }

        bytes32 key = Keys.claimableCollateralFactorKey(market, token, timeKey, account);
        dataStore.setUint(key, factor);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);
        eventData.addressItems.setItem(2, "account", account);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "timeKey", timeKey);
        eventData.uintItems.setItem(1, "factor", factor);

        eventEmitter.emitEventLog2(
            "SetClaimableCollateralFactorForAccount",
            Cast.toBytes32(market),
            Cast.toBytes32(token),
            eventData
        );
    }

    function setClaimableCollateralReductionFactorForAccount(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 timeKey,
        address account,
        uint256 factor
    ) external {
        if (factor > Precision.FLOAT_PRECISION) { revert Errors.InvalidClaimableReductionFactor(factor); }

        bytes32 key = Keys.claimableCollateralReductionFactorKey(market, token, timeKey, account);
        dataStore.setUint(key, factor);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);
        eventData.addressItems.setItem(2, "account", account);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "timeKey", timeKey);
        eventData.uintItems.setItem(1, "factor", factor);

        eventEmitter.emitEventLog2(
            "SetClaimableCollateralReductionFactorForAccount",
            Cast.toBytes32(market),
            Cast.toBytes32(token),
            eventData
        );
    }

    function setPositionImpactDistributionRate(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        uint256 minPositionImpactPoolAmount,
        uint256 positionImpactPoolDistributionRate,
        uint256 minPositionImpactPoolDistributionTime
    ) external {
        MarketUtils.distributePositionImpactPool(dataStore, eventEmitter, market);

        // Ensure the full positionImpactPoolAmount cannot be distributed in less then the minimum required time
        uint256 positionImpactPoolAmount = MarketUtils.getPositionImpactPoolAmount(dataStore, market);
        // positionImpactPoolDistributionRate has FLOAT_PRECISION, distributionAmount has WEI_PRECISION
        uint256 distributionAmount = Precision.applyFactor(minPositionImpactPoolDistributionTime, positionImpactPoolDistributionRate);
        if (positionImpactPoolAmount > 0) {
            if (distributionAmount >= positionImpactPoolAmount) {
                revert Errors.InvalidPositionImpactPoolDistributionRate(distributionAmount, positionImpactPoolAmount);
            }
        }

        dataStore.setUint(Keys.minPositionImpactPoolAmountKey(market), minPositionImpactPoolAmount);
        dataStore.setUint(Keys.positionImpactPoolDistributionRateKey(market), positionImpactPoolDistributionRate);

        dataStore.setUint(Keys.positionImpactPoolDistributedAtKey(market), Chain.currentTimestamp());

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "minPositionImpactPoolAmount", minPositionImpactPoolAmount);
        eventData.uintItems.setItem(1, "positionImpactPoolDistributionRate", positionImpactPoolDistributionRate);

        eventEmitter.emitEventLog1(
            "SetPositionImpactPoolDistributionRate",
            Cast.toBytes32(market),
            eventData
        );
    }

    // @dev validate that the value is within the allowed range
    // @param baseKey the base key for the value
    // @param value the value to be set
    function validateRange(
        DataStore dataStore,
        bytes32 baseKey,
        bytes memory data,
        uint256 value,
        uint256 maxAllowedMaxFundingFactorPerSecond,
        uint256 maxAllowedFundingIncreaseFactorPerSecond,
        uint256 maxAllowedFundingDecreaseFactorPerSecond
    ) public view {
        if (
            baseKey == Keys.SEQUENCER_GRACE_DURATION
        ) {
            // 2 hours
            if (value > 7200) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.MAX_FUNDING_FACTOR_PER_SECOND
        ) {
            if (value > maxAllowedMaxFundingFactorPerSecond) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }

            bytes32 minFundingFactorPerSecondKey = Keys.getFullKey(Keys.MIN_FUNDING_FACTOR_PER_SECOND, data);
            uint256 minFundingFactorPerSecond = dataStore.getUint(minFundingFactorPerSecondKey);
            if (value < minFundingFactorPerSecond) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.MIN_FUNDING_FACTOR_PER_SECOND
        ) {
            bytes32 maxFundingFactorPerSecondKey = Keys.getFullKey(Keys.MAX_FUNDING_FACTOR_PER_SECOND, data);
            uint256 maxFundingFactorPerSecond = dataStore.getUint(maxFundingFactorPerSecondKey);
            if (value > maxFundingFactorPerSecond) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.FUNDING_INCREASE_FACTOR_PER_SECOND
        ) {
            if (value > maxAllowedFundingIncreaseFactorPerSecond) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.FUNDING_DECREASE_FACTOR_PER_SECOND
        ) {
            if (value > maxAllowedFundingDecreaseFactorPerSecond) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.BORROWING_FACTOR ||
            baseKey == Keys.BASE_BORROWING_FACTOR
        ) {
            // 0.000005% per second, ~157% per year at 100% utilization
            if (value > 50000000000000000000000) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (baseKey == Keys.ABOVE_OPTIMAL_USAGE_BORROWING_FACTOR) {
            // 0.00001% per second, ~315% per year at 100% utilization
            if (value > 100000000000000000000000) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.FUNDING_EXPONENT_FACTOR ||
            baseKey == Keys.BORROWING_EXPONENT_FACTOR
        ) {
            // revert if value > 2
            if (value > 2 * Precision.FLOAT_PRECISION) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.POSITION_IMPACT_EXPONENT_FACTOR ||
            baseKey == Keys.SWAP_IMPACT_EXPONENT_FACTOR
        ) {
            // revert if value > 3
            if (value > 3 * Precision.FLOAT_PRECISION) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.FUNDING_FACTOR ||
            baseKey == Keys.BORROWING_FACTOR ||
            baseKey == Keys.FUNDING_INCREASE_FACTOR_PER_SECOND ||
            baseKey == Keys.FUNDING_DECREASE_FACTOR_PER_SECOND ||
            baseKey == Keys.MIN_COLLATERAL_FACTOR
        ) {
            // revert if value > 1%
            if (value > 1 * Precision.FLOAT_PRECISION / 100) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.SWAP_FEE_FACTOR ||
            baseKey == Keys.DEPOSIT_FEE_FACTOR ||
            baseKey == Keys.WITHDRAWAL_FEE_FACTOR ||
            baseKey == Keys.POSITION_FEE_FACTOR ||
            baseKey == Keys.MAX_UI_FEE_FACTOR ||
            baseKey == Keys.ATOMIC_SWAP_FEE_FACTOR ||
            baseKey == Keys.BUYBACK_MAX_PRICE_IMPACT_FACTOR
        ) {
            // revert if value > 5%
            if (value > 5 * Precision.FLOAT_PRECISION / 100) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (baseKey == Keys.LIQUIDATION_FEE_FACTOR) {
            // revert if value > 1%
            if (value > Precision.FLOAT_PRECISION / 100) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (baseKey == Keys.MIN_COLLATERAL_USD) {
            // revert if value > 10 USD
            if (value > 10 * Precision.FLOAT_PRECISION) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }

        if (
            baseKey == Keys.POSITION_FEE_RECEIVER_FACTOR ||
            baseKey == Keys.SWAP_FEE_RECEIVER_FACTOR ||
            baseKey == Keys.BORROWING_FEE_RECEIVER_FACTOR ||
            baseKey == Keys.LIQUIDATION_FEE_RECEIVER_FACTOR ||
            baseKey == Keys.MAX_PNL_FACTOR ||
            baseKey == Keys.MIN_PNL_FACTOR_AFTER_ADL ||
            baseKey == Keys.OPTIMAL_USAGE_FACTOR ||
            baseKey == Keys.PRO_DISCOUNT_FACTOR ||
            baseKey == Keys.BUYBACK_GMX_FACTOR ||
            baseKey == Keys.DATA_STREAM_SPREAD_REDUCTION_FACTOR
        ) {
            // revert if value > 100%
            if (value > Precision.FLOAT_PRECISION) {
                revert Errors.ConfigValueExceedsAllowedRange(baseKey, value);
            }
        }
    }
}
