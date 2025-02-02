import { hashString, hashData } from "./hash";

export const WNT = hashString("WNT");
export const NONCE = hashString("NONCE");

export const FEE_RECEIVER = hashString("FEE_RECEIVER");
export const HOLDING_ADDRESS = hashString("HOLDING_ADDRESS");
export const SEQUENCER_GRACE_DURATION = hashString("SEQUENCER_GRACE_DURATION");
export const IN_STRICT_PRICE_FEED_MODE = hashString("IN_STRICT_PRICE_FEED_MODE");

export const MIN_HANDLE_EXECUTION_ERROR_GAS = hashString("MIN_HANDLE_EXECUTION_ERROR_GAS");
export const MIN_ADDITIONAL_GAS_FOR_EXECUTION = hashString("MIN_ADDITIONAL_GAS_FOR_EXECUTION");
export const MIN_HANDLE_EXECUTION_ERROR_GAS_TO_FORWARD = hashString("MIN_HANDLE_EXECUTION_ERROR_GAS_TO_FORWARD");
export const REFUND_EXECUTION_FEE_GAS_LIMIT = hashString("REFUND_EXECUTION_FEE_GAS_LIMIT");

export const MAX_LEVERAGE = hashString("MAX_LEVERAGE");

export const MARKET_LIST = hashString("MARKET_LIST");

export const DEPOSIT_LIST = hashString("DEPOSIT_LIST");
export const ACCOUNT_DEPOSIT_LIST = hashString("ACCOUNT_DEPOSIT_LIST");

export const GLV_LIST = hashString("GLV_LIST");

export const GLV_DEPOSIT_LIST = hashString("GLV_DEPOSIT_LIST");
export const ACCOUNT_GLV_DEPOSIT_LIST = hashString("ACCOUNT_GLV_DEPOSIT_LIST");

export const WITHDRAWAL_LIST = hashString("WITHDRAWAL_LIST");
export const ACCOUNT_WITHDRAWAL_LIST = hashString("ACCOUNT_WITHDRAWAL_LIST");

export const GLV_WITHDRAWAL_LIST = hashString("GLV_WITHDRAWAL_LIST");
export const ACCOUNT_GLV_WITHDRAWAL_LIST = hashString("ACCOUNT_GLV_WITHDRAWAL_LIST");

export const SHIFT_LIST = hashString("SHIFT_LIST");
export const ACCOUNT_SHIFT_LIST = hashString("ACCOUNT_SHIFT_LIST");

export const GLV_SHIFT_LIST = hashString("GLV_SHIFT_LIST");

export const POSITION_LIST = hashString("POSITION_LIST");
export const ACCOUNT_POSITION_LIST = hashString("ACCOUNT_POSITION_LIST");

export const ORDER_LIST = hashString("ORDER_LIST");
export const ACCOUNT_ORDER_LIST = hashString("ACCOUNT_ORDER_LIST");

export const SUBACCOUNT_LIST = hashString("SUBACCOUNT_LIST");

export const AUTO_CANCEL_ORDER_LIST = hashString("AUTO_CANCEL_ORDER_LIST");

export const CREATE_DEPOSIT_FEATURE_DISABLED = hashString("CREATE_DEPOSIT_FEATURE_DISABLED");
export const CANCEL_DEPOSIT_FEATURE_DISABLED = hashString("CANCEL_DEPOSIT_FEATURE_DISABLED");
export const EXECUTE_DEPOSIT_FEATURE_DISABLED = hashString("EXECUTE_DEPOSIT_FEATURE_DISABLED");

export const CREATE_ORDER_FEATURE_DISABLED = hashString("CREATE_ORDER_FEATURE_DISABLED");
export const EXECUTE_ORDER_FEATURE_DISABLED = hashString("EXECUTE_ORDER_FEATURE_DISABLED");
export const EXECUTE_ADL_FEATURE_DISABLED = hashString("EXECUTE_ADL_FEATURE_DISABLED");
export const UPDATE_ORDER_FEATURE_DISABLED = hashString("UPDATE_ORDER_FEATURE_DISABLED");
export const CANCEL_ORDER_FEATURE_DISABLED = hashString("CANCEL_ORDER_FEATURE_DISABLED");

export const CREATE_WITHDRAWAL_FEATURE_DISABLED = hashString("CREATE_WITHDRAWAL_FEATURE_DISABLED");
export const CANCEL_WITHDRAWAL_FEATURE_DISABLED = hashString("CANCEL_WITHDRAWAL_FEATURE_DISABLED");
export const EXECUTE_WITHDRAWAL_FEATURE_DISABLED = hashString("EXECUTE_WITHDRAWAL_FEATURE_DISABLED");
export const EXECUTE_ATOMIC_WITHDRAWAL_FEATURE_DISABLED = hashString("EXECUTE_ATOMIC_WITHDRAWAL_FEATURE_DISABLED");

export const CREATE_SHIFT_FEATURE_DISABLED = hashString("CREATE_SHIFT_FEATURE_DISABLED");
export const EXECUTE_SHIFT_FEATURE_DISABLED = hashString("EXECUTE_SHIFT_FEATURE_DISABLED");
export const CANCEL_SHIFT_FEATURE_DISABLED = hashString("CANCEL_SHIFT_FEATURE_DISABLED");

export const CREATE_GLV_DEPOSIT_FEATURE_DISABLED = hashString("CREATE_GLV_DEPOSIT_FEATURE_DISABLED");

