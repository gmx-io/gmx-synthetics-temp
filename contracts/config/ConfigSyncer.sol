// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Config.sol";
import "./IRiskOracle.sol";
import "../feature/FeatureUtils.sol";

// @title ConfigSyncer
// @dev Contract to handle market parameter updates
contract ConfigSyncer is ReentrancyGuard, RoleModule {
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.BoolItems;

    Config public immutable config;
    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;
    address public immutable riskOracle;

    // @dev the base keys that can be set
    mapping(bytes32 => bool) public allowedBaseKeys;

    constructor(
        RoleStore _roleStore,
        Config _config,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        address _riskOracle
    ) RoleModule(_roleStore) {
        config = _config;
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
        riskOracle = _riskOracle;

        _initAllowedBaseKeys();
    }

    // @dev Allows the LIMITED_CONFIG_KEEPER to apply updates with the provided markets and parameters
    // Values for parameters with the following base keys are not currently validated on-chain, they should be
    // validated off-chain if needed: MIN_FUNDING_FACTOR_PER_SECOND, MAX_POOL_AMOUNT, MAX_POOL_USD_FOR_DEPOSIT,
    // MAX_OPEN_INTEREST, POSITION_IMPACT_FACTOR, SWAP_IMPACT_FACTOR, RESERVE_FACTOR, OPEN_INTEREST_RESERVE_FACTOR
    // @param markets An array of market addresses for which updates are to be applied
    // @param parameters An array of parameters corresponding to each market for which updates are to be applied
    function sync(
        address[] calldata markets,
        string[] calldata parameters
    ) external onlyLimitedConfigKeeper nonReentrant {
        FeatureUtils.validateFeature(dataStore, Keys.syncConfigFeatureDisabledKey(address(this)));

        if (markets.length != parameters.length) {
            revert Errors.SyncConfigInvalidInputLengths(markets.length, parameters.length);
        }

        uint256 latestUpdateId = dataStore.getUint(Keys.syncConfigLatestUpdateIdKey());

        for (uint256 i; i < markets.length; i++) {
            address market = markets[i];
            string memory parameter = parameters[i];
            bool updateApplied;

            bool syncConfigMarketDisabled = dataStore.getBool(Keys.syncConfigMarketDisabledKey(market));
            if (syncConfigMarketDisabled) {
                revert Errors.SyncConfigUpdatesDisabledForMarket(market);
            }

            bool syncConfigParameterDisabled = dataStore.getBool(Keys.syncConfigParameterDisabledKey(parameter));
            if (syncConfigParameterDisabled) {
                revert Errors.SyncConfigUpdatesDisabledForParameter(parameter);
            }

            bool syncConfigMarketParameterDisabled = dataStore.getBool(
                Keys.syncConfigMarketParameterDisabledKey(market, parameter)
            );
            if (syncConfigMarketParameterDisabled) {
                revert Errors.SyncConfigUpdatesDisabledForMarketParameter(market, parameter);
            }

            IRiskOracle.RiskParameterUpdate memory riskParameterUpdate = IRiskOracle(riskOracle)
                .getLatestUpdateByParameterAndMarket(parameter, market);
            uint256 updateId = riskParameterUpdate.updateId;
            (bytes32 baseKey, bytes memory data) = abi.decode(riskParameterUpdate.additionalData, (bytes32, bytes));

            _validateMarketInData(baseKey, market, data);

            _validateKey(baseKey);

            bytes32 fullKey = Keys.getFullKey(baseKey, data);
            uint256 prevValue = dataStore.getUint(fullKey);
            uint256 updatedValue = Cast.bytesToUint256(riskParameterUpdate.newValue);

            bool syncConfigUpdateCompleted = dataStore.getBool(Keys.syncConfigUpdateCompletedKey(updateId));
            if (!syncConfigUpdateCompleted) {
                config.setUint(baseKey, data, updatedValue);
                dataStore.setBool(Keys.syncConfigUpdateCompletedKey(updateId), true);
                updateApplied = true;

                if (updateId > latestUpdateId) {
                    latestUpdateId = updateId;
                }
            }

            EventUtils.EventLogData memory eventData;

            eventData.uintItems.initItems(3);
            eventData.uintItems.setItem(0, "updateId", updateId);
            eventData.uintItems.setItem(1, "prevValue", prevValue);
            eventData.uintItems.setItem(2, "nextValue", updatedValue);

            eventData.boolItems.initItems(1);
            eventData.boolItems.setItem(0, "updateApplied", updateApplied);

            eventEmitter.emitEventLog("SyncConfig", eventData);
        }

        if (latestUpdateId > dataStore.getUint(Keys.syncConfigLatestUpdateIdKey())) {
            dataStore.setUint(Keys.syncConfigLatestUpdateIdKey(), latestUpdateId);
        }
    }

    // @dev initialize the allowed base keys
    function _initAllowedBaseKeys() internal {
        allowedBaseKeys[Keys.MAX_POOL_AMOUNT] = true;
        allowedBaseKeys[Keys.MAX_POOL_USD_FOR_DEPOSIT] = true;
        allowedBaseKeys[Keys.MAX_OPEN_INTEREST] = true;

        allowedBaseKeys[Keys.POSITION_IMPACT_FACTOR] = true;
        allowedBaseKeys[Keys.POSITION_IMPACT_EXPONENT_FACTOR] = true;

        allowedBaseKeys[Keys.SWAP_IMPACT_FACTOR] = true;
        allowedBaseKeys[Keys.SWAP_IMPACT_EXPONENT_FACTOR] = true;

        allowedBaseKeys[Keys.FUNDING_INCREASE_FACTOR_PER_SECOND] = true;
        allowedBaseKeys[Keys.FUNDING_DECREASE_FACTOR_PER_SECOND] = true;
        allowedBaseKeys[Keys.MIN_FUNDING_FACTOR_PER_SECOND] = true;
        allowedBaseKeys[Keys.MAX_FUNDING_FACTOR_PER_SECOND] = true;

        allowedBaseKeys[Keys.OPTIMAL_USAGE_FACTOR] = true;
        allowedBaseKeys[Keys.BASE_BORROWING_FACTOR] = true;
        allowedBaseKeys[Keys.ABOVE_OPTIMAL_USAGE_BORROWING_FACTOR] = true;
        allowedBaseKeys[Keys.BORROWING_FACTOR] = true;
        allowedBaseKeys[Keys.BORROWING_EXPONENT_FACTOR] = true;

        allowedBaseKeys[Keys.RESERVE_FACTOR] = true;
        allowedBaseKeys[Keys.OPEN_INTEREST_RESERVE_FACTOR] = true;
    }

    // @dev validate that the baseKey is allowed to be used
    // @param baseKey the base key to validate
    function _validateKey(bytes32 baseKey) internal view {
        if (!allowedBaseKeys[baseKey]) {
            revert Errors.InvalidBaseKey(baseKey);
        }
    }

    // @dev validate that the market within data is equal to market
    // With the exception of parameters that use the MAX_PNL_FACTOR base key, this function currently
    // only supports parameters for which the market address is the first element in the 'data' param
    // @param baseKey the base key to validate
    // @param market the market address
    // @param data the data used to compute fullKey
    function _validateMarketInData(bytes32 baseKey, address market, bytes memory data) internal pure {
        address marketFromData;
        if (baseKey == Keys.MAX_PNL_FACTOR) {
            (, /* bytes32 extKey */ marketFromData /* bool isLong */, ) = abi.decode(data, (bytes32, address, bool));
        } else {
            marketFromData = abi.decode(data, (address));
        }

        if (market != marketFromData) {
            revert Errors.SyncConfigInvalidMarketFromData(market, marketFromData);
        }
    }
}
