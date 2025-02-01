// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./IGlpVault.sol";
import "./IGlpTimelock.sol";
import "./IGlpRewardRouter.sol";

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";

import "../deposit/DepositVault.sol";
import "../exchange/DepositHandler.sol";
import "../external/ExternalHandler.sol";

contract GlpMigrator is ReentrancyGuard, RoleModule {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    using SafeERC20 for IERC20;

    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;
    DepositVault public immutable depositVault;
    DepositHandler public immutable depositHandler;
    ExternalHandler public immutable externalHandler;

    IERC20 public immutable stakedGlp;
    IGlpVault public immutable glpVault;
    IGlpTimelock public immutable glpTimelock;
    IGlpRewardRouter public immutable glpRewardRouter;

    uint256 public reducedMintBurnFeeBasisPoints;

    struct GlpRedemption {
        address token;
        uint256 glpAmount;
        uint256 minOut;

        address receiver;
        address[] externalCallTargets;
        bytes[] externalCallDataList;
        address[] refundTokens;
        address[] refundReceivers;
    }

    struct MigrationItem {
        address market;

        GlpRedemption long;
        GlpRedemption short;

        uint256 minMarketTokens;
        uint256 executionFee;
    }

    struct MigrateCache {
        Market.Props market;
        uint256 redeemedLongTokenAmount;
        uint256 redeemedShortTokenAmount;
        bytes32 depositKey;
    }

    modifier withReducedRedemptionFees() {
        uint256 taxBasisPoints = glpVault.taxBasisPoints();
        uint256 stableTaxBasisPoints = glpVault.stableTaxBasisPoints();
        uint256 mintBurnFeeBasisPoints = glpVault.mintBurnFeeBasisPoints();
        uint256 swapFeeBasisPoints = glpVault.swapFeeBasisPoints();
        uint256 stableSwapFeeBasisPoints = glpVault.stableSwapFeeBasisPoints();
        uint256 _reducedMintBurnFeeBasisPoints = reducedMintBurnFeeBasisPoints;

        bool shouldUpdateFees = _reducedMintBurnFeeBasisPoints < mintBurnFeeBasisPoints;

        if (shouldUpdateFees) {
            glpTimelock.setSwapFees(
                address(glpVault),
                taxBasisPoints,
                stableTaxBasisPoints,
                _reducedMintBurnFeeBasisPoints,
                swapFeeBasisPoints,
                stableSwapFeeBasisPoints
            );
        }

        _;

        if (shouldUpdateFees) {
            glpTimelock.setSwapFees(
                address(glpVault),
                taxBasisPoints,
                stableTaxBasisPoints,
                mintBurnFeeBasisPoints,
                swapFeeBasisPoints,
                stableSwapFeeBasisPoints
            );
        }
    }

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        DepositVault _depositVault,
        DepositHandler _depositHandler,
        ExternalHandler _externalHandler,
        IERC20 _stakedGlp,
        IGlpVault _glpVault,
        IGlpTimelock _glpTimelock,
        IGlpRewardRouter _glpRewardRouter,
        uint256 _reducedMintBurnFeeBasisPoints
    ) RoleModule(_roleStore) {
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
        depositVault = _depositVault;
        depositHandler = _depositHandler;
        externalHandler = _externalHandler;

        stakedGlp = _stakedGlp;
        glpVault = _glpVault;
        glpTimelock = _glpTimelock;
        glpRewardRouter = _glpRewardRouter;

        reducedMintBurnFeeBasisPoints = _reducedMintBurnFeeBasisPoints;
    }

    function setReducedMintBurnFeeBasisPoints(uint256 _reducedMintBurnFeeBasisPoints) external onlyConfigKeeper {
        reducedMintBurnFeeBasisPoints = _reducedMintBurnFeeBasisPoints;

        EventUtils.EventLogData memory eventData;

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "reducedMintBurnFeeBasisPoints", _reducedMintBurnFeeBasisPoints);

        eventEmitter.emitEventLog(
            "SetReducedMintBurnFeeBasisPoints",
            eventData
        );
    }

    function migrate(
        uint256 totalGlpAmount,
        MigrationItem[] memory migrationItems
    ) external payable nonReentrant withReducedRedemptionFees {
        address account = msg.sender;
        stakedGlp.transferFrom(account, address(this), totalGlpAmount);

        uint256 totalGlpAmountToRedeem;
        uint256 totalExecutionFee;

        for (uint256 i = 0; i < migrationItems.length; i++) {
            MigrationItem memory migrationItem = migrationItems[i];
            totalGlpAmountToRedeem += migrationItem.long.glpAmount;
            totalGlpAmountToRedeem += migrationItem.short.glpAmount;

            totalExecutionFee += migrationItem.executionFee;
        }

        if (totalGlpAmountToRedeem != totalGlpAmount) {
            revert Errors.InvalidGlpAmount(totalGlpAmountToRedeem, totalGlpAmount);
        }

        if (msg.value != totalExecutionFee) {
            revert Errors.InvalidExecutionFeeForMigration(totalExecutionFee, msg.value);
        }

        for (uint256 i = 0; i < migrationItems.length; i++) {
            MigrationItem memory migrationItem = migrationItems[i];
            MigrateCache memory cache;

            cache.market = MarketUtils.getEnabledMarket(dataStore, migrationItem.market);

            cache.redeemedLongTokenAmount = _redeemGlp(migrationItem.long);
            cache.redeemedShortTokenAmount = _redeemGlp(migrationItem.short);

            TokenUtils.depositAndSendWrappedNativeToken(
                dataStore,
                address(depositVault),
                migrationItem.executionFee
            );

            // a user could set a minMarketTokens to force the deposit to fail
            // or set a market where the deposited amount would exceed the caps and
            // the deposit would fail
            // or use the externalHandler calls to set the receiver of tokens
            // directly to an account they own or control
            // glp should be adjusted such that only redemptions are allowed so
            // any arbitrage / benefit of doing this should be minimal
            // glp mint fees should also help to discourage this
            DepositUtils.CreateDepositParams memory depositParams =  DepositUtils.CreateDepositParams(
                account, // receiver;
                address(0), // callbackContract;
                address(0), // uiFeeReceiver;
                migrationItem.market, // market;
                cache.market.longToken, // initialLongToken;
                cache.market.shortToken, // initialShortToken;
                new address[](0), // longTokenSwapPath;
                new address[](0), // shortTokenSwapPath;
                migrationItem.minMarketTokens, // minMarketTokens;
                false, // shouldUnwrapNativeToken;
                migrationItem.executionFee, // executionFee;
                0, // callbackGasLimit;
                new bytes32[](0) // dataList;
            );

            cache.depositKey = depositHandler.createDeposit(
                account,
                depositParams
            );

            EventUtils.EventLogData memory eventData;

            eventData.bytes32Items.initItems(1);
            eventData.bytes32Items.setItem(0, "depositKey", cache.depositKey);

            eventData.addressItems.initItems(3);
            eventData.addressItems.setItem(0, "market", cache.market.marketToken);
            eventData.addressItems.setItem(1, "redeemedLongToken", migrationItem.long.token);
            eventData.addressItems.setItem(2, "redeemedShortToken", migrationItem.short.token);

            eventData.uintItems.initItems(4);
            eventData.uintItems.setItem(0, "glpLongAmount", migrationItem.long.glpAmount);
            eventData.uintItems.setItem(1, "glpShortAmount", migrationItem.short.glpAmount);
            eventData.uintItems.setItem(2, "redeemedLongTokenAmount", cache.redeemedLongTokenAmount);
            eventData.uintItems.setItem(3, "redeemedShortTokenAmount", cache.redeemedShortTokenAmount);

            eventEmitter.emitEventLog1(
                "GlpMigration",
                Cast.toBytes32(cache.market.marketToken),
                eventData
            );
        }
    }

    function _redeemGlp(
        GlpRedemption memory redemptionInfo
    ) internal returns (uint256) {
        if (redemptionInfo.glpAmount == 0) {
            return 0;
        }

        uint256 redeemedTokenAmount = glpRewardRouter.unstakeAndRedeemGlp(
            redemptionInfo.token, // tokenOut
            redemptionInfo.glpAmount, // glpAmount
            redemptionInfo.minOut, // minOut
            redemptionInfo.receiver // receiver
        );

        externalHandler.makeExternalCalls(
            redemptionInfo.externalCallTargets,
            redemptionInfo.externalCallDataList,
            redemptionInfo.refundTokens,
            redemptionInfo.refundReceivers
        );

        return redeemedTokenAmount;
    }
}
