// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../exchange/IDepositHandler.sol";
import "../exchange/IWithdrawalHandler.sol";
import "../exchange/IShiftHandler.sol";
import "../exchange/IOrderHandler.sol";
import "../external/IExternalHandler.sol";
import "../shift/ShiftUtils.sol";
import "../shift/ShiftStoreUtils.sol";
import "../referral/ReferralUtils.sol";

import "../order/OrderStoreUtils.sol";

import "./BaseRouter.sol";
import "./IExchangeRouter.sol";

/**
 * @title ExchangeRouter
 * @dev Router for exchange functions, supports functions which require
 * token transfers from the user
 *
 * IMPORTANT: PayableMulticall uses delegatecall, msg.value will be the same for each delegatecall
 * extra care should be taken when using msg.value in any of the functions in this contract
 *
 * To avoid front-running issues, most actions require two steps to execute:
 *
 * - User sends transaction with request details, e.g. deposit / withdraw liquidity,
 * swap, increase / decrease position
 * - Keepers listen for the transactions, include the prices for the request then
 * send a transaction to execute the request
 *
 * Prices are provided by an off-chain oracle system:
 *
 * - Oracle keepers continually check the latest blocks
 * - When there is a new block, oracle keepers fetch the latest prices from
 * reference exchanges
 * - Oracle keepers then sign the median price for each token together with
 * the block hash
 * - Oracle keepers then send the data and signature to archive nodes
 * - Archive nodes display this information for anyone to query
 *
 * Example:
 *
 * - Block 100 is finalized on the blockchain
 * - Oracle keepers observe this block
 * - Oracle keepers pull the latest prices from reference exchanges,
 * token A: price 20,000, token B: price 80,000
 * - Oracle keepers sign [chainId, blockhash(100), 20,000], [chainId, blockhash(100), 80,000]
 * - If in block 100, there was a market order to open a long position for token A,
 * the market order would have a block number of 100
 * - The prices signed at block 100 can be used to execute this order
 * - Order keepers would bundle the signature and price data for token A
 * then execute the order
 */