export const CLAIMABLE_FEE_AMOUNT = hashString("CLAIMABLE_FEE_AMOUNT");
export const CLAIMABLE_FUNDING_AMOUNT = hashString("CLAIMABLE_FUNDING_AMOUNT");
export const CLAIMABLE_COLLATERAL_AMOUNT = hashString("CLAIMABLE_COLLATERAL_AMOUNT");
export const CLAIMABLE_COLLATERAL_FACTOR = hashString("CLAIMABLE_COLLATERAL_FACTOR");
export const CLAIMABLE_COLLATERAL_REDUCTION_FACTOR = hashString("CLAIMABLE_COLLATERAL_REDUCTION_FACTOR");
export const CLAIMABLE_COLLATERAL_TIME_DIVISOR = hashString("CLAIMABLE_COLLATERAL_TIME_DIVISOR");
export const CLAIMABLE_COLLATERAL_DELAY = hashString("CLAIMABLE_COLLATERAL_DELAY");

export const CLAIMABLE_UI_FEE_AMOUNT = hashString("CLAIMABLE_UI_FEE_AMOUNT");
export const AFFILIATE_REWARD = hashString("AFFILIATE_REWARD");
export const MAX_UI_FEE_FACTOR = hashString("MAX_UI_FEE_FACTOR");
export const MIN_AFFILIATE_REWARD_FACTOR = hashString("MIN_AFFILIATE_REWARD_FACTOR");

export const MAX_AUTO_CANCEL_ORDERS = hashString("MAX_AUTO_CANCEL_ORDERS");
export const MAX_TOTAL_CALLBACK_GAS_LIMIT_FOR_AUTO_CANCEL_ORDERS = hashString(
  "MAX_TOTAL_CALLBACK_GAS_LIMIT_FOR_AUTO_CANCEL_ORDERS"
);

export const IS_MARKET_DISABLED = hashString("IS_MARKET_DISABLED");
export const MAX_SWAP_PATH_LENGTH = hashString("MAX_SWAP_PATH_LENGTH");
export const MIN_MARKET_TOKENS_FOR_FIRST_DEPOSIT = hashString("MIN_MARKET_TOKENS_FOR_FIRST_DEPOSIT");

export const MIN_ORACLE_BLOCK_CONFIRMATIONS = hashString("MIN_ORACLE_BLOCK_CONFIRMATIONS");
export const MAX_ORACLE_PRICE_AGE = hashString("MAX_ORACLE_PRICE_AGE");
export const MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR = hashString("MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR");
export const MIN_ORACLE_SIGNERS = hashString("MIN_ORACLE_SIGNERS");
export const MAX_ORACLE_TIMESTAMP_RANGE = hashString("MAX_ORACLE_TIMESTAMP_RANGE");
export const IS_ORACLE_PROVIDER_ENABLED = hashString("IS_ORACLE_PROVIDER_ENABLED");
export const IS_ATOMIC_ORACLE_PROVIDER = hashString("IS_ATOMIC_ORACLE_PROVIDER");
export const CHAINLINK_PAYMENT_TOKEN = hashString("CHAINLINK_PAYMENT_TOKEN");

export const MIN_COLLATERAL_FACTOR = hashString("MIN_COLLATERAL_FACTOR");
export const MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER = hashString(
  "MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER"
);
export const MIN_COLLATERAL_USD = hashString("MIN_COLLATERAL_USD");
export const MIN_POSITION_SIZE_USD = hashString("MIN_POSITION_SIZE_USD");

export const SWAP_FEE_RECEIVER_FACTOR = hashString("SWAP_FEE_RECEIVER_FACTOR");

export const TOKEN_TRANSFER_GAS_LIMIT = hashString("TOKEN_TRANSFER_GAS_LIMIT");
export const NATIVE_TOKEN_TRANSFER_GAS_LIMIT = hashString("NATIVE_TOKEN_TRANSFER_GAS_LIMIT");

export const MAX_CALLBACK_GAS_LIMIT = hashString("MAX_CALLBACK_GAS_LIMIT");

export const REQUEST_EXPIRATION_TIME = hashString("REQUEST_EXPIRATION_TIME");

export const PRICE_FEED = hashString("PRICE_FEED");
export const PRICE_FEED_MULTIPLIER = hashString("PRICE_FEED_MULTIPLIER");
export const PRICE_FEED_HEARTBEAT_DURATION = hashString("PRICE_FEED_HEARTBEAT_DURATION");
export const DATA_STREAM_ID = hashString("DATA_STREAM_ID");
export const DATA_STREAM_MULTIPLIER = hashString("DATA_STREAM_MULTIPLIER");
export const DATA_STREAM_SPREAD_REDUCTION_FACTOR = hashString("DATA_STREAM_SPREAD_REDUCTION_FACTOR");
export const STABLE_PRICE = hashString("STABLE_PRICE");

export const ORACLE_TYPE = hashString("ORACLE_TYPE");
export const ORACLE_PROVIDER_FOR_TOKEN = hashString("ORACLE_PROVIDER_FOR_TOKEN");
export const ORACLE_TIMESTAMP_ADJUSTMENT = hashString("ORACLE_TIMESTAMP_ADJUSTMENT");

export const OPEN_INTEREST = hashString("OPEN_INTEREST");
export const OPEN_INTEREST_IN_TOKENS = hashString("OPEN_INTEREST_IN_TOKENS");

export const COLLATERAL_SUM = hashString("COLLATERAL_SUM");
export const POOL_AMOUNT = hashString("POOL_AMOUNT");
export const MAX_POOL_AMOUNT = hashString("MAX_POOL_AMOUNT");
export const MAX_POOL_USD_FOR_DEPOSIT = hashString("MAX_POOL_USD_FOR_DEPOSIT");
export const MAX_OPEN_INTEREST = hashString("MAX_OPEN_INTEREST");

export const POSITION_IMPACT_POOL_AMOUNT = hashString("POSITION_IMPACT_POOL_AMOUNT");
export const PENDING_IMPACT_AMOUNT = hashString("PENDING_IMPACT_AMOUNT");
export const MIN_POSITION_IMPACT_POOL_AMOUNT = hashString("MIN_POSITION_IMPACT_POOL_AMOUNT");
export const POSITION_IMPACT_POOL_DISTRIBUTION_RATE = hashString("POSITION_IMPACT_POOL_DISTRIBUTION_RATE");
export const POSITION_IMPACT_POOL_DISTRIBUTED_AT = hashString("POSITION_IMPACT_POOL_DISTRIBUTED_AT");

