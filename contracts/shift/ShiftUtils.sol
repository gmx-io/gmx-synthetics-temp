// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";

import "./ShiftVault.sol";
import "./ShiftStoreUtils.sol";
import "./ShiftEventUtils.sol";

import "../nonce/NonceUtils.sol";

import "../gas/GasUtils.sol";
import "../callback/CallbackUtils.sol";
import "../utils/AccountUtils.sol";

import "../deposit/ExecuteDepositUtils.sol";
import "../withdrawal/ExecuteWithdrawalUtils.sol";

library ShiftUtils {
    using Deposit for Deposit.Props;
    using Withdrawal for Withdrawal.Props;
    using Shift for Shift.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    struct CreateShiftParams {
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address fromMarket;
        address toMarket;
        uint256 minMarketTokens;
        uint256 executionFee;
        uint256 callbackGasLimit;
        bytes32[] dataList;
    }

    struct CreateShiftCache {
        uint256 estimatedGasLimit;
        uint256 oraclePriceCount;
        bytes32 key;
    }

    struct ExecuteShiftParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        ShiftVault shiftVault;
        Oracle oracle;
        bytes32 key;
        address keeper;
        uint256 startingGas;
    }

    struct ExecuteShiftCache {
        Withdrawal.Props withdrawal;
        bytes32 withdrawalKey;
        ExecuteWithdrawalUtils.ExecuteWithdrawalParams executeWithdrawalParams;
        Market.Props depositMarket;
        uint256 initialLongTokenAmount;
        uint256 initialShortTokenAmount;
        Deposit.Props deposit;
        bytes32 depositKey;
        ExecuteDepositUtils.ExecuteDepositParams executeDepositParams;
        uint256 receivedMarketTokens;
    }

    function createShift(
        DataStore dataStore,
        EventEmitter eventEmitter,
        ShiftVault shiftVault,
        address account,
        CreateShiftParams memory params
    ) external returns (bytes32) {
        AccountUtils.validateAccount(account);

        if (params.fromMarket == params.toMarket) {
            revert Errors.ShiftFromAndToMarketAreEqual(params.fromMarket);
        }

        address wnt = TokenUtils.wnt(dataStore);
        uint256 wntAmount = shiftVault.recordTransferIn(wnt);

        if (wntAmount < params.executionFee) {
            revert Errors.InsufficientWntAmountForExecutionFee(wntAmount, params.executionFee);
        }

        AccountUtils.validateReceiver(params.receiver);

        uint256 marketTokenAmount = shiftVault.recordTransferIn(params.fromMarket);

        if (marketTokenAmount == 0) {
            revert Errors.EmptyShiftAmount();
        }

        params.executionFee = wntAmount;

        Market.Props memory fromMarket = MarketUtils.getEnabledMarket(dataStore, params.fromMarket);
        Market.Props memory toMarket = MarketUtils.getEnabledMarket(dataStore, params.toMarket);

        if (fromMarket.longToken != toMarket.longToken) {
            revert Errors.LongTokensAreNotEqual(fromMarket.longToken, toMarket.longToken);
        }

        if (fromMarket.shortToken != toMarket.shortToken) {
            revert Errors.ShortTokensAreNotEqual(fromMarket.shortToken, toMarket.shortToken);
        }

        Shift.Props memory shift = Shift.Props(
            Shift.Addresses(
                account,
                params.receiver,
                params.callbackContract,
                params.uiFeeReceiver,
                params.fromMarket,
                params.toMarket
            ),
            Shift.Numbers(
                marketTokenAmount,
                params.minMarketTokens,
                Chain.currentTimestamp(),
                params.executionFee,
                params.callbackGasLimit
            ),
            params.dataList
        );

        CallbackUtils.validateCallbackGasLimit(dataStore, shift.callbackGasLimit());

        CreateShiftCache memory cache;

        cache.estimatedGasLimit = GasUtils.estimateExecuteShiftGasLimit(dataStore, shift);
        cache.oraclePriceCount = GasUtils.estimateShiftOraclePriceCount();
        GasUtils.validateExecutionFee(dataStore, cache.estimatedGasLimit, params.executionFee, cache.oraclePriceCount);

        cache.key = NonceUtils.getNextKey(dataStore);

        ShiftStoreUtils.set(dataStore, cache.key, shift);

        ShiftEventUtils.emitShiftCreated(eventEmitter, cache.key, shift);

        return cache.key;
    }

    function executeShift(
        ExecuteShiftParams memory params,
        Shift.Props memory shift
    ) external returns (uint256) {
        // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
        params.startingGas -= gasleft() / 63;

        ShiftStoreUtils.remove(params.dataStore, params.key, shift.account());

        if (shift.account() == address(0)) {
            revert Errors.EmptyShift();
        }

        if (shift.marketTokenAmount() == 0) {
            revert Errors.EmptyShiftAmount();
        }

        ExecuteShiftCache memory cache;

        cache.depositMarket = MarketStoreUtils.get(params.dataStore, shift.toMarket());

        // if a user sends tokens directly to the shiftVault
        // the recordTransferIn after the shift withdrawal would record
        // these additional tokens and perform a deposit on the combined
        // token amount (tokens directly sent + tokens withdrawn)
        //
        // a user could use this to avoid paying deposit fees
        //
        // call shiftVault.recordTransferIn before the withdrawal to prevent
        // this
        params.shiftVault.recordTransferIn(cache.depositMarket.longToken);
        params.shiftVault.recordTransferIn(cache.depositMarket.shortToken);

        cache.withdrawal = Withdrawal.Props(
            Withdrawal.Addresses(
                shift.account(),
                address(params.shiftVault), // receiver
                address(0), // callbackContract
                shift.uiFeeReceiver(), // uiFeeReceiver
                shift.fromMarket(), // market
                new address[](0), // longTokenSwapPath
                new address[](0) // shortTokenSwapPath
            ),
            Withdrawal.Numbers(
                shift.marketTokenAmount(),
                0, // minLongTokenAmount
                0, // minShortTokenAmount
                shift.updatedAtTime(),
                0, // executionFee
                0 // callbackGasLimit
            ),
            Withdrawal.Flags(
                false
            ),
            shift.dataList()
        );

        cache.withdrawalKey = NonceUtils.getNextKey(params.dataStore);
        params.dataStore.addBytes32(
            Keys.WITHDRAWAL_LIST,
            cache.withdrawalKey
        );
        WithdrawalEventUtils.emitWithdrawalCreated(
            params.eventEmitter,
            cache.withdrawalKey,
            cache.withdrawal,
            Withdrawal.WithdrawalType.Shift
        );

        cache.executeWithdrawalParams = ExecuteWithdrawalUtils.ExecuteWithdrawalParams(
            params.dataStore,
            params.eventEmitter,
            WithdrawalVault(payable(params.shiftVault)),
            params.oracle,
            cache.withdrawalKey,
            params.keeper,
            params.startingGas,
            ISwapPricingUtils.SwapPricingType.Shift
        );

        ExecuteWithdrawalUtils.executeWithdrawal(
            cache.executeWithdrawalParams,
            cache.withdrawal
        );

        // if the initialLongToken and initialShortToken are the same, only the initialLongTokenAmount would
        // be non-zero, the initialShortTokenAmount would be zero
        cache.initialLongTokenAmount = params.shiftVault.recordTransferIn(cache.depositMarket.longToken);
        cache.initialShortTokenAmount = params.shiftVault.recordTransferIn(cache.depositMarket.shortToken);

        // set the uiFeeReceiver to the zero address since the ui fee was already paid
        // while executing the withdrawal
        cache.deposit = Deposit.Props(
            Deposit.Addresses(
                shift.account(),
                shift.receiver(),
                address(0), // callbackContract
                address(0), // uiFeeReceiver
                shift.toMarket(), // market
                cache.depositMarket.longToken, // initialLongToken
                cache.depositMarket.shortToken, // initialShortToken
                new address[](0), // longTokenSwapPath
                new address[](0) // shortTokenSwapPath
            ),
            Deposit.Numbers(
                cache.initialLongTokenAmount,
                cache.initialShortTokenAmount,
                shift.minMarketTokens(),
                shift.updatedAtTime(),
                0, // executionFee
                0, // callbackGasLimit
                0 // chainId // TODO: change to shift.chainId
            ),
            Deposit.Flags(
                false // shouldUnwrapNativeToken
            ),
            shift.dataList()
        );

        cache.depositKey = NonceUtils.getNextKey(params.dataStore);
        params.dataStore.addBytes32(
            Keys.DEPOSIT_LIST,
            cache.depositKey
        );
        DepositEventUtils.emitDepositCreated(params.eventEmitter, cache.depositKey, cache.deposit, Deposit.DepositType.Shift);

        // price impact from changes in virtual inventory should be excluded
        // since the action of withdrawing and depositing should not result in
        // a net change of virtual inventory
        cache.executeDepositParams = ExecuteDepositUtils.ExecuteDepositParams(
            params.dataStore,
            params.eventEmitter,
            DepositVault(payable(params.shiftVault)),
            params.oracle,
            cache.depositKey,
            params.keeper,
            params.startingGas,
            ISwapPricingUtils.SwapPricingType.Shift,
            false // includeVirtualInventoryImpact
        );

        cache.receivedMarketTokens = ExecuteDepositUtils.executeDeposit(
            cache.executeDepositParams,
            cache.deposit
        );

        ShiftEventUtils.emitShiftExecuted(
            params.eventEmitter,
            params.key,
            shift.account(),
            cache.receivedMarketTokens
        );

        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "receivedMarketTokens", cache.receivedMarketTokens);
        CallbackUtils.afterShiftExecution(params.key, shift, eventData);

        GasUtils.payExecutionFee(
            params.dataStore,
            params.eventEmitter,
            params.shiftVault,
            params.key,
            shift.callbackContract(),
            shift.executionFee(),
            params.startingGas,
            GasUtils.estimateShiftOraclePriceCount(),
            params.keeper,
            shift.receiver()
        );

        return cache.receivedMarketTokens;
    }

    function cancelShift(
        DataStore dataStore,
        EventEmitter eventEmitter,
        ShiftVault shiftVault,
        bytes32 key,
        address keeper,
        uint256 startingGas,
        string memory reason,
        bytes memory reasonBytes
    ) external {
        // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
        startingGas -= gasleft() / 63;

        Shift.Props memory shift = ShiftStoreUtils.get(dataStore, key);

        if (shift.account() == address(0)) {
            revert Errors.EmptyShift();
        }

        if (shift.marketTokenAmount() == 0) {
            revert Errors.EmptyShiftAmount();
        }

        ShiftStoreUtils.remove(dataStore, key, shift.account());

        shiftVault.transferOut(
            shift.fromMarket(),
            shift.account(),
            shift.marketTokenAmount(),
            false // shouldUnwrapNativeToken
        );

        ShiftEventUtils.emitShiftCancelled(
            eventEmitter,
            key,
            shift.account(),
            reason,
            reasonBytes
        );

        EventUtils.EventLogData memory eventData;
        CallbackUtils.afterShiftCancellation(key, shift, eventData);

        GasUtils.payExecutionFee(
            dataStore,
            eventEmitter,
            shiftVault,
            key,
            shift.callbackContract(),
            shift.executionFee(),
            startingGas,
            GasUtils.estimateShiftOraclePriceCount(),
            keeper,
            shift.receiver()
        );
    }
}