contract ExchangeRouter is IExchangeRouter, BaseRouter {
    using Deposit for Deposit.Props;
    using Withdrawal for Withdrawal.Props;
    using Order for Order.Props;
    using Shift for Shift.Props;

    IDepositHandler public immutable depositHandler;
    IWithdrawalHandler public immutable withdrawalHandler;
    IShiftHandler public immutable shiftHandler;
    IOrderHandler public immutable orderHandler;
    IExternalHandler public immutable externalHandler;

    // @dev Constructor that initializes the contract with the provided Router, RoleStore, DataStore,
    // EventEmitter, IDepositHandler, IWithdrawalHandler, IOrderHandler, and OrderStore instances
    constructor(
        Router _router,
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        IDepositHandler _depositHandler,
        IWithdrawalHandler _withdrawalHandler,
        IShiftHandler _shiftHandler,
        IOrderHandler _orderHandler,
        IExternalHandler _externalHandler
    ) BaseRouter(_router, _roleStore, _dataStore, _eventEmitter) {
        depositHandler = _depositHandler;
        withdrawalHandler = _withdrawalHandler;
        shiftHandler = _shiftHandler;
        orderHandler = _orderHandler;
        externalHandler = _externalHandler;
    }

    // makeExternalCalls can be used to perform an external swap before
    // an action
    // example:
    // - ExchangeRouter.sendTokens(token: WETH, receiver: externalHandler, amount: 1e18)
    // - ExchangeRouter.makeExternalCalls(
    //     WETH.approve(spender: aggregator, amount: 1e18),
    //     aggregator.swap(amount: 1, from: WETH, to: USDC, receiver: orderHandler)
    // )
    // - ExchangeRouter.createOrder
    // the msg.sender for makeExternalCalls would be externalHandler
    // refundTokens can be used to retrieve any excess tokens that may
    // be left in the externalHandler
    function makeExternalCalls(
        address[] memory externalCallTargets,
        bytes[] memory externalCallDataList,
        address[] memory refundTokens,
        address[] memory refundReceivers
    ) external payable nonReentrant {
        externalHandler.makeExternalCalls(
            externalCallTargets,
            externalCallDataList,
            refundTokens,
            refundReceivers
        );
    }

    /**
     * @dev Creates a new deposit with the given long token, short token, long token amount, short token
     * amount, and deposit parameters. The deposit is created by transferring the specified amounts of
     * long and short tokens from the caller's account to the deposit store, and then calling the
     * `createDeposit()` function on the deposit handler contract.
     *
     * @param params The deposit parameters, as specified in the `DepositUtils.CreateDepositParams` struct
     * @return The unique ID of the newly created deposit
     */
    function createDeposit(
        DepositUtils.CreateDepositParams calldata params
    ) external override payable nonReentrant returns (bytes32) {
        address account = msg.sender;

        return depositHandler.createDeposit(
            account,
            params
        );
    }

    function cancelDeposit(bytes32 key) external override payable nonReentrant {
        Deposit.Props memory deposit = DepositStoreUtils.get(dataStore, key);
        if (deposit.account() == address(0)) {
            revert Errors.EmptyDeposit();
        }

        if (deposit.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for cancelDeposit");
        }

        depositHandler.cancelDeposit(key);
    }

    function simulateExecuteDeposit(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        depositHandler.simulateExecuteDeposit(key, simulatedOracleParams);
    }

    function simulateExecuteLatestDeposit(
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        bytes32 key = NonceUtils.getCurrentKey(dataStore);
        depositHandler.simulateExecuteDeposit(key, simulatedOracleParams);
    }

    function createWithdrawal(
        WithdrawalUtils.CreateWithdrawalParams calldata params
    ) external override payable nonReentrant returns (bytes32) {
        address account = msg.sender;

        return withdrawalHandler.createWithdrawal(
            account,
            params
        );
    }

    function cancelWithdrawal(bytes32 key) external override payable nonReentrant {
        Withdrawal.Props memory withdrawal = WithdrawalStoreUtils.get(dataStore, key);
        if (withdrawal.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for cancelWithdrawal");
        }

        withdrawalHandler.cancelWithdrawal(key);
    }

    function executeAtomicWithdrawal(
        WithdrawalUtils.CreateWithdrawalParams calldata params,
        OracleUtils.SetPricesParams calldata oracleParams
    ) external override payable nonReentrant {
        address account = msg.sender;

        return withdrawalHandler.executeAtomicWithdrawal(
            account,
            params,
            oracleParams
        );
    }

    function simulateExecuteWithdrawal(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory simulatedOracleParams,
        ISwapPricingUtils.SwapPricingType swapPricingType
    ) external payable nonReentrant {
        withdrawalHandler.simulateExecuteWithdrawal(key, simulatedOracleParams, swapPricingType);
    }

    function simulateExecuteLatestWithdrawal(
        OracleUtils.SimulatePricesParams memory simulatedOracleParams,
        ISwapPricingUtils.SwapPricingType swapPricingType
    ) external payable nonReentrant {
        bytes32 key = NonceUtils.getCurrentKey(dataStore);
        withdrawalHandler.simulateExecuteWithdrawal(key, simulatedOracleParams, swapPricingType);
    }

    function createShift(
        ShiftUtils.CreateShiftParams calldata params
    ) external override payable nonReentrant returns (bytes32) {
        address account = msg.sender;

        return shiftHandler.createShift(
            account,
            params
        );
    }

    function cancelShift(bytes32 key) external override payable nonReentrant {
        Shift.Props memory shift = ShiftStoreUtils.get(dataStore, key);
        if (shift.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for cancelShift");
        }

        shiftHandler.cancelShift(key);
    }

    function simulateExecuteShift(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        shiftHandler.simulateExecuteShift(key, simulatedOracleParams);
    }

    function simulateExecuteLatestShift(
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        bytes32 key = NonceUtils.getCurrentKey(dataStore);
        shiftHandler.simulateExecuteShift(key, simulatedOracleParams);
    }

    /**
     * @dev Creates a new order with the given amount, order parameters. The order is
     * created by transferring the specified amount of collateral tokens from the caller's account to the
     * order store, and then calling the `createOrder()` function on the order handler contract. The
     * referral code is also set on the caller's account using the referral storage contract.
     */
    function createOrder(
        IBaseOrderUtils.CreateOrderParams calldata params
    ) external override payable nonReentrant returns (bytes32) {
        address account = msg.sender;

        return orderHandler.createOrder(
            account,
            params
        );
    }

    function setSavedCallbackContract(
        address market,
        address callbackContract
    ) external payable nonReentrant {
        // save the callback contract based on the account and market so that
        // it can be called on liquidations and ADLs
        CallbackUtils.setSavedCallbackContract(
            dataStore,
            msg.sender, // account
            market,
            callbackContract
        );
    }

    /**
     * @dev Updates the given order with the specified size delta, acceptable price, and trigger price.
     * The `updateOrder()` feature must be enabled for the given order type. The caller must be the owner
     * of the order, and the order must not be a market order. The size delta, trigger price, and
     * acceptable price are updated on the order, and the order is unfrozen. Any additional WNT that is
     * transferred to the contract is added to the order's execution fee. The updated order is then saved
     * in the order store, and an `OrderUpdated` event is emitted.
     *
     * @param key The unique ID of the order to be updated
     * @param sizeDeltaUsd The new size delta for the order
     * @param acceptablePrice The new acceptable price for the order
     * @param triggerPrice The new trigger price for the order
     */
    function updateOrder(
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice,
        uint256 minOutputAmount,
        uint256 validFromTime,
        bool autoCancel
    ) external payable nonReentrant {
        Order.Props memory order = OrderStoreUtils.get(dataStore, key);
        if (order.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for updateOrder");
        }

        orderHandler.updateOrder(
            key,
            sizeDeltaUsd,
            acceptablePrice,
            triggerPrice,
            minOutputAmount,
            validFromTime,
            autoCancel,
            order
        );
    }

    /**
     * @dev Cancels the given order. The `cancelOrder()` feature must be enabled for the given order
     * type. The caller must be the owner of the order, and the order must not be a market order. The
     * order is cancelled by calling the `cancelOrder()` function in the `OrderUtils` contract. This
     * function also records the starting gas amount and the reason for cancellation, which is passed to
     * the `cancelOrder()` function.
     *
     * @param key The unique ID of the order to be cancelled
     */
    function cancelOrder(bytes32 key) external payable nonReentrant {
        Order.Props memory order = OrderStoreUtils.get(dataStore, key);
        if (order.account() == address(0)) {
            revert Errors.EmptyOrder();
        }

        if (order.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for cancelOrder");
        }

        orderHandler.cancelOrder(key);
    }

    function simulateExecuteOrder(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        orderHandler.simulateExecuteOrder(key, simulatedOracleParams);
    }

    function simulateExecuteLatestOrder(
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        bytes32 key = NonceUtils.getCurrentKey(dataStore);
        orderHandler.simulateExecuteOrder(key, simulatedOracleParams);
    }

    /**
     * @dev Claims funding fees for the given markets and tokens on behalf of the caller, and sends the
     * fees to the specified receiver. The length of the `markets` and `tokens` arrays must be the same.
     * For each market-token pair, the `claimFundingFees()` function in the `MarketUtils` contract is
     * called to claim the fees for the caller.
     *
     * @param markets An array of market addresses
     * @param tokens An array of token addresses, corresponding to the given markets
     * @param receiver The address to which the claimed fees should be sent
     */
    function claimFundingFees(
        address[] memory markets,
        address[] memory tokens,
        address receiver
    ) external payable nonReentrant returns (uint256[] memory) {
        address account = msg.sender;
        return FeeUtils.batchClaimFundingFees(dataStore, eventEmitter, markets, tokens, receiver, account);
    }

    function claimCollateral(
        address[] memory markets,
        address[] memory tokens,
        uint256[] memory timeKeys,
        address receiver
    ) external payable nonReentrant returns (uint256[] memory) {
        address account = msg.sender;
        return MarketUtils.batchClaimCollateral(dataStore, eventEmitter, markets, tokens, timeKeys, receiver, account);
    }

    /**
     * @dev Claims affiliate rewards for the given markets and tokens on behalf of the caller, and sends
     * the rewards to the specified receiver. The length of the `markets` and `tokens` arrays must be
     * the same. For each market-token pair, the `claimAffiliateReward()` function in the `ReferralUtils`
     * contract is called to claim the rewards for the caller.
     *
     * @param markets An array of market addresses
     * @param tokens An array of token addresses, corresponding to the given markets
     * @param receiver The address to which the claimed rewards should be sent
     */
    function claimAffiliateRewards(
        address[] memory markets,
        address[] memory tokens,
        address receiver
    ) external payable nonReentrant returns (uint256[] memory) {
        address account = msg.sender;
        return ReferralUtils.batchClaimAffiliateRewards(
            dataStore, eventEmitter, markets, tokens, receiver, account
        );
    }

    function setUiFeeFactor(uint256 uiFeeFactor) external payable nonReentrant {
        address account = msg.sender;
        MarketUtils.setUiFeeFactor(dataStore, eventEmitter, account, uiFeeFactor);
    }

    function claimUiFees(
        address[] memory markets,
        address[] memory tokens,
        address receiver
    ) external payable nonReentrant returns (uint256[] memory) {
        address uiFeeReceiver = msg.sender;
        return FeeUtils.batchClaimUiFees(dataStore, eventEmitter, markets, tokens, receiver, uiFeeReceiver);
    }
}