export const SWAP_IMPACT_POOL_AMOUNT = hashString("SWAP_IMPACT_POOL_AMOUNT");

export const POSITION_FEE_RECEIVER_FACTOR = hashString("POSITION_FEE_RECEIVER_FACTOR");
export const LIQUIDATION_FEE_RECEIVER_FACTOR = hashString("LIQUIDATION_FEE_RECEIVER_FACTOR");
export const BORROWING_FEE_RECEIVER_FACTOR = hashString("BORROWING_FEE_RECEIVER_FACTOR");

export const SWAP_FEE_FACTOR = hashString("SWAP_FEE_FACTOR");
export const DEPOSIT_FEE_FACTOR = hashString("DEPOSIT_FEE_FACTOR");
export const WITHDRAWAL_FEE_FACTOR = hashString("WITHDRAWAL_FEE_FACTOR");
export const ATOMIC_SWAP_FEE_FACTOR = hashString("ATOMIC_SWAP_FEE_FACTOR");
export const SWAP_IMPACT_FACTOR = hashString("SWAP_IMPACT_FACTOR");
export const SWAP_IMPACT_EXPONENT_FACTOR = hashString("SWAP_IMPACT_EXPONENT_FACTOR");

export const POSITION_IMPACT_FACTOR = hashString("POSITION_IMPACT_FACTOR");
export const POSITION_IMPACT_EXPONENT_FACTOR = hashString("POSITION_IMPACT_EXPONENT_FACTOR");
export const MAX_POSITION_IMPACT_FACTOR = hashString("MAX_POSITION_IMPACT_FACTOR");
export const MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS = hashString("MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS");
export const POSITION_FEE_FACTOR = hashString("POSITION_FEE_FACTOR");
export const LIQUIDATION_FEE_FACTOR = hashString("LIQUIDATION_FEE_FACTOR");
export const PRO_TRADER_TIER = hashString("PRO_TRADER_TIER");
export const PRO_DISCOUNT_FACTOR = hashString("PRO_DISCOUNT_FACTOR");

export const RESERVE_FACTOR = hashString("RESERVE_FACTOR");
export const OPEN_INTEREST_RESERVE_FACTOR = hashString("OPEN_INTEREST_RESERVE_FACTOR");

export const MAX_PNL_FACTOR = hashString("MAX_PNL_FACTOR");
export const MAX_PNL_FACTOR_FOR_TRADERS = hashString("MAX_PNL_FACTOR_FOR_TRADERS");
export const MAX_PNL_FACTOR_FOR_ADL = hashString("MAX_PNL_FACTOR_FOR_ADL");
export const MIN_PNL_FACTOR_AFTER_ADL = hashString("MIN_PNL_FACTOR_AFTER_ADL");
export const MAX_PNL_FACTOR_FOR_DEPOSITS = hashString("MAX_PNL_FACTOR_FOR_DEPOSITS");
export const MAX_PNL_FACTOR_FOR_WITHDRAWALS = hashString("MAX_PNL_FACTOR_FOR_WITHDRAWALS");

export const LATEST_ADL_BLOCK = hashString("LATEST_ADL_BLOCK");
export const IS_ADL_ENABLED = hashString("IS_ADL_ENABLED");

export const FUNDING_FACTOR = hashString("FUNDING_FACTOR");
export const FUNDING_EXPONENT_FACTOR = hashString("FUNDING_EXPONENT_FACTOR");

export const SAVED_FUNDING_FACTOR_PER_SECOND = hashString("SAVED_FUNDING_FACTOR_PER_SECOND");
export const FUNDING_INCREASE_FACTOR_PER_SECOND = hashString("FUNDING_INCREASE_FACTOR_PER_SECOND");
export const FUNDING_DECREASE_FACTOR_PER_SECOND = hashString("FUNDING_DECREASE_FACTOR_PER_SECOND");
export const MIN_FUNDING_FACTOR_PER_SECOND = hashString("MIN_FUNDING_FACTOR_PER_SECOND");
export const MAX_FUNDING_FACTOR_PER_SECOND = hashString("MAX_FUNDING_FACTOR_PER_SECOND");
export const THRESHOLD_FOR_STABLE_FUNDING = hashString("THRESHOLD_FOR_STABLE_FUNDING");
export const THRESHOLD_FOR_DECREASE_FUNDING = hashString("THRESHOLD_FOR_DECREASE_FUNDING");

export const FUNDING_FEE_AMOUNT_PER_SIZE = hashString("FUNDING_FEE_AMOUNT_PER_SIZE");
export const CLAIMABLE_FUNDING_AMOUNT_PER_SIZE = hashString("CLAIMABLE_FUNDING_AMOUNT_PER_SIZE");
export const FUNDING_UPDATED_AT = hashString("FUNDING_UPDATED_AT");

export const OPTIMAL_USAGE_FACTOR = hashString("OPTIMAL_USAGE_FACTOR");
export const BASE_BORROWING_FACTOR = hashString("BASE_BORROWING_FACTOR");
export const ABOVE_OPTIMAL_USAGE_BORROWING_FACTOR = hashString("ABOVE_OPTIMAL_USAGE_BORROWING_FACTOR");

export const BORROWING_FACTOR = hashString("BORROWING_FACTOR");
export const BORROWING_EXPONENT_FACTOR = hashString("BORROWING_EXPONENT_FACTOR");

export const SKIP_BORROWING_FEE_FOR_SMALLER_SIDE = hashString("SKIP_BORROWING_FEE_FOR_SMALLER_SIDE");

