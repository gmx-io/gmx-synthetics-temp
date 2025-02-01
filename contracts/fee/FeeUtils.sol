// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../data/Keys.sol";

import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";
import "../utils/Cast.sol";
import "../utils/AccountUtils.sol";
import "../market/MarketUtils.sol";

import "../market/MarketToken.sol";

import "../feature/FeatureUtils.sol";

// @title FeeUtils
// @dev Library for fee actions
library FeeUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    // @dev increment the claimable fee amount
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to increment claimable fees for
    // @param token the fee token
    // @param delta the amount to increment
    // @param feeType the type of the fee
    function incrementClaimableFeeAmount(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 delta,
        bytes32 feeType
    ) external {
        if (delta == 0) {
            return;
        }

        bytes32 key = Keys.claimableFeeAmountKey(market, token);

        uint256 nextValue = dataStore.incrementUint(
            key,
            delta
        );

        emitClaimableFeeAmountUpdated(
            eventEmitter,
            market,
            token,
            delta,
            nextValue,
            feeType
        );
    }

    function incrementClaimableUiFeeAmount(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address uiFeeReceiver,
        address market,
        address token,
        uint256 delta,
        bytes32 feeType
    ) external {
        if (delta == 0) {
            return;
        }

        uint256 nextValue = dataStore.incrementUint(
            Keys.claimableUiFeeAmountKey(market, token, uiFeeReceiver),
            delta
        );

        uint256 nextPoolValue = dataStore.incrementUint(
            Keys.claimableUiFeeAmountKey(market, token),
            delta
        );

        emitClaimableUiFeeAmountUpdated(
            eventEmitter,
            uiFeeReceiver,
            market,
            token,
            delta,
            nextValue,
            nextPoolValue,
            feeType
        );
    }

    function batchClaimFundingFees(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address[] memory markets,
        address[] memory tokens,
        address receiver,
        address account
    ) external returns (uint256[] memory) {
        if (markets.length != tokens.length) {
            revert Errors.InvalidClaimFundingFeesInput(markets.length, tokens.length);
        }

        FeatureUtils.validateFeature(dataStore, Keys.claimFundingFeesFeatureDisabledKey(address(this)));

        AccountUtils.validateReceiver(receiver);

        uint256[] memory claimedAmounts = new uint256[](markets.length);

        for (uint256 i; i < markets.length; i++) {
            claimedAmounts[i] = MarketUtils.claimFundingFees(
                dataStore,
                eventEmitter,
                markets[i],
                tokens[i],
                account,
                receiver
            );
        }

        return claimedAmounts;
    }

    // @dev claim fees for the specified market
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to claim fees for
    // @param token the fee token
    // @param receiver the receiver of the claimed fees
    function claimFees(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        address receiver
    ) internal returns (uint256) {
        AccountUtils.validateReceiver(receiver);

        bytes32 key = Keys.claimableFeeAmountKey(market, token);

        uint256 feeAmount = dataStore.getUint(key);
        dataStore.setUint(key, 0);

        MarketToken(payable(market)).transferOut(
            token,
            receiver,
            feeAmount
        );

        MarketUtils.validateMarketTokenBalance(dataStore, market);

        emitFeesClaimed(
            eventEmitter,
            market,
            receiver,
            feeAmount
        );

        return feeAmount;
    }

    function batchClaimUiFees(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address[] memory markets,
        address[] memory tokens,
        address receiver,
        address uiFeeReceiver
    ) external returns (uint256[] memory) {
        if (markets.length != tokens.length) {
            revert Errors.InvalidClaimUiFeesInput(markets.length, tokens.length);
        }

        FeatureUtils.validateFeature(dataStore, Keys.claimUiFeesFeatureDisabledKey(address(this)));

        uint256[] memory claimedAmounts = new uint256[](markets.length);

        for (uint256 i; i < markets.length; i++) {
            claimedAmounts[i] = claimUiFees(
                dataStore,
                eventEmitter,
                uiFeeReceiver,
                markets[i],
                tokens[i],
                receiver
            );
        }

        return claimedAmounts;
    }

    function claimUiFees(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address uiFeeReceiver,
        address market,
        address token,
        address receiver
    ) internal returns (uint256) {
        AccountUtils.validateReceiver(receiver);

        bytes32 key = Keys.claimableUiFeeAmountKey(market, token, uiFeeReceiver);

        uint256 feeAmount = dataStore.getUint(key);
        dataStore.setUint(key, 0);

        uint256 nextPoolValue = dataStore.decrementUint(
            Keys.claimableUiFeeAmountKey(market, token),
            feeAmount
        );

        MarketToken(payable(market)).transferOut(
            token,
            receiver,
            feeAmount
        );

        MarketUtils.validateMarketTokenBalance(dataStore, market);

        emitUiFeesClaimed(
            eventEmitter,
            uiFeeReceiver,
            market,
            receiver,
            feeAmount,
            nextPoolValue
        );

        return feeAmount;
    }

    function emitClaimableFeeAmountUpdated(
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 delta,
        uint256 nextValue,
        bytes32 feeType
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "delta", delta);
        eventData.uintItems.setItem(1, "nextValue", nextValue);

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "feeType", feeType);

        eventEmitter.emitEventLog2(
            "ClaimableFeeAmountUpdated",
            Cast.toBytes32(market),
            feeType,
            eventData
        );
    }

    function emitClaimableUiFeeAmountUpdated(
        EventEmitter eventEmitter,
        address uiFeeReceiver,
        address market,
        address token,
        uint256 delta,
        uint256 nextValue,
        uint256 nextPoolValue,
        bytes32 feeType
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "uiFeeReceiver", uiFeeReceiver);
        eventData.addressItems.setItem(1, "market", market);
        eventData.addressItems.setItem(2, "token", token);

        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "delta", delta);
        eventData.uintItems.setItem(1, "nextValue", nextValue);
        eventData.uintItems.setItem(2, "nextPoolValue", nextPoolValue);

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "feeType", feeType);

        eventEmitter.emitEventLog2(
            "ClaimableUiFeeAmountUpdated",
            Cast.toBytes32(market),
            feeType,
            eventData
        );
    }

    function emitFeesClaimed(
        EventEmitter eventEmitter,
        address market,
        address receiver,
        uint256 feeAmount
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "receiver", receiver);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "feeAmount", feeAmount);

        eventEmitter.emitEventLog1(
            "FeesClaimed",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitUiFeesClaimed(
        EventEmitter eventEmitter,
        address uiFeeReceiver,
        address market,
        address receiver,
        uint256 feeAmount,
        uint256 nextPoolValue
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "uiFeeReceiver", uiFeeReceiver);
        eventData.addressItems.setItem(1, "market", market);
        eventData.addressItems.setItem(2, "receiver", receiver);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "feeAmount", feeAmount);
        eventData.uintItems.setItem(1, "nextPoolValue", nextPoolValue);

        eventEmitter.emitEventLog1(
            "UiFeesClaimed",
            Cast.toBytes32(market),
            eventData
        );
    }
}
