// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

// @title Keys
// @dev Keys for values in the DataStore
library Keys {
    // @dev key for the address of the wrapped native token
    bytes32 public constant WNT = keccak256(abi.encode("WNT"));
    // @dev key for the nonce value used in NonceUtils
    bytes32 public constant NONCE = keccak256(abi.encode("NONCE"));

    // @dev for sending received fees
    bytes32 public constant FEE_RECEIVER = keccak256(abi.encode("FEE_RECEIVER"));

    // @dev for holding tokens that could not be sent out
    bytes32 public constant HOLDING_ADDRESS = keccak256(abi.encode("HOLDING_ADDRESS"));

    // @dev key for the minimum gas for execution error
    bytes32 public constant MIN_HANDLE_EXECUTION_ERROR_GAS = keccak256(abi.encode("MIN_HANDLE_EXECUTION_ERROR_GAS"));

    // @dev key for the minimum gas that should be forwarded for execution error handling
    bytes32 public constant MIN_HANDLE_EXECUTION_ERROR_GAS_TO_FORWARD = keccak256(abi.encode("MIN_HANDLE_EXECUTION_ERROR_GAS_TO_FORWARD"));

    // @dev key for the min additional gas for execution
    bytes32 public constant MIN_ADDITIONAL_GAS_FOR_EXECUTION = keccak256(abi.encode("MIN_ADDITIONAL_GAS_FOR_EXECUTION"));

    // @dev for a global reentrancy guard
    bytes32 public constant REENTRANCY_GUARD_STATUS = keccak256(abi.encode("REENTRANCY_GUARD_STATUS"));

    // @dev key for deposit fees
    bytes32 public constant DEPOSIT_FEE_TYPE = keccak256(abi.encode("DEPOSIT_FEE_TYPE"));
    // @dev key for withdrawal fees
    bytes32 public constant WITHDRAWAL_FEE_TYPE = keccak256(abi.encode("WITHDRAWAL_FEE_TYPE"));
    // @dev key for swap fees
    bytes32 public constant SWAP_FEE_TYPE = keccak256(abi.encode("SWAP_FEE_TYPE"));
    // @dev key for position fees
    bytes32 public constant POSITION_FEE_TYPE = keccak256(abi.encode("POSITION_FEE_TYPE"));
    // @dev key for ui deposit fees
    bytes32 public constant UI_DEPOSIT_FEE_TYPE = keccak256(abi.encode("UI_DEPOSIT_FEE_TYPE"));
    // @dev key for ui withdrawal fees
    bytes32 public constant UI_WITHDRAWAL_FEE_TYPE = keccak256(abi.encode("UI_WITHDRAWAL_FEE_TYPE"));
    // @dev key for ui swap fees
    bytes32 public constant UI_SWAP_FEE_TYPE = keccak256(abi.encode("UI_SWAP_FEE_TYPE"));
    // @dev key for ui position fees
    bytes32 public constant UI_POSITION_FEE_TYPE = keccak256(abi.encode("UI_POSITION_FEE_TYPE"));

    // @dev key for ui fee factor
    bytes32 public constant UI_FEE_FACTOR = keccak256(abi.encode("UI_FEE_FACTOR"));
    // @dev key for max ui fee receiver factor
    bytes32 public constant MAX_UI_FEE_FACTOR = keccak256(abi.encode("MAX_UI_FEE_FACTOR"));

    // @dev key for the claimable fee amount
    bytes32 public constant CLAIMABLE_FEE_AMOUNT = keccak256(abi.encode("CLAIMABLE_FEE_AMOUNT"));
    // @dev key for the claimable ui fee amount
    bytes32 public constant CLAIMABLE_UI_FEE_AMOUNT = keccak256(abi.encode("CLAIMABLE_UI_FEE_AMOUNT"));
    // @dev key for the max number of auto cancel orders
    bytes32 public constant MAX_AUTO_CANCEL_ORDERS = keccak256(abi.encode("MAX_AUTO_CANCEL_ORDERS"));
    // @dev key for the max total callback gas limit for auto cancel orders
    bytes32 public constant MAX_TOTAL_CALLBACK_GAS_LIMIT_FOR_AUTO_CANCEL_ORDERS = keccak256(abi.encode("MAX_TOTAL_CALLBACK_GAS_LIMIT_FOR_AUTO_CANCEL_ORDERS"));

    // @dev key for the market list
    bytes32 public constant MARKET_LIST = keccak256(abi.encode("MARKET_LIST"));

    // @dev key for the fee batch list
    bytes32 public constant FEE_BATCH_LIST = keccak256(abi.encode("FEE_BATCH_LIST"));

    // @dev key for the deposit list
    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));
    // @dev key for the account deposit list
    bytes32 public constant ACCOUNT_DEPOSIT_LIST = keccak256(abi.encode("ACCOUNT_DEPOSIT_LIST"));

    // @dev key for the withdrawal list
    bytes32 public constant WITHDRAWAL_LIST = keccak256(abi.encode("WITHDRAWAL_LIST"));
    // @dev key for the account withdrawal list
    bytes32 public constant ACCOUNT_WITHDRAWAL_LIST = keccak256(abi.encode("ACCOUNT_WITHDRAWAL_LIST"));

    // @dev key for the shift list
    bytes32 public constant SHIFT_LIST = keccak256(abi.encode("SHIFT_LIST"));
    // @dev key for the account shift list
    bytes32 public constant ACCOUNT_SHIFT_LIST = keccak256(abi.encode("ACCOUNT_SHIFT_LIST"));

    bytes32 public constant GLV_LIST = keccak256(abi.encode("GLV_LIST"));
    bytes32 public constant GLV_DEPOSIT_LIST = keccak256(abi.encode("GLV_DEPOSIT_LIST"));
    bytes32 public constant GLV_SHIFT_LIST = keccak256(abi.encode("GLV_SHIFT_LIST"));
    bytes32 public constant ACCOUNT_GLV_DEPOSIT_LIST = keccak256(abi.encode("ACCOUNT_GLV_DEPOSIT_LIST"));
    bytes32 public constant GLV_WITHDRAWAL_LIST = keccak256(abi.encode("GLV_WITHDRAWAL_LIST"));
    bytes32 public constant ACCOUNT_GLV_WITHDRAWAL_LIST = keccak256(abi.encode("ACCOUNT_GLV_WITHDRAWAL_LIST"));
    bytes32 public constant GLV_SUPPORTED_MARKET_LIST = keccak256(abi.encode("GLV_SUPPORTED_MARKET_LIST"));

    // @dev key for the position list
    bytes32 public constant POSITION_LIST = keccak256(abi.encode("POSITION_LIST"));
    // @dev key for the account position list
    bytes32 public constant ACCOUNT_POSITION_LIST = keccak256(abi.encode("ACCOUNT_POSITION_LIST"));

    // @dev key for the order list
    bytes32 public constant ORDER_LIST = keccak256(abi.encode("ORDER_LIST"));
    // @dev key for the account order list
    bytes32 public constant ACCOUNT_ORDER_LIST = keccak256(abi.encode("ACCOUNT_ORDER_LIST"));

    // @dev key for the subaccount list
    bytes32 public constant SUBACCOUNT_LIST = keccak256(abi.encode("SUBACCOUNT_LIST"));

    // @dev key for the auto cancel order list
    bytes32 public constant AUTO_CANCEL_ORDER_LIST = keccak256(abi.encode("AUTO_CANCEL_ORDER_LIST"));

    // @dev key for is market disabled
    bytes32 public constant IS_MARKET_DISABLED = keccak256(abi.encode("IS_MARKET_DISABLED"));

    // @dev key for the max swap path length allowed
    bytes32 public constant MAX_SWAP_PATH_LENGTH = keccak256(abi.encode("MAX_SWAP_PATH_LENGTH"));
    // @dev key used to store markets observed in a swap path, to ensure that a swap path contains unique markets
    bytes32 public constant SWAP_PATH_MARKET_FLAG = keccak256(abi.encode("SWAP_PATH_MARKET_FLAG"));
    // @dev key used to store the min market tokens for the first deposit for a market
    bytes32 public constant MIN_MARKET_TOKENS_FOR_FIRST_DEPOSIT = keccak256(abi.encode("MIN_MARKET_TOKENS_FOR_FIRST_DEPOSIT"));

    bytes32 public constant CREATE_GLV_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("CREATE_GLV_DEPOSIT_FEATURE_DISABLED"));
    bytes32 public constant CANCEL_GLV_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_GLV_DEPOSIT_FEATURE_DISABLED"));
    bytes32 public constant EXECUTE_GLV_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_GLV_DEPOSIT_FEATURE_DISABLED"));

    bytes32 public constant CREATE_GLV_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("CREATE_GLV_WITHDRAWAL_FEATURE_DISABLED"));
    bytes32 public constant CANCEL_GLV_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_GLV_WITHDRAWAL_FEATURE_DISABLED"));
    bytes32 public constant EXECUTE_GLV_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_GLV_WITHDRAWAL_FEATURE_DISABLED"));

    bytes32 public constant CREATE_GLV_SHIFT_FEATURE_DISABLED = keccak256(abi.encode("CREATE_GLV_SHIFT_FEATURE_DISABLED"));
    bytes32 public constant EXECUTE_GLV_SHIFT_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_GLV_SHIFT_FEATURE_DISABLED"));

    // @dev key for whether the create deposit feature is disabled
    bytes32 public constant CREATE_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("CREATE_DEPOSIT_FEATURE_DISABLED"));
    // @dev key for whether the cancel deposit feature is disabled
    bytes32 public constant CANCEL_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_DEPOSIT_FEATURE_DISABLED"));
    // @dev key for whether the execute deposit feature is disabled
    bytes32 public constant EXECUTE_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_DEPOSIT_FEATURE_DISABLED"));

    // @dev key for whether the create withdrawal feature is disabled
    bytes32 public constant CREATE_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("CREATE_WITHDRAWAL_FEATURE_DISABLED"));
    // @dev key for whether the cancel withdrawal feature is disabled
    bytes32 public constant CANCEL_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_WITHDRAWAL_FEATURE_DISABLED"));
    // @dev key for whether the execute withdrawal feature is disabled
    bytes32 public constant EXECUTE_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_WITHDRAWAL_FEATURE_DISABLED"));
    // @dev key for whether the execute atomic withdrawal feature is disabled
    bytes32 public constant EXECUTE_ATOMIC_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_ATOMIC_WITHDRAWAL_FEATURE_DISABLED"));

    // @dev key for whether the create shift feature is disabled
    bytes32 public constant CREATE_SHIFT_FEATURE_DISABLED = keccak256(abi.encode("CREATE_SHIFT_FEATURE_DISABLED"));
    // @dev key for whether the cancel shift feature is disabled
    bytes32 public constant CANCEL_SHIFT_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_SHIFT_FEATURE_DISABLED"));
    // @dev key for whether the execute shift feature is disabled
    bytes32 public constant EXECUTE_SHIFT_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_SHIFT_FEATURE_DISABLED"));

    // @dev key for whether the create order feature is disabled
    bytes32 public constant CREATE_ORDER_FEATURE_DISABLED = keccak256(abi.encode("CREATE_ORDER_FEATURE_DISABLED"));
    // @dev key for whether the execute order feature is disabled
    bytes32 public constant EXECUTE_ORDER_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_ORDER_FEATURE_DISABLED"));
    // @dev key for whether the execute adl feature is disabled
    // for liquidations, it can be disabled by using the EXECUTE_ORDER_FEATURE_DISABLED key with the Liquidation
    // order type, ADL orders have a MarketDecrease order type, so a separate key is needed to disable it
    bytes32 public constant EXECUTE_ADL_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_ADL_FEATURE_DISABLED"));
    // @dev key for whether the update order feature is disabled
    bytes32 public constant UPDATE_ORDER_FEATURE_DISABLED = keccak256(abi.encode("UPDATE_ORDER_FEATURE_DISABLED"));
    // @dev key for whether the cancel order feature is disabled
    bytes32 public constant CANCEL_ORDER_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_ORDER_FEATURE_DISABLED"));

    // @dev key for whether the claim funding fees feature is disabled
    bytes32 public constant CLAIM_FUNDING_FEES_FEATURE_DISABLED = keccak256(abi.encode("CLAIM_FUNDING_FEES_FEATURE_DISABLED"));
    // @dev key for whether the claim collateral feature is disabled
    bytes32 public constant CLAIM_COLLATERAL_FEATURE_DISABLED = keccak256(abi.encode("CLAIM_COLLATERAL_FEATURE_DISABLED"));
    // @dev key for whether the claim affiliate rewards feature is disabled
    bytes32 public constant CLAIM_AFFILIATE_REWARDS_FEATURE_DISABLED = keccak256(abi.encode("CLAIM_AFFILIATE_REWARDS_FEATURE_DISABLED"));
    // @dev key for whether the claim ui fees feature is disabled
    bytes32 public constant CLAIM_UI_FEES_FEATURE_DISABLED = keccak256(abi.encode("CLAIM_UI_FEES_FEATURE_DISABLED"));
    // @dev key for whether the subaccount feature is disabled
    bytes32 public constant SUBACCOUNT_FEATURE_DISABLED = keccak256(abi.encode("SUBACCOUNT_FEATURE_DISABLED"));

    // @dev key for the minimum required oracle signers for an oracle observation
    bytes32 public constant MIN_ORACLE_SIGNERS = keccak256(abi.encode("MIN_ORACLE_SIGNERS"));
    // @dev key for the minimum block confirmations before blockhash can be excluded for oracle signature validation
    bytes32 public constant MIN_ORACLE_BLOCK_CONFIRMATIONS = keccak256(abi.encode("MIN_ORACLE_BLOCK_CONFIRMATIONS"));
    // @dev key for the maximum usable oracle price age in seconds
    bytes32 public constant MAX_ORACLE_PRICE_AGE = keccak256(abi.encode("MAX_ORACLE_PRICE_AGE"));
    // @dev key for the maximum oracle timestamp range
    bytes32 public constant MAX_ORACLE_TIMESTAMP_RANGE = keccak256(abi.encode("MAX_ORACLE_TIMESTAMP_RANGE"));
    // @dev key for the maximum oracle price deviation factor from the ref price
    bytes32 public constant MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR = keccak256(abi.encode("MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR"));
    // @dev key for whether an oracle provider is enabled
    bytes32 public constant IS_ORACLE_PROVIDER_ENABLED = keccak256(abi.encode("IS_ORACLE_PROVIDER_ENABLED"));
    // @dev key for whether an oracle provider can be used for atomic actions
    bytes32 public constant IS_ATOMIC_ORACLE_PROVIDER = keccak256(abi.encode("IS_ATOMIC_ORACLE_PROVIDER"));
    // @dev key for oracle timestamp adjustment
    bytes32 public constant ORACLE_TIMESTAMP_ADJUSTMENT = keccak256(abi.encode("ORACLE_TIMESTAMP_ADJUSTMENT"));
    // @dev key for oracle provider for token
    bytes32 public constant ORACLE_PROVIDER_FOR_TOKEN = keccak256(abi.encode("ORACLE_PROVIDER_FOR_TOKEN"));
    // @dev key for the chainlink payment token
    bytes32 public constant CHAINLINK_PAYMENT_TOKEN = keccak256(abi.encode("CHAINLINK_PAYMENT_TOKEN"));
    // @dev key for the sequencer grace duration
    bytes32 public constant SEQUENCER_GRACE_DURATION = keccak256(abi.encode("SEQUENCER_GRACE_DURATION"));

    // @dev key for the percentage amount of position fees to be received
    bytes32 public constant POSITION_FEE_RECEIVER_FACTOR = keccak256(abi.encode("POSITION_FEE_RECEIVER_FACTOR"));
    // @dev key for the percentage amount of liquidation fees to be received
    bytes32 public constant LIQUIDATION_FEE_RECEIVER_FACTOR = keccak256(abi.encode("LIQUIDATION_FEE_RECEIVER_FACTOR"));
    // @dev key for the percentage amount of swap fees to be received
    bytes32 public constant SWAP_FEE_RECEIVER_FACTOR = keccak256(abi.encode("SWAP_FEE_RECEIVER_FACTOR"));
    // @dev key for the percentage amount of borrowing fees to be received
    bytes32 public constant BORROWING_FEE_RECEIVER_FACTOR = keccak256(abi.encode("BORROWING_FEE_RECEIVER_FACTOR"));

    // @dev key for the base gas limit used when estimating execution fee
    bytes32 public constant ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1 = keccak256(abi.encode("ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1"));
    // @dev key for the gas limit used for each oracle price when estimating execution fee
    bytes32 public constant ESTIMATED_GAS_FEE_PER_ORACLE_PRICE = keccak256(abi.encode("ESTIMATED_GAS_FEE_PER_ORACLE_PRICE"));
    // @dev key for the multiplier used when estimating execution fee
    bytes32 public constant ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR = keccak256(abi.encode("ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR"));

    // @dev key for the base gas limit used when calculating execution fee
    bytes32 public constant EXECUTION_GAS_FEE_BASE_AMOUNT_V2_1 = keccak256(abi.encode("EXECUTION_GAS_FEE_BASE_AMOUNT_V2_1"));
    // @dev key for the gas limit used for each oracle price
    bytes32 public constant EXECUTION_GAS_FEE_PER_ORACLE_PRICE = keccak256(abi.encode("EXECUTION_GAS_FEE_PER_ORACLE_PRICE"));
    // @dev key for the multiplier used when calculating execution fee
    bytes32 public constant EXECUTION_GAS_FEE_MULTIPLIER_FACTOR = keccak256(abi.encode("EXECUTION_GAS_FEE_MULTIPLIER_FACTOR"));

    // @dev key for the estimated gas limit for deposits
    bytes32 public constant DEPOSIT_GAS_LIMIT = keccak256(abi.encode("DEPOSIT_GAS_LIMIT"));
    // @dev key for the estimated gas limit for withdrawals
    bytes32 public constant WITHDRAWAL_GAS_LIMIT = keccak256(abi.encode("WITHDRAWAL_GAS_LIMIT"));
    bytes32 public constant GLV_DEPOSIT_GAS_LIMIT = keccak256(abi.encode("GLV_DEPOSIT_GAS_LIMIT"));
    bytes32 public constant GLV_WITHDRAWAL_GAS_LIMIT = keccak256(abi.encode("GLV_WITHDRAWAL_GAS_LIMIT"));
    bytes32 public constant GLV_SHIFT_GAS_LIMIT = keccak256(abi.encode("GLV_SHIFT_GAS_LIMIT"));
    bytes32 public constant GLV_PER_MARKET_GAS_LIMIT = keccak256(abi.encode("GLV_PER_MARKET_GAS_LIMIT"));
    // @dev key for the estimated gas limit for shifts
    bytes32 public constant SHIFT_GAS_LIMIT = keccak256(abi.encode("SHIFT_GAS_LIMIT"));
    // @dev key for the estimated gas limit for single swaps
    bytes32 public constant SINGLE_SWAP_GAS_LIMIT = keccak256(abi.encode("SINGLE_SWAP_GAS_LIMIT"));
    // @dev key for the estimated gas limit for increase orders
    bytes32 public constant INCREASE_ORDER_GAS_LIMIT = keccak256(abi.encode("INCREASE_ORDER_GAS_LIMIT"));
    // @dev key for the estimated gas limit for decrease orders
    bytes32 public constant DECREASE_ORDER_GAS_LIMIT = keccak256(abi.encode("DECREASE_ORDER_GAS_LIMIT"));
    // @dev key for the estimated gas limit for swap orders
    bytes32 public constant SWAP_ORDER_GAS_LIMIT = keccak256(abi.encode("SWAP_ORDER_GAS_LIMIT"));
    // @dev key for the amount of gas to forward for token transfers
    bytes32 public constant TOKEN_TRANSFER_GAS_LIMIT = keccak256(abi.encode("TOKEN_TRANSFER_GAS_LIMIT"));
    // @dev key for the amount of gas to forward for native token transfers
    bytes32 public constant NATIVE_TOKEN_TRANSFER_GAS_LIMIT = keccak256(abi.encode("NATIVE_TOKEN_TRANSFER_GAS_LIMIT"));
    // @dev key for the request expiration time, after which the request will be considered expired
    bytes32 public constant REQUEST_EXPIRATION_TIME = keccak256(abi.encode("REQUEST_EXPIRATION_TIME"));

    bytes32 public constant MAX_CALLBACK_GAS_LIMIT = keccak256(abi.encode("MAX_CALLBACK_GAS_LIMIT"));
    bytes32 public constant REFUND_EXECUTION_FEE_GAS_LIMIT = keccak256(abi.encode("REFUND_EXECUTION_FEE_GAS_LIMIT"));
    bytes32 public constant SAVED_CALLBACK_CONTRACT = keccak256(abi.encode("SAVED_CALLBACK_CONTRACT"));

    // @dev key for the min collateral factor
    bytes32 public constant MIN_COLLATERAL_FACTOR = keccak256(abi.encode("MIN_COLLATERAL_FACTOR"));
    // @dev key for the min collateral factor for open interest multiplier
    bytes32 public constant MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER = keccak256(abi.encode("MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER"));
    // @dev key for the min allowed collateral in USD
    bytes32 public constant MIN_COLLATERAL_USD = keccak256(abi.encode("MIN_COLLATERAL_USD"));
    // @dev key for the min allowed position size in USD
    bytes32 public constant MIN_POSITION_SIZE_USD = keccak256(abi.encode("MIN_POSITION_SIZE_USD"));

    // @dev key for the virtual id of tokens
    bytes32 public constant VIRTUAL_TOKEN_ID = keccak256(abi.encode("VIRTUAL_TOKEN_ID"));
    // @dev key for the virtual id of markets
    bytes32 public constant VIRTUAL_MARKET_ID = keccak256(abi.encode("VIRTUAL_MARKET_ID"));
    // @dev key for the virtual inventory for swaps
    bytes32 public constant VIRTUAL_INVENTORY_FOR_SWAPS = keccak256(abi.encode("VIRTUAL_INVENTORY_FOR_SWAPS"));
    // @dev key for the virtual inventory for positions
    bytes32 public constant VIRTUAL_INVENTORY_FOR_POSITIONS = keccak256(abi.encode("VIRTUAL_INVENTORY_FOR_POSITIONS"));

    // @dev key for the position impact factor
    bytes32 public constant POSITION_IMPACT_FACTOR = keccak256(abi.encode("POSITION_IMPACT_FACTOR"));
    // @dev key for the position impact exponent factor
    bytes32 public constant POSITION_IMPACT_EXPONENT_FACTOR = keccak256(abi.encode("POSITION_IMPACT_EXPONENT_FACTOR"));
    // @dev key for the max decrease position impact factor
    bytes32 public constant MAX_POSITION_IMPACT_FACTOR = keccak256(abi.encode("MAX_POSITION_IMPACT_FACTOR"));
    // @dev key for the max position impact factor for liquidations
    bytes32 public constant MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS = keccak256(abi.encode("MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS"));
    // @dev key for the position fee factor
    bytes32 public constant POSITION_FEE_FACTOR = keccak256(abi.encode("POSITION_FEE_FACTOR"));
    bytes32 public constant PRO_TRADER_TIER = keccak256(abi.encode("PRO_TRADER_TIER"));
    bytes32 public constant PRO_DISCOUNT_FACTOR = keccak256(abi.encode("PRO_DISCOUNT_FACTOR"));
    // @dev key for the liquidation fee factor
    bytes32 public constant LIQUIDATION_FEE_FACTOR = keccak256(abi.encode("LIQUIDATION_FEE_FACTOR"));
    // @dev key for the swap impact factor
    bytes32 public constant SWAP_IMPACT_FACTOR = keccak256(abi.encode("SWAP_IMPACT_FACTOR"));
    // @dev key for the swap impact exponent factor
    bytes32 public constant SWAP_IMPACT_EXPONENT_FACTOR = keccak256(abi.encode("SWAP_IMPACT_EXPONENT_FACTOR"));
    // @dev key for the swap fee factor
    bytes32 public constant SWAP_FEE_FACTOR = keccak256(abi.encode("SWAP_FEE_FACTOR"));
    // @dev key for the atomic swap fee factor
    bytes32 public constant ATOMIC_SWAP_FEE_FACTOR = keccak256(abi.encode("ATOMIC_SWAP_FEE_FACTOR"));
    bytes32 public constant DEPOSIT_FEE_FACTOR = keccak256(abi.encode("DEPOSIT_FEE_FACTOR"));
    bytes32 public constant WITHDRAWAL_FEE_FACTOR = keccak256(abi.encode("WITHDRAWAL_FEE_FACTOR"));
    // @dev key for the oracle type
    bytes32 public constant ORACLE_TYPE = keccak256(abi.encode("ORACLE_TYPE"));
    // @dev key for open interest
    bytes32 public constant OPEN_INTEREST = keccak256(abi.encode("OPEN_INTEREST"));
    // @dev key for open interest in tokens
    bytes32 public constant OPEN_INTEREST_IN_TOKENS = keccak256(abi.encode("OPEN_INTEREST_IN_TOKENS"));
    // @dev key for collateral sum for a market
    bytes32 public constant COLLATERAL_SUM = keccak256(abi.encode("COLLATERAL_SUM"));
    // @dev key for pool amount
    bytes32 public constant POOL_AMOUNT = keccak256(abi.encode("POOL_AMOUNT"));
    // @dev key for max pool amount
    bytes32 public constant MAX_POOL_AMOUNT = keccak256(abi.encode("MAX_POOL_AMOUNT"));
    // @dev key for max pool usd for deposit
    bytes32 public constant MAX_POOL_USD_FOR_DEPOSIT = keccak256(abi.encode("MAX_POOL_USD_FOR_DEPOSIT"));
    // @dev key for max open interest
    bytes32 public constant MAX_OPEN_INTEREST = keccak256(abi.encode("MAX_OPEN_INTEREST"));
    // @dev key for position impact pool amount
    bytes32 public constant POSITION_IMPACT_POOL_AMOUNT = keccak256(abi.encode("POSITION_IMPACT_POOL_AMOUNT"));
    // @dev key for min position impact pool amount
    bytes32 public constant MIN_POSITION_IMPACT_POOL_AMOUNT = keccak256(abi.encode("MIN_POSITION_IMPACT_POOL_AMOUNT"));
    // @dev key for position impact pool distribution rate
    bytes32 public constant POSITION_IMPACT_POOL_DISTRIBUTION_RATE = keccak256(abi.encode("POSITION_IMPACT_POOL_DISTRIBUTION_RATE"));
    // @dev key for position impact pool distributed at
    bytes32 public constant POSITION_IMPACT_POOL_DISTRIBUTED_AT = keccak256(abi.encode("POSITION_IMPACT_POOL_DISTRIBUTED_AT"));
    // @dev key for swap impact pool amount
    bytes32 public constant SWAP_IMPACT_POOL_AMOUNT = keccak256(abi.encode("SWAP_IMPACT_POOL_AMOUNT"));
    // @dev key for price feed
    bytes32 public constant PRICE_FEED = keccak256(abi.encode("PRICE_FEED"));
    // @dev key for price feed multiplier
    bytes32 public constant PRICE_FEED_MULTIPLIER = keccak256(abi.encode("PRICE_FEED_MULTIPLIER"));
    // @dev key for price feed heartbeat
    bytes32 public constant PRICE_FEED_HEARTBEAT_DURATION = keccak256(abi.encode("PRICE_FEED_HEARTBEAT_DURATION"));
    // @dev key for data stream feed id
    bytes32 public constant DATA_STREAM_ID = keccak256(abi.encode("DATA_STREAM_ID"));
    // @dev key for data stream feed multiplier
    bytes32 public constant DATA_STREAM_MULTIPLIER = keccak256(abi.encode("DATA_STREAM_MULTIPLIER"));
    bytes32 public constant DATA_STREAM_SPREAD_REDUCTION_FACTOR = keccak256(abi.encode("DATA_STREAM_SPREAD_REDUCTION_FACTOR"));
    // @dev key for stable price
    bytes32 public constant STABLE_PRICE = keccak256(abi.encode("STABLE_PRICE"));
    // @dev key for reserve factor
    bytes32 public constant RESERVE_FACTOR = keccak256(abi.encode("RESERVE_FACTOR"));
    // @dev key for open interest reserve factor
    bytes32 public constant OPEN_INTEREST_RESERVE_FACTOR = keccak256(abi.encode("OPEN_INTEREST_RESERVE_FACTOR"));
    // @dev key for max pnl factor
    bytes32 public constant MAX_PNL_FACTOR = keccak256(abi.encode("MAX_PNL_FACTOR"));
    // @dev key for max pnl factor
    bytes32 public constant MAX_PNL_FACTOR_FOR_TRADERS = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_TRADERS"));
    // @dev key for max pnl factor for adl
    bytes32 public constant MAX_PNL_FACTOR_FOR_ADL = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_ADL"));
    // @dev key for min pnl factor for adl
    bytes32 public constant MIN_PNL_FACTOR_AFTER_ADL = keccak256(abi.encode("MIN_PNL_FACTOR_AFTER_ADL"));
    // @dev key for max pnl factor
    bytes32 public constant MAX_PNL_FACTOR_FOR_DEPOSITS = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_DEPOSITS"));
    // @dev key for max pnl factor for withdrawals
    bytes32 public constant MAX_PNL_FACTOR_FOR_WITHDRAWALS = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_WITHDRAWALS"));
    // @dev key for latest ADL at
    bytes32 public constant LATEST_ADL_AT = keccak256(abi.encode("LATEST_ADL_AT"));
    // @dev key for whether ADL is enabled
    bytes32 public constant IS_ADL_ENABLED = keccak256(abi.encode("IS_ADL_ENABLED"));
    // @dev key for funding factor
    bytes32 public constant FUNDING_FACTOR = keccak256(abi.encode("FUNDING_FACTOR"));
    // @dev key for funding exponent factor
    bytes32 public constant FUNDING_EXPONENT_FACTOR = keccak256(abi.encode("FUNDING_EXPONENT_FACTOR"));
    // @dev key for saved funding factor
    bytes32 public constant SAVED_FUNDING_FACTOR_PER_SECOND = keccak256(abi.encode("SAVED_FUNDING_FACTOR_PER_SECOND"));
    // @dev key for funding increase factor
    bytes32 public constant FUNDING_INCREASE_FACTOR_PER_SECOND = keccak256(abi.encode("FUNDING_INCREASE_FACTOR_PER_SECOND"));
    // @dev key for funding decrease factor
    bytes32 public constant FUNDING_DECREASE_FACTOR_PER_SECOND = keccak256(abi.encode("FUNDING_DECREASE_FACTOR_PER_SECOND"));
    // @dev key for min funding factor
    bytes32 public constant MIN_FUNDING_FACTOR_PER_SECOND = keccak256(abi.encode("MIN_FUNDING_FACTOR_PER_SECOND"));
    // @dev key for max funding factor
    bytes32 public constant MAX_FUNDING_FACTOR_PER_SECOND = keccak256(abi.encode("MAX_FUNDING_FACTOR_PER_SECOND"));
    // @dev key for threshold for stable funding
    bytes32 public constant THRESHOLD_FOR_STABLE_FUNDING = keccak256(abi.encode("THRESHOLD_FOR_STABLE_FUNDING"));
    // @dev key for threshold for decrease funding
    bytes32 public constant THRESHOLD_FOR_DECREASE_FUNDING = keccak256(abi.encode("THRESHOLD_FOR_DECREASE_FUNDING"));
    // @dev key for funding fee amount per size
    bytes32 public constant FUNDING_FEE_AMOUNT_PER_SIZE = keccak256(abi.encode("FUNDING_FEE_AMOUNT_PER_SIZE"));
    // @dev key for claimable funding amount per size
    bytes32 public constant CLAIMABLE_FUNDING_AMOUNT_PER_SIZE = keccak256(abi.encode("CLAIMABLE_FUNDING_AMOUNT_PER_SIZE"));
    // @dev key for when funding was last updated at
    bytes32 public constant FUNDING_UPDATED_AT = keccak256(abi.encode("FUNDING_UPDATED_AT"));
    // @dev key for claimable funding amount
    bytes32 public constant CLAIMABLE_FUNDING_AMOUNT = keccak256(abi.encode("CLAIMABLE_FUNDING_AMOUNT"));
    // @dev key for claimable collateral amount
    bytes32 public constant CLAIMABLE_COLLATERAL_AMOUNT = keccak256(abi.encode("CLAIMABLE_COLLATERAL_AMOUNT"));
    // @dev key for claimable collateral factor
    bytes32 public constant CLAIMABLE_COLLATERAL_FACTOR = keccak256(abi.encode("CLAIMABLE_COLLATERAL_FACTOR"));
    // @dev key for claimable collateral time divisor
    bytes32 public constant CLAIMABLE_COLLATERAL_TIME_DIVISOR = keccak256(abi.encode("CLAIMABLE_COLLATERAL_TIME_DIVISOR"));
    // @dev key for claimed collateral amount
    bytes32 public constant CLAIMED_COLLATERAL_AMOUNT = keccak256(abi.encode("CLAIMED_COLLATERAL_AMOUNT"));
    bytes32 public constant IGNORE_OPEN_INTEREST_FOR_USAGE_FACTOR = keccak256(abi.encode("IGNORE_OPEN_INTEREST_FOR_USAGE_FACTOR"));
    // @dev key for optimal usage factor
    bytes32 public constant OPTIMAL_USAGE_FACTOR = keccak256(abi.encode("OPTIMAL_USAGE_FACTOR"));
    // @dev key for base borrowing factor
    bytes32 public constant BASE_BORROWING_FACTOR = keccak256(abi.encode("BASE_BORROWING_FACTOR"));
    // @dev key for above optimal usage borrowing factor
    bytes32 public constant ABOVE_OPTIMAL_USAGE_BORROWING_FACTOR = keccak256(abi.encode("ABOVE_OPTIMAL_USAGE_BORROWING_FACTOR"));
    // @dev key for borrowing factor
    bytes32 public constant BORROWING_FACTOR = keccak256(abi.encode("BORROWING_FACTOR"));
    // @dev key for borrowing factor
    bytes32 public constant BORROWING_EXPONENT_FACTOR = keccak256(abi.encode("BORROWING_EXPONENT_FACTOR"));
    // @dev key for skipping the borrowing factor for the smaller side
    bytes32 public constant SKIP_BORROWING_FEE_FOR_SMALLER_SIDE = keccak256(abi.encode("SKIP_BORROWING_FEE_FOR_SMALLER_SIDE"));
    // @dev key for cumulative borrowing factor
    bytes32 public constant CUMULATIVE_BORROWING_FACTOR = keccak256(abi.encode("CUMULATIVE_BORROWING_FACTOR"));
    // @dev key for when the cumulative borrowing factor was last updated at
    bytes32 public constant CUMULATIVE_BORROWING_FACTOR_UPDATED_AT = keccak256(abi.encode("CUMULATIVE_BORROWING_FACTOR_UPDATED_AT"));
    // @dev key for total borrowing amount
    bytes32 public constant TOTAL_BORROWING = keccak256(abi.encode("TOTAL_BORROWING"));
    // @dev key for affiliate reward
    bytes32 public constant MIN_AFFILIATE_REWARD_FACTOR = keccak256(abi.encode("MIN_AFFILIATE_REWARD_FACTOR"));
    bytes32 public constant AFFILIATE_REWARD = keccak256(abi.encode("AFFILIATE_REWARD"));
    // @dev key for max allowed subaccount action count
    bytes32 public constant MAX_ALLOWED_SUBACCOUNT_ACTION_COUNT = keccak256(abi.encode("MAX_ALLOWED_SUBACCOUNT_ACTION_COUNT"));
    bytes32 public constant SUBACCOUNT_EXPIRES_AT = keccak256(abi.encode("SUBACCOUNT_EXPIRES_AT"));
    // @dev key for subaccount action count
    bytes32 public constant SUBACCOUNT_ACTION_COUNT = keccak256(abi.encode("SUBACCOUNT_ACTION_COUNT"));
    // @dev key for subaccount auto top up amount
    bytes32 public constant SUBACCOUNT_AUTO_TOP_UP_AMOUNT = keccak256(abi.encode("SUBACCOUNT_AUTO_TOP_UP_AMOUNT"));
    // @dev key for subaccount order action
    bytes32 public constant SUBACCOUNT_ORDER_ACTION = keccak256(abi.encode("SUBACCOUNT_ORDER_ACTION"));
    // @dev key for fee distributor swap order token index
    bytes32 public constant FEE_DISTRIBUTOR_SWAP_TOKEN_INDEX = keccak256(abi.encode("FEE_DISTRIBUTOR_SWAP_TOKEN_INDEX"));
    // @dev key for fee distributor swap fee batch
    bytes32 public constant FEE_DISTRIBUTOR_SWAP_FEE_BATCH = keccak256(abi.encode("FEE_DISTRIBUTOR_SWAP_FEE_BATCH"));

    bytes32 public constant GLV_MAX_MARKET_COUNT = keccak256(abi.encode("GLV_MAX_MARKET_COUNT"));
    bytes32 public constant GLV_MAX_MARKET_TOKEN_BALANCE_USD = keccak256(abi.encode("GLV_MAX_MARKET_TOKEN_BALANCE_USD"));
    bytes32 public constant GLV_MAX_MARKET_TOKEN_BALANCE_AMOUNT = keccak256(abi.encode("GLV_MAX_MARKET_TOKEN_BALANCE_AMOUNT"));
    bytes32 public constant IS_GLV_MARKET_DISABLED = keccak256(abi.encode("IS_GLV_MARKET_DISABLED"));
    bytes32 public constant GLV_SHIFT_MAX_PRICE_IMPACT_FACTOR = keccak256(abi.encode("GLV_SHIFT_MAX_PRICE_IMPACT_FACTOR"));
    bytes32 public constant GLV_SHIFT_LAST_EXECUTED_AT = keccak256(abi.encode("GLV_SHIFT_LAST_EXECUTED_AT"));
    bytes32 public constant GLV_SHIFT_MIN_INTERVAL = keccak256(abi.encode("GLV_SHIFT_MIN_INTERVAL"));
    bytes32 public constant MIN_GLV_TOKENS_FOR_FIRST_DEPOSIT = keccak256(abi.encode("MIN_GLV_TOKENS_FOR_FIRST_DEPOSIT"));

    // @dev key for disabling automatic parameter updates via ConfigSyncer
    bytes32 public constant SYNC_CONFIG_FEATURE_DISABLED = keccak256(abi.encode("SYNC_CONFIG_FEATURE_DISABLED"));
    // @dev key for disabling all parameter updates for a specific market via ConfigSyncer
    bytes32 public constant SYNC_CONFIG_MARKET_DISABLED = keccak256(abi.encode("SYNC_CONFIG_MARKET_DISABLED"));
    // @dev key for disabling all updates for a specific parameter via ConfigSyncer
    bytes32 public constant SYNC_CONFIG_PARAMETER_DISABLED = keccak256(abi.encode("SYNC_CONFIG_PARAMETER_DISABLED"));
    // @dev key for disabling all updates for a specific market parameter via ConfigSyncer
    bytes32 public constant SYNC_CONFIG_MARKET_PARAMETER_DISABLED = keccak256(abi.encode("SYNC_CONFIG_MARKET_PARAMETER_DISABLED"));
    // @dev key for tracking which updateIds have already been applied by ConfigSyncer
    bytes32 public constant SYNC_CONFIG_UPDATE_COMPLETED = keccak256(abi.encode("SYNC_CONFIG_UPDATE_COMPLETED"));
    // @dev key for the latest updateId that has been applied by ConfigSyncer
    bytes32 public constant SYNC_CONFIG_LATEST_UPDATE_ID = keccak256(abi.encode("SYNC_CONFIG_LATEST_UPDATE_ID"));

    // @dev key for the contributor account list
    bytes32 public constant CONTRIBUTOR_ACCOUNT_LIST = keccak256(abi.encode("CONTRIBUTOR_ACCOUNT_LIST"));
    // @dev key for the contributor token list
    bytes32 public constant CONTRIBUTOR_TOKEN_LIST = keccak256(abi.encode("CONTRIBUTOR_TOKEN_LIST"));
    // @dev key for the contributor token amount
    bytes32 public constant CONTRIBUTOR_TOKEN_AMOUNT = keccak256(abi.encode("CONTRIBUTOR_TOKEN_AMOUNT"));
    // @dev key for the max total contributor token amount
    bytes32 public constant MAX_TOTAL_CONTRIBUTOR_TOKEN_AMOUNT = keccak256(abi.encode("MAX_TOTAL_CONTRIBUTOR_TOKEN_AMOUNT"));
    // @dev key for the contributor token vault
    bytes32 public constant CONTRIBUTOR_TOKEN_VAULT = keccak256(abi.encode("CONTRIBUTOR_TOKEN_VAULT"));
    // @dev key for the contributor last payment at
    bytes32 public constant CONTRIBUTOR_LAST_PAYMENT_AT = keccak256(abi.encode("CONTRIBUTOR_LAST_PAYMENT_AT"));
    // @dev key for the min contributor payment interval
    bytes32 public constant MIN_CONTRIBUTOR_PAYMENT_INTERVAL = keccak256(abi.encode("MIN_CONTRIBUTOR_PAYMENT_INTERVAL"));

    // @dev key for the buyback batch amount used when claiming and swapping fees
    bytes32 public constant BUYBACK_BATCH_AMOUNT = keccak256(abi.encode("BUYBACK_BATCH_AMOUNT"));
    // @dev key for the buyback available fees
    bytes32 public constant BUYBACK_AVAILABLE_FEE_AMOUNT = keccak256(abi.encode("BUYBACK_AVAILABLE_FEE_AMOUNT"));
    // @dev key for the buyback gmx fee factor used in calculating fees by GMX/WNT
    bytes32 public constant BUYBACK_GMX_FACTOR = keccak256(abi.encode("BUYBACK_GMX_FACTOR"));
    // @dev key for the FeeHandler max price impact when buying back fees
    bytes32 public constant BUYBACK_MAX_PRICE_IMPACT_FACTOR = keccak256(abi.encode("BUYBACK_MAX_PRICE_IMPACT_FACTOR"));
    // @dev key for the maximum price delay in seconds when buying back fees
    bytes32 public constant BUYBACK_MAX_PRICE_AGE = keccak256(abi.encode("BUYBACK_MAX_PRICE_AGE"));
    // @dev key for the buyback withdrawable fees
    bytes32 public constant WITHDRAWABLE_BUYBACK_TOKEN_AMOUNT = keccak256(abi.encode("WITHDRAWABLE_BUYBACK_TOKEN_AMOUNT"));

    // @dev constant for user initiated cancel reason
    string public constant USER_INITIATED_CANCEL = "USER_INITIATED_CANCEL";

    // @dev function used to calculate fullKey for a given market parameter
    // @param baseKey the base key for the market parameter
    // @param data the additional data for the market parameter
    function getFullKey(bytes32 baseKey, bytes memory data) internal pure returns (bytes32) {
        if (data.length == 0) {
            return baseKey;
        }

        return keccak256(bytes.concat(baseKey, data));
    }

    // @dev key for the account deposit list
    // @param account the account for the list
    function accountDepositListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_DEPOSIT_LIST, account));
    }

    // @dev key for the account withdrawal list
    // @param account the account for the list
    function accountWithdrawalListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_WITHDRAWAL_LIST, account));
    }

    // @dev key for the account shift list
    // @param account the account for the list
    function accountShiftListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_SHIFT_LIST, account));
    }

    // @dev key for the account glv deposit list
    // @param account the account for the list
    function accountGlvDepositListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_GLV_DEPOSIT_LIST, account));
    }

    // @dev key for the account glv deposit list
    // @param account the account for the list
    function accountGlvWithdrawalListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_GLV_WITHDRAWAL_LIST, account));
    }

    // @dev key for the glv supported market list
    // @param glv the glv for the supported market list
    function glvSupportedMarketListKey(address glv) internal pure returns (bytes32) {
        return keccak256(abi.encode(GLV_SUPPORTED_MARKET_LIST, glv));
    }

    // @dev key for the account position list
    // @param account the account for the list
    function accountPositionListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_POSITION_LIST, account));
    }

    // @dev key for the account order list
    // @param account the account for the list
    function accountOrderListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_ORDER_LIST, account));
    }

    // @dev key for the subaccount list
    // @param account the account for the list
    function subaccountListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(SUBACCOUNT_LIST, account));
    }

    // @dev key for the auto cancel order list
    // @param position key the position key for the list
    function autoCancelOrderListKey(bytes32 positionKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(AUTO_CANCEL_ORDER_LIST, positionKey));
    }

    // @dev key for the claimable fee amount
    // @param market the market for the fee
    // @param token the token for the fee
    function claimableFeeAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(CLAIMABLE_FEE_AMOUNT, market, token));
    }

    // @dev key for the claimable ui fee amount
    // @param market the market for the fee
    // @param token the token for the fee
    // @param account the account that can claim the ui fee
    function claimableUiFeeAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(CLAIMABLE_UI_FEE_AMOUNT, market, token));
    }

    // @dev key for the claimable ui fee amount for account
    // @param market the market for the fee
    // @param token the token for the fee
    // @param account the account that can claim the ui fee
    function claimableUiFeeAmountKey(address market, address token, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(CLAIMABLE_UI_FEE_AMOUNT, market, token, account));
    }

    // @dev key for deposit gas limit
    // @param singleToken whether a single token or pair tokens are being deposited
    // @return key for deposit gas limit
    function depositGasLimitKey() internal pure returns (bytes32) {
        return DEPOSIT_GAS_LIMIT;
    }

    // @dev key for withdrawal gas limit
    // @return key for withdrawal gas limit
    function withdrawalGasLimitKey() internal pure returns (bytes32) {
        return WITHDRAWAL_GAS_LIMIT;
    }

    // @dev key for shift gas limit
    // @return key for shift gas limit
    function shiftGasLimitKey() internal pure returns (bytes32) {
        return SHIFT_GAS_LIMIT;
    }

    function glvDepositGasLimitKey() internal pure returns (bytes32) {
        return GLV_DEPOSIT_GAS_LIMIT;
    }

    function glvWithdrawalGasLimitKey() internal pure returns (bytes32) {
        return GLV_WITHDRAWAL_GAS_LIMIT;
    }

    function glvShiftGasLimitKey() internal pure returns (bytes32) {
        return GLV_SHIFT_GAS_LIMIT;
    }

    function glvPerMarketGasLimitKey() internal pure returns (bytes32) {
        return GLV_PER_MARKET_GAS_LIMIT;
    }

    // @dev key for single swap gas limit
    // @return key for single swap gas limit
    function singleSwapGasLimitKey() internal pure returns (bytes32) {
        return SINGLE_SWAP_GAS_LIMIT;
    }

    // @dev key for increase order gas limit
    // @return key for increase order gas limit
    function increaseOrderGasLimitKey() internal pure returns (bytes32) {
        return INCREASE_ORDER_GAS_LIMIT;
    }

    // @dev key for decrease order gas limit
    // @return key for decrease order gas limit
    function decreaseOrderGasLimitKey() internal pure returns (bytes32) {
        return DECREASE_ORDER_GAS_LIMIT;
    }

    // @dev key for swap order gas limit
    // @return key for swap order gas limit
    function swapOrderGasLimitKey() internal pure returns (bytes32) {
        return SWAP_ORDER_GAS_LIMIT;
    }

    function swapPathMarketFlagKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_PATH_MARKET_FLAG,
            market
        ));
    }

    // @dev key for whether create glv deposit is disabled
    // @param the create deposit module
    // @return key for whether create deposit is disabled
    function createGlvDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_GLV_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether cancel glv deposit is disabled
    // @param the cancel deposit module
    // @return key for whether cancel deposit is disabled
    function cancelGlvDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_GLV_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether execute glv deposit is disabled
    // @param the execute deposit module
    // @return key for whether execute deposit is disabled
    function executeGlvDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_GLV_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether create glv withdrawal is disabled
    // @param the create withdrawal module
    // @return key for whether create withdrawal is disabled
    function createGlvWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_GLV_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether cancel glv withdrawal is disabled
    // @param the cancel withdrawal module
    // @return key for whether cancel withdrawal is disabled
    function cancelGlvWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_GLV_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether execute glv withdrawal is disabled
    // @param the execute withdrawal module
    // @return key for whether execute withdrawal is disabled
    function executeGlvWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_GLV_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    function createGlvShiftFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_GLV_SHIFT_FEATURE_DISABLED,
            module
        ));
    }

    function executeGlvShiftFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_GLV_SHIFT_FEATURE_DISABLED,
            module
        ));
    }


    // @dev key for whether create deposit is disabled
    // @param the create deposit module
    // @return key for whether create deposit is disabled
    function createDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether cancel deposit is disabled
    // @param the cancel deposit module
    // @return key for whether cancel deposit is disabled
    function cancelDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether execute deposit is disabled
    // @param the execute deposit module
    // @return key for whether execute deposit is disabled
    function executeDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether create withdrawal is disabled
    // @param the create withdrawal module
    // @return key for whether create withdrawal is disabled
    function createWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether cancel withdrawal is disabled
    // @param the cancel withdrawal module
    // @return key for whether cancel withdrawal is disabled
    function cancelWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether execute withdrawal is disabled
    // @param the execute withdrawal module
    // @return key for whether execute withdrawal is disabled
    function executeWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether execute atomic withdrawal is disabled
    // @param the execute atomic withdrawal module
    // @return key for whether execute atomic withdrawal is disabled
    function executeAtomicWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_ATOMIC_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether create shift is disabled
    // @param the create shift module
    // @return key for whether create shift is disabled
    function createShiftFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_SHIFT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether cancel shift is disabled
    // @param the cancel shift module
    // @return key for whether cancel shift is disabled
    function cancelShiftFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_SHIFT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether execute shift is disabled
    // @param the execute shift module
    // @return key for whether execute shift is disabled
    function executeShiftFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_SHIFT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether create order is disabled
    // @param the create order module
    // @return key for whether create order is disabled
    function createOrderFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_ORDER_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether execute order is disabled
    // @param the execute order module
    // @return key for whether execute order is disabled
    function executeOrderFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_ORDER_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether execute adl is disabled
    // @param the execute adl module
    // @return key for whether execute adl is disabled
    function executeAdlFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_ADL_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether update order is disabled
    // @param the update order module
    // @return key for whether update order is disabled
    function updateOrderFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            UPDATE_ORDER_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether cancel order is disabled
    // @param the cancel order module
    // @return key for whether cancel order is disabled
    function cancelOrderFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_ORDER_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether claim funding fees is disabled
    // @param the claim funding fees module
    function claimFundingFeesFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIM_FUNDING_FEES_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether claim colltareral is disabled
    // @param the claim funding fees module
    function claimCollateralFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIM_COLLATERAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether claim affiliate rewards is disabled
    // @param the claim affiliate rewards module
    function claimAffiliateRewardsFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIM_AFFILIATE_REWARDS_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether claim ui fees is disabled
    // @param the claim ui fees module
    function claimUiFeesFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIM_UI_FEES_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether subaccounts are disabled
    // @param the subaccount module
    function subaccountFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SUBACCOUNT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for ui fee factor
    // @param account the fee receiver account
    // @return key for ui fee factor
    function uiFeeFactorKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            UI_FEE_FACTOR,
            account
        ));
    }

    // @dev key for whether an oracle provider is enabled
    // @param provider the oracle provider
    // @return key for whether an oracle provider is enabled
    function isOracleProviderEnabledKey(address provider) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            IS_ORACLE_PROVIDER_ENABLED,
            provider
        ));
    }

    // @dev key for whether an oracle provider is allowed to be used for atomic actions
    // @param provider the oracle provider
    // @return key for whether an oracle provider is allowed to be used for atomic actions
    function isAtomicOracleProviderKey(address provider) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            IS_ATOMIC_ORACLE_PROVIDER,
            provider
        ));
    }

    // @dev key for oracle timestamp adjustment
    // @param provider the oracle provider
    // @param token the token
    // @return key for oracle timestamp adjustment
    function oracleTimestampAdjustmentKey(address provider, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ORACLE_TIMESTAMP_ADJUSTMENT,
            provider,
            token
        ));
    }

    // @dev key for oracle provider for token
    // @param token the token
    // @return key for oracle provider for token
    function oracleProviderForTokenKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ORACLE_PROVIDER_FOR_TOKEN,
            token
        ));
    }

    // @dev key for gas to forward for token transfer
    // @param the token to check
    // @return key for gas to forward for token transfer
    function tokenTransferGasLimit(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TOKEN_TRANSFER_GAS_LIMIT,
            token
        ));
   }

   // @dev the default callback contract
   // @param account the user's account
   // @param market the address of the market
   // @param callbackContract the callback contract
   function savedCallbackContract(address account, address market) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           SAVED_CALLBACK_CONTRACT,
           account,
           market
       ));
   }

   // @dev the min collateral factor key
   // @param the market for the min collateral factor
   function minCollateralFactorKey(address market) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           MIN_COLLATERAL_FACTOR,
           market
       ));
   }

   // @dev the min collateral factor for open interest multiplier key
   // @param the market for the factor
   function minCollateralFactorForOpenInterestMultiplierKey(address market, bool isLong) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER,
           market,
           isLong
       ));
   }

   // @dev the key for the virtual token id
   // @param the token to get the virtual id for
   function virtualTokenIdKey(address token) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           VIRTUAL_TOKEN_ID,
           token
       ));
   }

   // @dev the key for the virtual market id
   // @param the market to get the virtual id for
   function virtualMarketIdKey(address market) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           VIRTUAL_MARKET_ID,
           market
       ));
   }

   // @dev the key for the virtual inventory for positions
   // @param the virtualTokenId the virtual token id
   function virtualInventoryForPositionsKey(bytes32 virtualTokenId) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           VIRTUAL_INVENTORY_FOR_POSITIONS,
           virtualTokenId
       ));
   }

   // @dev the key for the virtual inventory for swaps
   // @param the virtualMarketId the virtual market id
   // @param the token to check the inventory for
   function virtualInventoryForSwapsKey(bytes32 virtualMarketId, bool isLongToken) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           VIRTUAL_INVENTORY_FOR_SWAPS,
           virtualMarketId,
           isLongToken
       ));
   }

    // @dev key for position impact factor
    // @param market the market address to check
    // @param isPositive whether the impact is positive or negative
    // @return key for position impact factor
    function positionImpactFactorKey(address market, bool isPositive) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_IMPACT_FACTOR,
            market,
            isPositive
        ));
   }

    // @dev key for position impact exponent factor
    // @param market the market address to check
    // @return key for position impact exponent factor
    function positionImpactExponentFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_IMPACT_EXPONENT_FACTOR,
            market
        ));
    }

    // @dev key for the max position impact factor
    // @param market the market address to check
    // @return key for the max position impact factor
    function maxPositionImpactFactorKey(address market, bool isPositive) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_POSITION_IMPACT_FACTOR,
            market,
            isPositive
        ));
    }

    // @dev key for the max position impact factor for liquidations
    // @param market the market address to check
    // @return key for the max position impact factor
    function maxPositionImpactFactorForLiquidationsKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS,
            market
        ));
    }

    // @dev key for position fee factor
    // @param market the market address to check
    // @param forPositiveImpact whether the fee is for an action that has a positive price impact
    // @return key for position fee factor
    function positionFeeFactorKey(address market, bool forPositiveImpact) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_FEE_FACTOR,
            market,
            forPositiveImpact
        ));
    }

    // @dev key for pro trader's tier
    function proTraderTierKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PRO_TRADER_TIER,
            account
        ));
    }


    // @dev key for pro discount factor for specific tier
    function proDiscountFactorKey(uint256 proTier) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PRO_DISCOUNT_FACTOR,
            proTier
        ));
    }

    // @dev key for liquidation fee factor
    // @param market the market address to check
    // @param forPositiveImpact whether the fee is for an action that has a positive price impact
    // @return key for liquidation fee factor
    function liquidationFeeFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            LIQUIDATION_FEE_FACTOR,
            market
        ));
    }

    // @dev key for swap impact factor
    // @param market the market address to check
    // @param isPositive whether the impact is positive or negative
    // @return key for swap impact factor
    function swapImpactFactorKey(address market, bool isPositive) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_IMPACT_FACTOR,
            market,
            isPositive
        ));
    }

    // @dev key for swap impact exponent factor
    // @param market the market address to check
    // @return key for swap impact exponent factor
    function swapImpactExponentFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_IMPACT_EXPONENT_FACTOR,
            market
        ));
    }


    // @dev key for swap fee factor
    // @param market the market address to check
    // @return key for swap fee factor
    function swapFeeFactorKey(address market, bool forPositiveImpact) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_FEE_FACTOR,
            market,
            forPositiveImpact
        ));
    }

    // @dev key for atomic swap fee factor
    // @param market the market address to check
    // @return key for atomic swap fee factor
    function atomicSwapFeeFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ATOMIC_SWAP_FEE_FACTOR,
            market
        ));
    }

    function depositFeeFactorKey(address market, bool forPositiveImpact) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            DEPOSIT_FEE_FACTOR,
            market,
            forPositiveImpact
        ));
    }

    function withdrawalFeeFactorKey(address market, bool forPositiveImpact) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            WITHDRAWAL_FEE_FACTOR,
            market,
            forPositiveImpact
        ));
    }

    // @dev key for oracle type
    // @param token the token to check
    // @return key for oracle type
    function oracleTypeKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ORACLE_TYPE,
            token
        ));
    }

    // @dev key for open interest
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to check the long or short open interest
    // @return key for open interest
    function openInterestKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OPEN_INTEREST,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for open interest in tokens
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to check the long or short open interest
    // @return key for open interest in tokens
    function openInterestInTokensKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OPEN_INTEREST_IN_TOKENS,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for collateral sum for a market
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to check the long or short open interest
    // @return key for collateral sum
    function collateralSumKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            COLLATERAL_SUM,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for amount of tokens in a market's pool
    // @param market the market to check
    // @param token the token to check
    // @return key for amount of tokens in a market's pool
    function poolAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POOL_AMOUNT,
            market,
            token
        ));
    }

    // @dev the key for the max amount of pool tokens
    // @param market the market for the pool
    // @param token the token for the pool
    function maxPoolAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_POOL_AMOUNT,
            market,
            token
        ));
    }

    // @dev the key for the max usd of pool tokens for deposits
    // @param market the market for the pool
    // @param token the token for the pool
    function maxPoolUsdForDepositKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_POOL_USD_FOR_DEPOSIT,
            market,
            token
        ));
    }

    // @dev the key for the max open interest
    // @param market the market for the pool
    // @param isLong whether the key is for the long or short side
    function maxOpenInterestKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_OPEN_INTEREST,
            market,
            isLong
        ));
    }

    // @dev key for amount of tokens in a market's position impact pool
    // @param market the market to check
    // @return key for amount of tokens in a market's position impact pool
    function positionImpactPoolAmountKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_IMPACT_POOL_AMOUNT,
            market
        ));
    }

    // @dev key for min amount of tokens in a market's position impact pool
    // @param market the market to check
    // @return key for min amount of tokens in a market's position impact pool
    function minPositionImpactPoolAmountKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MIN_POSITION_IMPACT_POOL_AMOUNT,
            market
        ));
    }

    // @dev key for position impact pool distribution rate
    // @param market the market to check
    // @return key for position impact pool distribution rate
    function positionImpactPoolDistributionRateKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_IMPACT_POOL_DISTRIBUTION_RATE,
            market
        ));
    }

    // @dev key for position impact pool distributed at
    // @param market the market to check
    // @return key for position impact pool distributed at
    function positionImpactPoolDistributedAtKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_IMPACT_POOL_DISTRIBUTED_AT,
            market
        ));
    }

    // @dev key for amount of tokens in a market's swap impact pool
    // @param market the market to check
    // @param token the token to check
    // @return key for amount of tokens in a market's swap impact pool
    function swapImpactPoolAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_IMPACT_POOL_AMOUNT,
            market,
            token
        ));
    }

    // @dev key for reserve factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for reserve factor
    function reserveFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RESERVE_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for open interest reserve factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for open interest reserve factor
    function openInterestReserveFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OPEN_INTEREST_RESERVE_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for max pnl factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for max pnl factor
    function maxPnlFactorKey(bytes32 pnlFactorType, address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_PNL_FACTOR,
            pnlFactorType,
            market,
            isLong
        ));
    }

    // @dev the key for min PnL factor after ADL
    // @param market the market for the pool
    // @param isLong whether the key is for the long or short side
    function minPnlFactorAfterAdlKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MIN_PNL_FACTOR_AFTER_ADL,
            market,
            isLong
        ));
    }

    // @dev key for latest adl time
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for latest adl time
    function latestAdlAtKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            LATEST_ADL_AT,
            market,
            isLong
        ));
    }

    // @dev key for whether adl is enabled
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for whether adl is enabled
    function isAdlEnabledKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            IS_ADL_ENABLED,
            market,
            isLong
        ));
    }

    // @dev key for funding factor
    // @param market the market to check
    // @return key for funding factor
    function fundingFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_FACTOR,
            market
        ));
    }

    // @dev the key for funding exponent
    // @param market the market for the pool
    function fundingExponentFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_EXPONENT_FACTOR,
            market
        ));
    }

    // @dev the key for saved funding factor
    // @param market the market for the pool
    function savedFundingFactorPerSecondKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SAVED_FUNDING_FACTOR_PER_SECOND,
            market
        ));
    }

    // @dev the key for funding increase factor
    // @param market the market for the pool
    function fundingIncreaseFactorPerSecondKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_INCREASE_FACTOR_PER_SECOND,
            market
        ));
    }

    // @dev the key for funding decrease factor
    // @param market the market for the pool
    function fundingDecreaseFactorPerSecondKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_DECREASE_FACTOR_PER_SECOND,
            market
        ));
    }

    // @dev the key for min funding factor
    // @param market the market for the pool
    function minFundingFactorPerSecondKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MIN_FUNDING_FACTOR_PER_SECOND,
            market
        ));
    }

    // @dev the key for max funding factor
    // @param market the market for the pool
    function maxFundingFactorPerSecondKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_FUNDING_FACTOR_PER_SECOND,
            market
        ));
    }

    // @dev the key for threshold for stable funding
    // @param market the market for the pool
    function thresholdForStableFundingKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            THRESHOLD_FOR_STABLE_FUNDING,
            market
        ));
    }

    // @dev the key for threshold for decreasing funding
    // @param market the market for the pool
    function thresholdForDecreaseFundingKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            THRESHOLD_FOR_DECREASE_FUNDING,
            market
        ));
    }

    // @dev key for funding fee amount per size
    // @param market the market to check
    // @param collateralToken the collateralToken to get the key for
    // @param isLong whether to get the key for the long or short side
    // @return key for funding fee amount per size
    function fundingFeeAmountPerSizeKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_FEE_AMOUNT_PER_SIZE,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for claimabel funding amount per size
    // @param market the market to check
    // @param collateralToken the collateralToken to get the key for
    // @param isLong whether to get the key for the long or short side
    // @return key for claimable funding amount per size
    function claimableFundingAmountPerSizeKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_FUNDING_AMOUNT_PER_SIZE,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for when funding was last updated
    // @param market the market to check
    // @return key for when funding was last updated
    function fundingUpdatedAtKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_UPDATED_AT,
            market
        ));
    }

    // @dev key for claimable funding amount
    // @param market the market to check
    // @param token the token to check
    // @return key for claimable funding amount
    function claimableFundingAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_FUNDING_AMOUNT,
            market,
            token
        ));
    }

    // @dev key for claimable funding amount by account
    // @param market the market to check
    // @param token the token to check
    // @param account the account to check
    // @return key for claimable funding amount
    function claimableFundingAmountKey(address market, address token, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_FUNDING_AMOUNT,
            market,
            token,
            account
        ));
    }

    // @dev key for claimable collateral amount
    // @param market the market to check
    // @param token the token to check
    // @param account the account to check
    // @param timeKey the time key for the claimable amount
    // @return key for claimable funding amount
    function claimableCollateralAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_COLLATERAL_AMOUNT,
            market,
            token
        ));
    }

    // @dev key for claimable collateral amount for a timeKey for an account
    // @param market the market to check
    // @param token the token to check
    // @param account the account to check
    // @param timeKey the time key for the claimable amount
    // @return key for claimable funding amount
    function claimableCollateralAmountKey(address market, address token, uint256 timeKey, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_COLLATERAL_AMOUNT,
            market,
            token,
            timeKey,
            account
        ));
    }

    // @dev key for claimable collateral factor for a timeKey
    // @param market the market to check
    // @param token the token to check
    // @param timeKey the time key for the claimable amount
    // @return key for claimable funding amount
    function claimableCollateralFactorKey(address market, address token, uint256 timeKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_COLLATERAL_FACTOR,
            market,
            token,
            timeKey
        ));
    }

    // @dev key for claimable collateral factor for a timeKey for an account
    // @param market the market to check
    // @param token the token to check
    // @param timeKey the time key for the claimable amount
    // @param account the account to check
    // @return key for claimable funding amount
    function claimableCollateralFactorKey(address market, address token, uint256 timeKey, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_COLLATERAL_FACTOR,
            market,
            token,
            timeKey,
            account
        ));
    }

    // @dev key for claimable collateral factor
    // @param market the market to check
    // @param token the token to check
    // @param account the account to check
    // @param timeKey the time key for the claimable amount
    // @return key for claimable funding amount
    function claimedCollateralAmountKey(address market, address token, uint256 timeKey, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMED_COLLATERAL_AMOUNT,
            market,
            token,
            timeKey,
            account
        ));
    }

    // @dev key for optimal usage factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for optimal usage factor
    function optimalUsageFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OPTIMAL_USAGE_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for base borrowing factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for base borrowing factor
    function baseBorrowingFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BASE_BORROWING_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for above optimal usage borrowing factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for above optimal usage borrowing factor
    function aboveOptimalUsageBorrowingFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ABOVE_OPTIMAL_USAGE_BORROWING_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for borrowing factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for borrowing factor
    function borrowingFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BORROWING_FACTOR,
            market,
            isLong
        ));
    }

    // @dev the key for borrowing exponent
    // @param market the market for the pool
    // @param isLong whether to get the key for the long or short side
    function borrowingExponentFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BORROWING_EXPONENT_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for cumulative borrowing factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for cumulative borrowing factor
    function cumulativeBorrowingFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CUMULATIVE_BORROWING_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for cumulative borrowing factor updated at
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for cumulative borrowing factor updated at
    function cumulativeBorrowingFactorUpdatedAtKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CUMULATIVE_BORROWING_FACTOR_UPDATED_AT,
            market,
            isLong
        ));
    }

    // @dev key for total borrowing amount
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for total borrowing amount
    function totalBorrowingKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TOTAL_BORROWING,
            market,
            isLong
        ));
    }

    // @dev key for affiliate reward amount
    // @param market the market to check
    // @param token the token to get the key for
    // @param account the account to get the key for
    // @return key for affiliate reward amount
    function affiliateRewardKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AFFILIATE_REWARD,
            market,
            token
        ));
    }

    function minAffiliateRewardFactorKey(uint256 referralTierLevel) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MIN_AFFILIATE_REWARD_FACTOR,
            referralTierLevel
        ));
    }

    function maxAllowedSubaccountActionCountKey(address account, address subaccount, bytes32 actionType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_ALLOWED_SUBACCOUNT_ACTION_COUNT,
            account,
            subaccount,
            actionType
        ));
    }

    function subaccountExpiresAtKey(address account, address subaccount, bytes32 actionType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SUBACCOUNT_EXPIRES_AT,
            account,
            subaccount,
            actionType
        ));
    }

    function subaccountActionCountKey(address account, address subaccount, bytes32 actionType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SUBACCOUNT_ACTION_COUNT,
            account,
            subaccount,
            actionType
        ));
    }

    function subaccountAutoTopUpAmountKey(address account, address subaccount) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SUBACCOUNT_AUTO_TOP_UP_AMOUNT,
            account,
            subaccount
        ));
    }

    // @dev key for affiliate reward amount for an account
    // @param market the market to check
    // @param token the token to get the key for
    // @param account the account to get the key for
    // @return key for affiliate reward amount
    function affiliateRewardKey(address market, address token, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AFFILIATE_REWARD,
            market,
            token,
            account
        ));
    }

    // @dev key for is market disabled
    // @param market the market to check
    // @return key for is market disabled
    function isMarketDisabledKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            IS_MARKET_DISABLED,
            market
        ));
    }

    // @dev key for min market tokens for first deposit
    // @param market the market to check
    // @return key for min market tokens for first deposit
    function minMarketTokensForFirstDepositKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MIN_MARKET_TOKENS_FOR_FIRST_DEPOSIT,
            market
        ));
    }

    // @dev key for price feed address
    // @param token the token to get the key for
    // @return key for price feed address
    function priceFeedKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PRICE_FEED,
            token
        ));
    }

    // @dev key for data stream feed ID
    // @param token the token to get the key for
    // @return key for data stream feed ID
    function dataStreamIdKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            DATA_STREAM_ID,
            token
        ));
    }

    // @dev key for data stream feed multiplier
    // @param token the token to get the key for
    // @return key for data stream feed multiplier
    function dataStreamMultiplierKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            DATA_STREAM_MULTIPLIER,
            token
        ));
    }

    function dataStreamSpreadReductionFactorKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            DATA_STREAM_SPREAD_REDUCTION_FACTOR,
            token
        ));
    }

    // @dev key for price feed multiplier
    // @param token the token to get the key for
    // @return key for price feed multiplier
    function priceFeedMultiplierKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PRICE_FEED_MULTIPLIER,
            token
        ));
    }

    function priceFeedHeartbeatDurationKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PRICE_FEED_HEARTBEAT_DURATION,
            token
        ));
    }

    // @dev key for stable price value
    // @param token the token to get the key for
    // @return key for stable price value
    function stablePriceKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            STABLE_PRICE,
            token
        ));
    }

    // @dev key for fee distributor swap token index
    // @param orderKey the swap order key
    // @return key for fee distributor swap token index
    function feeDistributorSwapTokenIndexKey(bytes32 orderKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FEE_DISTRIBUTOR_SWAP_TOKEN_INDEX,
            orderKey
        ));
    }

    // @dev key for fee distributor swap fee batch key
    // @param orderKey the swap order key
    // @return key for fee distributor swap fee batch key
    function feeDistributorSwapFeeBatchKey(bytes32 orderKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FEE_DISTRIBUTOR_SWAP_FEE_BATCH,
            orderKey
        ));
    }

    // @dev key for max market token balance usd
    // it is used to limit amount of funds deposited into each market
    function glvMaxMarketTokenBalanceUsdKey(address glv, address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(GLV_MAX_MARKET_TOKEN_BALANCE_USD, glv, market));
    }

    // @dev key for max market token balance amount
    // it is used to limit amount of funds deposited into each market
    function glvMaxMarketTokenBalanceAmountKey(address glv, address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(GLV_MAX_MARKET_TOKEN_BALANCE_AMOUNT, glv, market));
    }

    // @dev key for is glv market disabled
    function isGlvMarketDisabledKey(address glv, address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            IS_GLV_MARKET_DISABLED,
            glv,
            market
        ));
    }

    // @dev key for max allowed price impact for glv shifts
    // if effective price impact exceeds max price impact then glv shift fails
    function glvShiftMaxPriceImpactFactorKey(address glv) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            GLV_SHIFT_MAX_PRICE_IMPACT_FACTOR,
            glv
        ));
    }

    // @dev key for time when glv shift was executed last
    // used to validate glv shifts are not executed too frequently
    function glvShiftLastExecutedAtKey(address glv) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            GLV_SHIFT_LAST_EXECUTED_AT,
            glv
        ));
    }

    // @dev key for min time interval between glv shifts in seconds
    function glvShiftMinIntervalKey(address glv) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            GLV_SHIFT_MIN_INTERVAL,
            glv
        ));
    }

    function minGlvTokensForFirstGlvDepositKey(address glv) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MIN_GLV_TOKENS_FOR_FIRST_DEPOSIT,
            glv
        ));
    }

    // @dev key for whether the sync config feature is disabled
    // @param module the sync config module
    // @return key for sync config feature disabled
    function syncConfigFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SYNC_CONFIG_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether sync config updates are disabled for a market
    // @param market the market to check
    // @return key for sync config market disabled
    function syncConfigMarketDisabledKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SYNC_CONFIG_MARKET_DISABLED,
            market
        ));
    }

    // @dev key for whether sync config updates are disabled for a parameter
    // @param parameter the parameter to check
    // @return key for sync config parameter disabled
    function syncConfigParameterDisabledKey(string memory parameter) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SYNC_CONFIG_PARAMETER_DISABLED,
            parameter
        ));
    }

    // @dev key for whether sync config updates are disabled for a market parameter
    // @param market the market to check
    // @param parameter the parameter to check
    // @return key for sync config market parameter disabled
    function syncConfigMarketParameterDisabledKey(address market, string memory parameter) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SYNC_CONFIG_MARKET_PARAMETER_DISABLED,
            market,
            parameter
        ));
    }

    // @dev key for whether a sync config update is completed
    // @param updateId the update id to check
    // @return key for sync config market update completed
    function syncConfigUpdateCompletedKey(uint256 updateId) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SYNC_CONFIG_UPDATE_COMPLETED,
            updateId
        ));
    }

    // @dev key for the latest sync config update that was completed
    // @return key for sync config latest update id
    function syncConfigLatestUpdateIdKey() internal pure returns (bytes32) {
        return SYNC_CONFIG_LATEST_UPDATE_ID;
    }

    // @dev key for the contributor token amount
    // @param account the contributor account
    // @param token the contributor token
    // @return key for the contributor token amount
    function contributorTokenAmountKey(address account, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CONTRIBUTOR_TOKEN_AMOUNT,
            account,
            token
        ));
    }

    // @dev key for the max total contributor token amount
    // @param token the contributor token
    // @return key for the max contributor token amount
    function maxTotalContributorTokenAmountKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_TOTAL_CONTRIBUTOR_TOKEN_AMOUNT,
            token
        ));
    }

    // @dev key for the contributor token vault
    // @param token the contributor token
    // @return key for the contributor token vault
    function contributorTokenVaultKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CONTRIBUTOR_TOKEN_VAULT,
            token
        ));
    }

    // @dev key for the buyback batch amount
    // @param token the token for which to retrieve batch amount (GMX or WNT)
    // @return key for buyback batch amount for a given token
    function buybackBatchAmountKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BUYBACK_BATCH_AMOUNT,
            token
        ));
    }

    // @dev key for the buyback available fee amount
    // @param feeToken the token in which the fees are denominated
    // @param swapToken the token for which fees are accumulated (GMX or WNT)
    // @return key for buyback available fee amount for a given token and feeToken
    function buybackAvailableFeeAmountKey(address feeToken, address swapToken) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BUYBACK_AVAILABLE_FEE_AMOUNT,
            feeToken,
            swapToken
        ));
    }

    // @dev key for the buyback withdrawable fee amount
    // @param buybackToken the token that was bought back
    // @return key for the buyback withdrawable fee amount
    function withdrawableBuybackTokenAmountKey(address buybackToken) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            WITHDRAWABLE_BUYBACK_TOKEN_AMOUNT,
            buybackToken
        ));
    }

    // @dev key for the buyback gmx fee factor
    // @param version the version for which to retrieve the fee numerator
    // @return key for buyback gmx fee factor for a given version
    function buybackGmxFactorKey(uint256 version) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BUYBACK_GMX_FACTOR,
            version
        ));
    }

    // @dev key for the buyback max price impact factor
    // @param token the token for which to retrieve the max price impact factor key
    // @return key for buyback max price impact factor for a given token
    function buybackMaxPriceImpactFactorKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BUYBACK_MAX_PRICE_IMPACT_FACTOR,
            token
        ));
    }
}