export const ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1 = hashString("ESTIMATED_GAS_FEE_BASE_AMOUNT_V2_1");
export const ESTIMATED_GAS_FEE_PER_ORACLE_PRICE = hashString("ESTIMATED_GAS_FEE_PER_ORACLE_PRICE");
export const ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR = hashString("ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR");

export const EXECUTION_GAS_FEE_BASE_AMOUNT_V2_1 = hashString("EXECUTION_GAS_FEE_BASE_AMOUNT_V2_1");
export const EXECUTION_GAS_FEE_PER_ORACLE_PRICE = hashString("EXECUTION_GAS_FEE_PER_ORACLE_PRICE");
export const EXECUTION_GAS_FEE_MULTIPLIER_FACTOR = hashString("EXECUTION_GAS_FEE_MULTIPLIER_FACTOR");

export const DEPOSIT_GAS_LIMIT = hashString("DEPOSIT_GAS_LIMIT");
export const WITHDRAWAL_GAS_LIMIT = hashString("WITHDRAWAL_GAS_LIMIT");
export const SHIFT_GAS_LIMIT = hashString("SHIFT_GAS_LIMIT");
export const SINGLE_SWAP_GAS_LIMIT = hashString("SINGLE_SWAP_GAS_LIMIT");
export const INCREASE_ORDER_GAS_LIMIT = hashString("INCREASE_ORDER_GAS_LIMIT");
export const DECREASE_ORDER_GAS_LIMIT = hashString("DECREASE_ORDER_GAS_LIMIT");
export const SWAP_ORDER_GAS_LIMIT = hashString("SWAP_ORDER_GAS_LIMIT");
export const GLV_DEPOSIT_GAS_LIMIT = hashString("GLV_DEPOSIT_GAS_LIMIT");
export const GLV_WITHDRAWAL_GAS_LIMIT = hashString("GLV_WITHDRAWAL_GAS_LIMIT");
export const GLV_SHIFT_GAS_LIMIT = hashString("GLV_SHIFT_GAS_LIMIT");
export const GLV_PER_MARKET_GAS_LIMIT = hashString("GLV_PER_MARKET_GAS_LIMIT");

export const CUMULATIVE_BORROWING_FACTOR = hashString("CUMULATIVE_BORROWING_FACTOR");
export const CUMULATIVE_BORROWING_FACTOR_UPDATED_AT = hashString("CUMULATIVE_BORROWING_FACTOR_UPDATED_AT");

export const VIRTUAL_TOKEN_ID = hashString("VIRTUAL_TOKEN_ID");
export const VIRTUAL_MARKET_ID = hashString("VIRTUAL_MARKET_ID");

export const VIRTUAL_INVENTORY_FOR_SWAPS = hashString("VIRTUAL_INVENTORY_FOR_SWAPS");
export const VIRTUAL_INVENTORY_FOR_POSITIONS = hashString("VIRTUAL_INVENTORY_FOR_POSITIONS");

export const MAX_ALLOWED_SUBACCOUNT_ACTION_COUNT = hashString("MAX_ALLOWED_SUBACCOUNT_ACTION_COUNT");
export const SUBACCOUNT_ACTION_COUNT = hashString("SUBACCOUNT_ACTION_COUNT");
export const SUBACCOUNT_AUTO_TOP_UP_AMOUNT = hashString("SUBACCOUNT_AUTO_TOP_UP_AMOUNT");
export const SUBACCOUNT_ORDER_ACTION = hashString("SUBACCOUNT_ORDER_ACTION");
export const SUBACCOUNT_EXPIRES_AT = hashString("SUBACCOUNT_EXPIRES_AT");
export const GLV_SUPPORTED_MARKET_LIST = hashString("GLV_SUPPORTED_MARKET_LIST");
export const MIN_GLV_TOKENS_FOR_FIRST_DEPOSIT = hashString("MIN_GLV_TOKENS_FOR_FIRST_DEPOSIT");

export const GLV_SHIFT_MAX_PRICE_IMPACT_FACTOR = hashString("GLV_SHIFT_MAX_PRICE_IMPACT_FACTOR");
export const GLV_MAX_MARKET_COUNT = hashString("GLV_MAX_MARKET_COUNT");
export const GLV_MAX_MARKET_TOKEN_BALANCE_USD = hashString("GLV_MAX_MARKET_TOKEN_BALANCE_USD");
export const GLV_MAX_MARKET_TOKEN_BALANCE_AMOUNT = hashString("GLV_MAX_MARKET_TOKEN_BALANCE_AMOUNT");
export const GLV_SHIFT_MIN_INTERVAL = hashString("GLV_SHIFT_MIN_INTERVAL");
export const IS_GLV_MARKET_DISABLED = hashString("IS_GLV_MARKET_DISABLED");

export const SYNC_CONFIG_FEATURE_DISABLED = hashString("SYNC_CONFIG_FEATURE_DISABLED");
export const SYNC_CONFIG_MARKET_DISABLED = hashString("SYNC_CONFIG_MARKET_DISABLED");
export const SYNC_CONFIG_PARAMETER_DISABLED = hashString("SYNC_CONFIG_PARAMETER_DISABLED");
export const SYNC_CONFIG_MARKET_PARAMETER_DISABLED = hashString("SYNC_CONFIG_MARKET_PARAMETER_DISABLED");
export const SYNC_CONFIG_UPDATE_COMPLETED = hashString("SYNC_CONFIG_UPDATE_COMPLETED");
export const SYNC_CONFIG_LATEST_UPDATE_ID = hashString("SYNC_CONFIG_LATEST_UPDATE_ID");

