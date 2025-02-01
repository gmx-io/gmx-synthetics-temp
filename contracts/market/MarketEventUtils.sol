// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";
import "../utils/Cast.sol";

import "./MarketPoolValueInfo.sol";

library MarketEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    // this event is emitted before a deposit or withdrawal
    // it provides information of the pool state so that the amount
    // of market tokens minted or amount withdrawn from the pool can be checked
    function emitMarketPoolValueInfo(
        EventEmitter eventEmitter,
        bytes32 tradeKey,
        address market,
        MarketPoolValueInfo.Props memory props,
        uint256 marketTokensSupply
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "tradeKey", tradeKey);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.intItems.initItems(4);
        eventData.intItems.setItem(0, "poolValue", props.poolValue);
        eventData.intItems.setItem(1, "longPnl", props.longPnl);
        eventData.intItems.setItem(2, "shortPnl", props.shortPnl);
        eventData.intItems.setItem(3, "netPnl", props.netPnl);

        eventData.uintItems.initItems(8);
        eventData.uintItems.setItem(0, "longTokenAmount", props.longTokenAmount);
        eventData.uintItems.setItem(1, "shortTokenAmount", props.shortTokenAmount);
        eventData.uintItems.setItem(2, "longTokenUsd", props.longTokenUsd);
        eventData.uintItems.setItem(3, "shortTokenUsd", props.shortTokenUsd);
        eventData.uintItems.setItem(4, "totalBorrowingFees", props.totalBorrowingFees);
        eventData.uintItems.setItem(5, "borrowingFeePoolFactor", props.borrowingFeePoolFactor);
        eventData.uintItems.setItem(6, "impactPoolAmount", props.impactPoolAmount);
        eventData.uintItems.setItem(7, "marketTokensSupply", marketTokensSupply);

        eventEmitter.emitEventLog1(
            "MarketPoolValueInfo",
            Cast.toBytes32(market),
            eventData
        );
    }

    // this event is emitted after a deposit or withdrawal
    // it provides information of the updated pool state
    // note that the pool state can change even without a deposit / withdrawal
    // e.g. borrowing fees can increase the pool's value with time, trader pnl
    // will change as index prices change
    function emitMarketPoolValueUpdated(
        EventEmitter eventEmitter,
        bytes32 actionType,
        bytes32 tradeKey,
        address market,
        MarketPoolValueInfo.Props memory props,
        uint256 marketTokensSupply
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(2);
        eventData.bytes32Items.setItem(0, "actionType", actionType);
        eventData.bytes32Items.setItem(1, "tradeKey", tradeKey);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.intItems.initItems(4);
        eventData.intItems.setItem(0, "poolValue", props.poolValue);
        eventData.intItems.setItem(1, "longPnl", props.longPnl);
        eventData.intItems.setItem(2, "shortPnl", props.shortPnl);
        eventData.intItems.setItem(3, "netPnl", props.netPnl);

        eventData.uintItems.initItems(8);
        eventData.uintItems.setItem(0, "longTokenAmount", props.longTokenAmount);
        eventData.uintItems.setItem(1, "shortTokenAmount", props.shortTokenAmount);
        eventData.uintItems.setItem(2, "longTokenUsd", props.longTokenUsd);
        eventData.uintItems.setItem(3, "shortTokenUsd", props.shortTokenUsd);
        eventData.uintItems.setItem(4, "totalBorrowingFees", props.totalBorrowingFees);
        eventData.uintItems.setItem(5, "borrowingFeePoolFactor", props.borrowingFeePoolFactor);
        eventData.uintItems.setItem(6, "impactPoolAmount", props.impactPoolAmount);
        eventData.uintItems.setItem(7, "marketTokensSupply", marketTokensSupply);

        eventEmitter.emitEventLog1(
            "MarketPoolValueUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitPoolAmountUpdated(
        EventEmitter eventEmitter,
        address market,
        address token,
        int256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "delta", delta);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "nextValue", nextValue);

        eventEmitter.emitEventLog1(
            "PoolAmountUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitSwapImpactPoolAmountUpdated(
        EventEmitter eventEmitter,
        address market,
        address token,
        int256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "delta", delta);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "nextValue", nextValue);

        eventEmitter.emitEventLog1(
            "SwapImpactPoolAmountUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitPositionImpactPoolDistributed(
        EventEmitter eventEmitter,
        address market,
        uint256 distributionAmount,
        uint256 nextPositionImpactPoolAmount
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "distributionAmount", distributionAmount);
        eventData.uintItems.setItem(1, "nextPositionImpactPoolAmount", nextPositionImpactPoolAmount);

        eventEmitter.emitEventLog1(
            "PositionImpactPoolDistributed",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitPositionImpactPoolAmountUpdated(
        EventEmitter eventEmitter,
        address market,
        int256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "delta", delta);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "nextValue", nextValue);

        eventEmitter.emitEventLog1(
            "PositionImpactPoolAmountUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitOpenInterestUpdated(
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        int256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "collateralToken", collateralToken);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLong", isLong);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "delta", delta);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "nextValue", nextValue);

        eventEmitter.emitEventLog1(
            "OpenInterestUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitVirtualSwapInventoryUpdated(
        EventEmitter eventEmitter,
        address market,
        bool isLongToken,
        bytes32 virtualMarketId,
        int256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLongToken", isLongToken);

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "virtualMarketId", virtualMarketId);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "delta", delta);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "nextValue", nextValue);

        eventEmitter.emitEventLog2(
            "VirtualSwapInventoryUpdated",
            Cast.toBytes32(market),
            virtualMarketId,
            eventData
        );
    }

    function emitVirtualPositionInventoryUpdated(
        EventEmitter eventEmitter,
        address token,
        bytes32 virtualTokenId,
        int256 delta,
        int256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "token", token);

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "virtualTokenId", virtualTokenId);

        eventData.intItems.initItems(2);
        eventData.intItems.setItem(0, "delta", delta);
        eventData.intItems.setItem(1, "nextValue", nextValue);

        eventEmitter.emitEventLog2(
            "VirtualPositionInventoryUpdated",
            Cast.toBytes32(token),
            virtualTokenId,
            eventData
        );
    }

    function emitOpenInterestInTokensUpdated(
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        int256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "collateralToken", collateralToken);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLong", isLong);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "delta", delta);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "nextValue", nextValue);

        eventEmitter.emitEventLog1(
            "OpenInterestInTokensUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitCollateralSumUpdated(
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        int256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "collateralToken", collateralToken);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLong", isLong);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "delta", delta);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "nextValue", nextValue);

        eventEmitter.emitEventLog1(
            "CollateralSumUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitBorrowing(
        EventEmitter eventEmitter,
        address market,
        uint256 borrowingFactorPerSecond
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "borrowingFactorPerSecond", borrowingFactorPerSecond);

        eventEmitter.emitEventLog1(
            "Borrowing",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitBorrowingFactorUpdated(
        EventEmitter eventEmitter,
        address market,
        bool isLong,
        uint256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLong", isLong);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "delta", delta);
        eventData.uintItems.setItem(1, "nextValue", nextValue);

        eventEmitter.emitEventLog1(
            "CumulativeBorrowingFactorUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitFunding(
        EventEmitter eventEmitter,
        address market,
        uint256 fundingFactorPerSecond
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "fundingFactorPerSecond", fundingFactorPerSecond);

        eventEmitter.emitEventLog1(
            "Funding",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitFundingFeeAmountPerSizeUpdated(
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        uint256 delta,
        uint256 value
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "collateralToken", collateralToken);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLong", isLong);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "delta", delta);
        eventData.uintItems.setItem(1, "value", value);

        eventEmitter.emitEventLog1(
            "FundingFeeAmountPerSizeUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitClaimableFundingAmountPerSizeUpdated(
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        uint256 delta,
        uint256 value
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "collateralToken", collateralToken);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLong", isLong);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "delta", delta);
        eventData.uintItems.setItem(1, "value", value);

        eventEmitter.emitEventLog1(
            "ClaimableFundingAmountPerSizeUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitClaimableFundingUpdated(
        EventEmitter eventEmitter,
        address market,
        address token,
        address account,
        uint256 delta,
        uint256 nextValue,
        uint256 nextPoolValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);
        eventData.addressItems.setItem(2, "account", account);

        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "delta", delta);
        eventData.uintItems.setItem(1, "nextValue", nextValue);
        eventData.uintItems.setItem(2, "nextPoolValue", nextPoolValue);

        eventEmitter.emitEventLog1(
            "ClaimableFundingUpdated",
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitFundingFeesClaimed(
        EventEmitter eventEmitter,
        address market,
        address token,
        address account,
        address receiver,
        uint256 amount,
        uint256 nextPoolValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(4);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);
        eventData.addressItems.setItem(2, "account", account);
        eventData.addressItems.setItem(3, "receiver", receiver);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "amount", amount);
        eventData.uintItems.setItem(1, "nextPoolValue", nextPoolValue);

        eventEmitter.emitEventLog1(
            "FundingFeesClaimed",
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitClaimableFundingUpdated(
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 timeKey,
        address account,
        uint256 delta,
        uint256 nextValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);
        eventData.addressItems.setItem(2, "account", account);

        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "timeKey", timeKey);
        eventData.uintItems.setItem(1, "delta", delta);
        eventData.uintItems.setItem(2, "nextValue", nextValue);

        eventEmitter.emitEventLog1(
            "ClaimableFundingUpdated",
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitClaimableCollateralUpdated(
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 timeKey,
        address account,
        uint256 delta,
        uint256 nextValue,
        uint256 nextPoolValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);
        eventData.addressItems.setItem(2, "account", account);

        eventData.uintItems.initItems(4);
        eventData.uintItems.setItem(0, "timeKey", timeKey);
        eventData.uintItems.setItem(1, "delta", delta);
        eventData.uintItems.setItem(2, "nextValue", nextValue);
        eventData.uintItems.setItem(3, "nextPoolValue", nextPoolValue);

        eventEmitter.emitEventLog1(
            "ClaimableCollateralUpdated",
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitCollateralClaimed(
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 timeKey,
        address account,
        address receiver,
        uint256 amount,
        uint256 nextPoolValue
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(4);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);
        eventData.addressItems.setItem(2, "account", account);
        eventData.addressItems.setItem(3, "receiver", receiver);

        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "timeKey", timeKey);
        eventData.uintItems.setItem(1, "amount", amount);
        eventData.uintItems.setItem(2, "nextPoolValue", nextPoolValue);

        eventEmitter.emitEventLog1(
            "CollateralClaimed",
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitUiFeeFactorUpdated(
        EventEmitter eventEmitter,
        address account,
        uint256 uiFeeFactor
    ) external {

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "uiFeeFactor", uiFeeFactor);

        eventEmitter.emitEventLog1(
            "UiFeeFactorUpdated",
            Cast.toBytes32(account),
            eventData
        );
    }
}