export const BUYBACK_BATCH_AMOUNT = hashString("BUYBACK_BATCH_AMOUNT");
export const BUYBACK_AVAILABLE_FEE_AMOUNT = hashString("BUYBACK_AVAILABLE_FEE_AMOUNT");
export const BUYBACK_GMX_FACTOR = hashString("BUYBACK_GMX_FACTOR");
export const BUYBACK_MAX_PRICE_IMPACT_FACTOR = hashString("BUYBACK_MAX_PRICE_IMPACT_FACTOR");
export const BUYBACK_MAX_PRICE_AGE = hashString("BUYBACK_MAX_PRICE_AGE");
export const WITHDRAWABLE_BUYBACK_TOKEN_AMOUNT = hashString("WITHDRAWABLE_BUYBACK_TOKEN_AMOUNT");
export const SOURCE_CHAIN_BALANCE = hashString("SOURCE_CHAIN_BALANCE");

export const VALID_FROM_TIME = hashString("VALID_FROM_TIME");

export const MAX_DATA_LENGTH = hashString("MAX_DATA_LENGTH");

export function accountDepositListKey(account) {
  return hashData(["bytes32", "address"], [ACCOUNT_DEPOSIT_LIST, account]);
}

export function accountWithdrawalListKey(account) {
  return hashData(["bytes32", "address"], [ACCOUNT_WITHDRAWAL_LIST, account]);
}

export function accountShiftListKey(account) {
  return hashData(["bytes32", "address"], [ACCOUNT_SHIFT_LIST, account]);
}

export function accountPositionListKey(account) {
  return hashData(["bytes32", "address"], [ACCOUNT_POSITION_LIST, account]);
}

export function accountOrderListKey(account) {
  return hashData(["bytes32", "address"], [ACCOUNT_ORDER_LIST, account]);
}

export function subaccountListKey(account) {
  return hashData(["bytes32", "address"], [SUBACCOUNT_LIST, account]);
}

export function autoCancelOrderListKey(positionKey) {
  return hashData(["bytes32", "bytes32"], [AUTO_CANCEL_ORDER_LIST, positionKey]);
}

export function isMarketDisabledKey(market) {
  return hashData(["bytes32", "address"], [IS_MARKET_DISABLED, market]);
}

export function minMarketTokensForFirstDeposit(market) {
  return hashData(["bytes32", "address"], [MIN_MARKET_TOKENS_FOR_FIRST_DEPOSIT, market]);
}

export function createDepositFeatureDisabledKey(contract) {
  return hashData(["bytes32", "address"], [CREATE_DEPOSIT_FEATURE_DISABLED, contract]);
}

export function cancelDepositFeatureDisabledKey(contract) {
  return hashData(["bytes32", "address"], [CANCEL_DEPOSIT_FEATURE_DISABLED, contract]);
}

export function executeDepositFeatureDisabledKey(contract) {
  return hashData(["bytes32", "address"], [EXECUTE_DEPOSIT_FEATURE_DISABLED, contract]);
}

export function createOrderFeatureDisabledKey(contract, orderType) {
  return hashData(["bytes32", "address", "uint256"], [CREATE_ORDER_FEATURE_DISABLED, contract, orderType]);
}

export function executeOrderFeatureDisabledKey(contract, orderType) {
  return hashData(["bytes32", "address", "uint256"], [EXECUTE_ORDER_FEATURE_DISABLED, contract, orderType]);
}

export function executeAdlFeatureDisabledKey(contract, orderType) {
  return hashData(["bytes32", "address", "uint256"], [EXECUTE_ADL_FEATURE_DISABLED, contract, orderType]);
}

export function updateOrderFeatureDisabledKey(contract, orderType) {
  return hashData(["bytes32", "address", "uint256"], [UPDATE_ORDER_FEATURE_DISABLED, contract, orderType]);
}

export function cancelOrderFeatureDisabledKey(contract, orderType) {
  return hashData(["bytes32", "address", "uint256"], [CANCEL_ORDER_FEATURE_DISABLED, contract, orderType]);
}

export function claimableFeeAmountKey(market: string, token: string) {
  return hashData(["bytes32", "address", "address"], [CLAIMABLE_FEE_AMOUNT, market, token]);
}

export function claimableFundingAmountKey(market: string, token: string, account: string) {
  return hashData(["bytes32", "address", "address", "address"], [CLAIMABLE_FUNDING_AMOUNT, market, token, account]);
}

export function claimableCollateralAmountKey(market: string, token: string, timeKey: number, account: string) {
  return hashData(
    ["bytes32", "address", "address", "uint256", "address"],
    [CLAIMABLE_COLLATERAL_AMOUNT, market, token, timeKey, account]
  );
}

export function claimableCollateralFactorKey(market: string, token: string, timeKey: number) {
  return hashData(["bytes32", "address", "address", "uint256"], [CLAIMABLE_COLLATERAL_FACTOR, market, token, timeKey]);
}

export function claimableCollateralFactorForAccountKey(
  market: string,
  token: string,
  timeKey: number,
  account: string
) {
  return hashData(
    ["bytes32", "address", "address", "uint256", "address"],
    [CLAIMABLE_COLLATERAL_FACTOR, market, token, timeKey, account]
  );
}

export function claimableCollateralReductionFactorForAccountKey(
  market: string,
  token: string,
  timeKey: number,
  account: string
) {
  return hashData(
    ["bytes32", "address", "address", "uint256", "address"],
    [CLAIMABLE_COLLATERAL_REDUCTION_FACTOR, market, token, timeKey, account]
  );
}

export function claimableUiFeeAmountKey(market: string, token: string, uiFeeReceiver: string) {
  return hashData(
    ["bytes32", "address", "address", "address"],
    [CLAIMABLE_UI_FEE_AMOUNT, market, token, uiFeeReceiver]
  );
}

export function affiliateRewardKey(market: string, token: string, account: string) {
  return hashData(["bytes32", "address", "address", "address"], [AFFILIATE_REWARD, market, token, account]);
}

export function minAffiliateRewardFactorKey(referralTierLevel: number) {
  return hashData(["bytes32", "uint256"], [MIN_AFFILIATE_REWARD_FACTOR, referralTierLevel]);
}

export function tokenTransferGasLimit(token: string) {
  return hashData(["bytes32", "address"], [TOKEN_TRANSFER_GAS_LIMIT, token]);
}

export function priceFeedKey(token: string) {
  return hashData(["bytes32", "address"], [PRICE_FEED, token]);
}

export function priceFeedMultiplierKey(token: string) {
  return hashData(["bytes32", "address"], [PRICE_FEED_MULTIPLIER, token]);
}

export function priceFeedHeartbeatDurationKey(token: string) {
  return hashData(["bytes32", "address"], [PRICE_FEED_HEARTBEAT_DURATION, token]);
}

export function dataStreamIdKey(token: string) {
  return hashData(["bytes32", "address"], [DATA_STREAM_ID, token]);
}

export function dataStreamMultiplierKey(token: string) {
  return hashData(["bytes32", "address"], [DATA_STREAM_MULTIPLIER, token]);
}

export function dataStreamSpreadReductionFactorKey(token: string) {
  return hashData(["bytes32", "address"], [DATA_STREAM_SPREAD_REDUCTION_FACTOR, token]);
}

export function stablePriceKey(token: string) {
  return hashData(["bytes32", "address"], [STABLE_PRICE, token]);
}

export function oracleTypeKey(token: string) {
  return hashData(["bytes32", "address"], [ORACLE_TYPE, token]);
}

export function oracleTimestampAdjustmentKey(provider: string, token: string) {
  return hashData(["bytes32", "address", "address"], [ORACLE_TIMESTAMP_ADJUSTMENT, provider, token]);
}

export function oracleProviderForTokenKey(token: string) {
  return hashData(["bytes32", "address"], [ORACLE_PROVIDER_FOR_TOKEN, token]);
}

export function openInterestKey(market: string, collateralToken: string, isLong: boolean) {
  return hashData(["bytes32", "address", "address", "bool"], [OPEN_INTEREST, market, collateralToken, isLong]);
}

export function openInterestInTokensKey(market: string, collateralToken: string, isLong: boolean) {
  return hashData(
    ["bytes32", "address", "address", "bool"],
    [OPEN_INTEREST_IN_TOKENS, market, collateralToken, isLong]
  );
}

export function isOracleProviderEnabledKey(provider: string) {
  return hashData(["bytes32", "address"], [IS_ORACLE_PROVIDER_ENABLED, provider]);
}

export function isAtomicOracleProviderKey(provider: string) {
  return hashData(["bytes32", "address"], [IS_ATOMIC_ORACLE_PROVIDER, provider]);
}

export function minCollateralFactorKey(market: string) {
  return hashData(["bytes32", "address"], [MIN_COLLATERAL_FACTOR, market]);
}

export function minCollateralFactorForOpenInterestMultiplierKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER, market, isLong]);
}

export function reserveFactorKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [RESERVE_FACTOR, market, isLong]);
}

export function openInterestReserveFactorKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [OPEN_INTEREST_RESERVE_FACTOR, market, isLong]);
}

export function maxPnlFactorKey(pnlFactorType: string, market: string, isLong: boolean) {
  return hashData(["bytes32", "bytes32", "address", "bool"], [MAX_PNL_FACTOR, pnlFactorType, market, isLong]);
}

export function minPnlFactorAfterAdl(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [MIN_PNL_FACTOR_AFTER_ADL, market, isLong]);
}

export function collateralSumKey(market: string, collateralToken: string, isLong: boolean) {
  return hashData(["bytes32", "address", "address", "bool"], [COLLATERAL_SUM, market, collateralToken, isLong]);
}

export function poolAmountKey(market: string, token: string) {
  return hashData(["bytes32", "address", "address"], [POOL_AMOUNT, market, token]);
}

export function maxPoolAmountKey(market: string, token: string) {
  return hashData(["bytes32", "address", "address"], [MAX_POOL_AMOUNT, market, token]);
}

export function maxPoolUsdForDepositKey(market: string, token: string) {
  return hashData(["bytes32", "address", "address"], [MAX_POOL_USD_FOR_DEPOSIT, market, token]);
}

export function maxOpenInterestKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [MAX_OPEN_INTEREST, market, isLong]);
}

export function positionImpactPoolAmountKey(market: string) {
  return hashData(["bytes32", "address"], [POSITION_IMPACT_POOL_AMOUNT, market]);
}

export function minPositionImpactPoolAmountKey(market: string) {
  return hashData(["bytes32", "address"], [MIN_POSITION_IMPACT_POOL_AMOUNT, market]);
}

export function positionImpactPoolDistributionRateKey(market: string) {
  return hashData(["bytes32", "address"], [POSITION_IMPACT_POOL_DISTRIBUTION_RATE, market]);
}

export function positionImpactPoolDistributedAtKey(market: string) {
  return hashData(["bytes32", "address"], [POSITION_IMPACT_POOL_DISTRIBUTED_AT, market]);
}

export function swapImpactPoolAmountKey(market: string, token: string) {
  return hashData(["bytes32", "address", "address"], [SWAP_IMPACT_POOL_AMOUNT, market, token]);
}

export function swapFeeFactorKey(market: string, balanceWasImproved: boolean) {
  return hashData(["bytes32", "address", "bool"], [SWAP_FEE_FACTOR, market, balanceWasImproved]);
}

export function depositFeeFactorKey(market: string, balanceWasImproved: boolean) {
  return hashData(["bytes32", "address", "bool"], [DEPOSIT_FEE_FACTOR, market, balanceWasImproved]);
}

export function withdrawalFeeFactorKey(market: string, balanceWasImproved: boolean) {
  return hashData(["bytes32", "address", "bool"], [WITHDRAWAL_FEE_FACTOR, market, balanceWasImproved]);
}

export function atomicSwapFeeFactorKey(market: string) {
  return hashData(["bytes32", "address"], [ATOMIC_SWAP_FEE_FACTOR, market]);
}

export function swapImpactFactorKey(market: string, isPositive: boolean) {
  return hashData(["bytes32", "address", "bool"], [SWAP_IMPACT_FACTOR, market, isPositive]);
}

export function swapImpactExponentFactorKey(market: string) {
  return hashData(["bytes32", "address"], [SWAP_IMPACT_EXPONENT_FACTOR, market]);
}

export function positionImpactFactorKey(market: string, isPositive: boolean) {
  return hashData(["bytes32", "address", "bool"], [POSITION_IMPACT_FACTOR, market, isPositive]);
}

export function positionImpactExponentFactorKey(market: string) {
  return hashData(["bytes32", "address"], [POSITION_IMPACT_EXPONENT_FACTOR, market]);
}

export function maxPositionImpactFactorKey(market: string, isPositive: boolean) {
  return hashData(["bytes32", "address", "bool"], [MAX_POSITION_IMPACT_FACTOR, market, isPositive]);
}

export function maxPositionImpactFactorForLiquidationsKey(market: string) {
  return hashData(["bytes32", "address"], [MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS, market]);
}

export function positionFeeFactorKey(market: string, balanceWasImproved: boolean) {
  return hashData(["bytes32", "address", "bool"], [POSITION_FEE_FACTOR, market, balanceWasImproved]);
}

export function proTraderTierKey(account: string) {
  return hashData(["bytes32", "address"], [PRO_TRADER_TIER, account]);
}

export function proDiscountFactorKey(proTier: number) {
  return hashData(["bytes32", "uint256"], [PRO_DISCOUNT_FACTOR, proTier]);
}

export function liquidationFeeFactorKey(market: string) {
  return hashData(["bytes32", "address"], [LIQUIDATION_FEE_FACTOR, market]);
}

export function latestAdlBlockKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [LATEST_ADL_BLOCK, market, isLong]);
}

export function isAdlEnabledKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [IS_ADL_ENABLED, market, isLong]);
}

export function fundingFactorKey(market: string) {
  return hashData(["bytes32", "address"], [FUNDING_FACTOR, market]);
}

export function fundingExponentFactorKey(market: string) {
  return hashData(["bytes32", "address"], [FUNDING_EXPONENT_FACTOR, market]);
}

export function savedFundingFactorPerSecondKey(market: string) {
  return hashData(["bytes32", "address"], [SAVED_FUNDING_FACTOR_PER_SECOND, market]);
}

export function fundingIncreaseFactorPerSecondKey(market: string) {
  return hashData(["bytes32", "address"], [FUNDING_INCREASE_FACTOR_PER_SECOND, market]);
}

export function fundingDecreaseFactorPerSecondKey(market: string) {
  return hashData(["bytes32", "address"], [FUNDING_DECREASE_FACTOR_PER_SECOND, market]);
}

export function minFundingFactorPerSecondKey(market: string) {
  return hashData(["bytes32", "address"], [MIN_FUNDING_FACTOR_PER_SECOND, market]);
}

export function maxFundingFactorPerSecondKey(market: string) {
  return hashData(["bytes32", "address"], [MAX_FUNDING_FACTOR_PER_SECOND, market]);
}

export function thresholdForStableFundingKey(market: string) {
  return hashData(["bytes32", "address"], [THRESHOLD_FOR_STABLE_FUNDING, market]);
}

export function thresholdForDecreaseFundingKey(market: string) {
  return hashData(["bytes32", "address"], [THRESHOLD_FOR_DECREASE_FUNDING, market]);
}

export function fundingFeeAmountPerSizeKey(market: string, collateralToken: string, isLong: boolean) {
  return hashData(
    ["bytes32", "address", "address", "bool"],
    [FUNDING_FEE_AMOUNT_PER_SIZE, market, collateralToken, isLong]
  );
}

export function claimableFundingAmountPerSizeKey(market: string, collateralToken: string, isLong: boolean) {
  return hashData(
    ["bytes32", "address", "address", "bool"],
    [CLAIMABLE_FUNDING_AMOUNT_PER_SIZE, market, collateralToken, isLong]
  );
}

export function fundingUpdatedAtKey(market: string) {
  return hashData(["bytes32", "address"], [FUNDING_UPDATED_AT, market]);
}

export function borrowingFactorKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [BORROWING_FACTOR, market, isLong]);
}

export function borrowingExponentFactorKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [BORROWING_EXPONENT_FACTOR, market, isLong]);
}

export function depositGasLimitKey() {
  return DEPOSIT_GAS_LIMIT;
}

export function withdrawalGasLimitKey() {
  return WITHDRAWAL_GAS_LIMIT;
}

export function shiftGasLimitKey() {
  return SHIFT_GAS_LIMIT;
}

export function singleSwapGasLimitKey() {
  return SINGLE_SWAP_GAS_LIMIT;
}

export function increaseOrderGasLimitKey() {
  return INCREASE_ORDER_GAS_LIMIT;
}

export function decreaseOrderGasLimitKey() {
  return DECREASE_ORDER_GAS_LIMIT;
}

export function swapOrderGasLimitKey() {
  return SWAP_ORDER_GAS_LIMIT;
}

export function glvDepositGasLimitKey() {
  return GLV_DEPOSIT_GAS_LIMIT;
}

export function glvWithdrawalGasLimitKey() {
  return GLV_WITHDRAWAL_GAS_LIMIT;
}

export function glvShiftGasLimitKey() {
  return GLV_SHIFT_GAS_LIMIT;
}

export function glvPerMarketGasLimitKey() {
  return GLV_PER_MARKET_GAS_LIMIT;
}

export function cumulativeBorrowingFactorKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [CUMULATIVE_BORROWING_FACTOR, market, isLong]);
}

export function cumulativeBorrowingFactorUpdatedAtKey(market: string, isLong: boolean) {
  return hashData(["bytes32", "address", "bool"], [CUMULATIVE_BORROWING_FACTOR_UPDATED_AT, market, isLong]);
}

export function virtualTokenIdKey(token: string) {
  return hashData(["bytes32", "address"], [VIRTUAL_TOKEN_ID, token]);
}

export function virtualMarketIdKey(market: string) {
  return hashData(["bytes32", "address"], [VIRTUAL_MARKET_ID, market]);
}

export function virtualInventoryForSwapsKey(virtualMarketId: string, isLongToken: boolean) {
  return hashData(["bytes32", "bytes32", "bool"], [VIRTUAL_INVENTORY_FOR_SWAPS, virtualMarketId, isLongToken]);
}

export function virtualInventoryForPositionsKey(virtualTokenId: string) {
  return hashData(["bytes32", "bytes32"], [VIRTUAL_INVENTORY_FOR_POSITIONS, virtualTokenId]);
}

export function maxAllowedSubaccountActionCountKey(account: string, subaccount: string, actionType: string) {
  return hashData(
    ["bytes32", "address", "address", "bytes32"],
    [MAX_ALLOWED_SUBACCOUNT_ACTION_COUNT, account, subaccount, actionType]
  );
}

export function subaccountExpiresAtKey(account: string, subaccount: string, actionType: string) {
  return hashData(
    ["bytes32", "address", "address", "bytes32"],
    [SUBACCOUNT_EXPIRES_AT, account, subaccount, actionType]
  );
}

export function subaccountActionCountKey(account: string, subaccount: string, actionType: string) {
  return hashData(
    ["bytes32", "address", "address", "bytes32"],
    [SUBACCOUNT_ACTION_COUNT, account, subaccount, actionType]
  );
}

export function subaccountAutoTopUpAmountKey(account: string, subaccount: string) {
  return hashData(["bytes32", "address", "address"], [SUBACCOUNT_AUTO_TOP_UP_AMOUNT, account, subaccount]);
}

export function glvSupportedMarketListKey(glv: string) {
  return hashData(["bytes32", "address"], [GLV_SUPPORTED_MARKET_LIST, glv]);
}

export function minGlvTokensForFirstGlvDepositKey(glv: string) {
  return hashData(["bytes32", "address"], [MIN_GLV_TOKENS_FOR_FIRST_DEPOSIT, glv]);
}

export function accountGlvDepositListKey(account) {
  return hashData(["bytes32", "address"], [ACCOUNT_GLV_DEPOSIT_LIST, account]);
}

export function accountGlvWithdrawalListKey(account) {
  return hashData(["bytes32", "address"], [ACCOUNT_GLV_WITHDRAWAL_LIST, account]);
}

export function glvMaxMarketTokenBalanceUsdKey(glv: string, market: string) {
  return hashData(["bytes32", "address", "address"], [GLV_MAX_MARKET_TOKEN_BALANCE_USD, glv, market]);
}

export function glvMaxMarketTokenBalanceAmountKey(glv: string, market: string) {
  return hashData(["bytes32", "address", "address"], [GLV_MAX_MARKET_TOKEN_BALANCE_AMOUNT, glv, market]);
}

export function glvShiftMinIntervalKey(glv: string) {
  return hashData(["bytes32", "address"], [GLV_SHIFT_MIN_INTERVAL, glv]);
}

export function glvShiftMaxPriceImpactFactorKey(glv: string) {
  return hashData(["bytes32", "address"], [GLV_SHIFT_MAX_PRICE_IMPACT_FACTOR, glv]);
}

export function isGlvMarketDisabledKey(glv: string, market: string) {
  return hashData(["bytes32", "address", "address"], [IS_GLV_MARKET_DISABLED, glv, market]);
}

export function syncConfigFeatureDisabledKey(contract: string) {
  return hashData(["bytes32", "address"], [SYNC_CONFIG_FEATURE_DISABLED, contract]);
}

export function syncConfigMarketDisabledKey(market: string) {
  return hashData(["bytes32", "address"], [SYNC_CONFIG_MARKET_DISABLED, market]);
}

export function syncConfigParameterDisabledKey(parameter: string) {
  return hashData(["bytes32", "string"], [SYNC_CONFIG_PARAMETER_DISABLED, parameter]);
}

export function syncConfigMarketParameterDisabledKey(market: string, parameter: string) {
  return hashData(["bytes32", "address", "string"], [SYNC_CONFIG_MARKET_PARAMETER_DISABLED, market, parameter]);
}

export function syncConfigUpdateCompletedKey(updateId: number) {
  return hashData(["bytes32", "uint256"], [SYNC_CONFIG_UPDATE_COMPLETED, updateId]);
}

export function syncConfigLatestUpdateIdKey() {
  return SYNC_CONFIG_LATEST_UPDATE_ID;
}

export function buybackBatchAmountKey(token: string) {
  return hashData(["bytes32", "address"], [BUYBACK_BATCH_AMOUNT, token]);
}

export function buybackAvailableFeeAmountKey(feeToken: string, swapToken: string) {
  return hashData(["bytes32", "address", "address"], [BUYBACK_AVAILABLE_FEE_AMOUNT, feeToken, swapToken]);
}

export function buybackGmxFactorKey(version: number) {
  return hashData(["bytes32", "uint256"], [BUYBACK_GMX_FACTOR, version]);
}

export function buybackMaxPriceImpactFactorKey(token: string) {
  return hashData(["bytes32", "address"], [BUYBACK_MAX_PRICE_IMPACT_FACTOR, token]);
}

export function withdrawableBuybackTokenAmountKey(buybackToken: string) {
  return hashData(["bytes32", "address"], [WITHDRAWABLE_BUYBACK_TOKEN_AMOUNT, buybackToken]);
}

export function sourceChainBalanceKey(sourceChainId: number, account: string, token: string) {
  return hashData(["bytes32", "uint256", "address", "address"], [SOURCE_CHAIN_BALANCE, sourceChainId, account, token]);
}
