// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { AggregatorV2V3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";

import "../role/RoleModule.sol";

import "./OracleUtils.sol";
import "./IOracleProvider.sol";
import "./ChainlinkPriceFeedUtils.sol";
import "../price/Price.sol";

import "../chain/Chain.sol";
import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";

import "../utils/Precision.sol";
import "../utils/Cast.sol";
import "../utils/Uint256Mask.sol";

// @title Oracle
// @dev Contract to validate and store signed values
// Some calculations e.g. calculating the size in tokens for a position
// may not work with zero / negative prices
// as a result, zero / negative prices are considered empty / invalid
// A market may need to be manually settled in this case
contract Oracle is RoleModule {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;
    using Price for Price.Props;
    using Uint256Mask for Uint256Mask.Mask;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;
    AggregatorV2V3Interface public immutable sequencerUptimeFeed;

    // tokensWithPrices stores the tokens with prices that have been set
    // this is used in clearAllPrices to help ensure that all token prices
    // set in setPrices are cleared after use
    EnumerableSet.AddressSet internal tokensWithPrices;
    mapping(address => Price.Props) public primaryPrices;

    uint256 public minTimestamp;
    uint256 public maxTimestamp;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        AggregatorV2V3Interface _sequencerUptimeFeed
    ) RoleModule(_roleStore) {
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
        sequencerUptimeFeed = _sequencerUptimeFeed;
    }

    // this can be used to help ensure that on-chain prices are updated
    // before actions dependent on those on-chain prices are allowed
    // additionally, this can also be used to provide a grace period for
    // users to top up collateral before liquidations occur
    function validateSequencerUp() external view {
        if (address(sequencerUptimeFeed) == address(0)) {
            return;
        }

        (
            /*uint80 roundID*/,
            int256 answer,
            uint256 startedAt,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = sequencerUptimeFeed.latestRoundData();

        // answer == 0: sequencer is up
        // answer == 1: sequencer is down
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert Errors.SequencerDown();
        }

        uint256 sequencerGraceDuration = dataStore.getUint(Keys.SEQUENCER_GRACE_DURATION);

        // ensure the grace duration has passed after the
        // sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= sequencerGraceDuration) {
            revert Errors.SequencerGraceDurationNotYetPassed(timeSinceUp, sequencerGraceDuration);
        }
    }

    function setPrices(
        OracleUtils.SetPricesParams memory params
    ) external onlyController {
        OracleUtils.ValidatedPrice[] memory prices = _validatePrices(params, false);

        _setPrices(prices);
    }

    function setPricesForAtomicAction(
        OracleUtils.SetPricesParams memory params
    ) external onlyController {
        OracleUtils.ValidatedPrice[] memory prices = _validatePrices(params, true);

        _setPrices(prices);
    }

    // @dev set the primary price
    // @param token the token to set the price for
    // @param price the price value to set to
    function setPrimaryPrice(address token, Price.Props memory price) external onlyController {
        _setPrimaryPrice(token, price);
    }

    function setTimestamps(uint256 _minTimestamp, uint256 _maxTimestamp) external onlyController {
        minTimestamp = _minTimestamp;
        maxTimestamp = _maxTimestamp;
    }

    // @dev clear all prices
    function clearAllPrices() external onlyController {
        uint256 length = tokensWithPrices.length();
        for (uint256 i; i < length; i++) {
            address token = tokensWithPrices.at(0);
            _removePrimaryPrice(token);
        }

        minTimestamp = 0;
        maxTimestamp = 0;
    }

    // @dev get the length of tokensWithPrices
    // @return the length of tokensWithPrices
    function getTokensWithPricesCount() external view returns (uint256) {
        return tokensWithPrices.length();
    }

    // @dev get the tokens of tokensWithPrices for the specified indexes
    // @param start the start index, the value for this index will be included
    // @param end the end index, the value for this index will not be included
    // @return the tokens of tokensWithPrices for the specified indexes
    function getTokensWithPrices(uint256 start, uint256 end) external view returns (address[] memory) {
        return tokensWithPrices.valuesAt(start, end);
    }

    // @dev get the primary price of a token
    // @param token the token to get the price for
    // @return the primary price of a token
    function getPrimaryPrice(address token) external view returns (Price.Props memory) {
        if (token == address(0)) { return Price.Props(0, 0); }

        Price.Props memory price = primaryPrices[token];
        if (price.isEmpty()) {
            revert Errors.EmptyPrimaryPrice(token);
        }

        return price;
    }

    function validatePrices(
        OracleUtils.SetPricesParams memory params,
        bool forAtomicAction
    ) external onlyController returns (OracleUtils.ValidatedPrice[] memory) {
        return _validatePrices(params, forAtomicAction);
    }

    // @dev validate and set prices
    // @param params OracleUtils.SetPricesParams
    function _setPrices(
        OracleUtils.ValidatedPrice[] memory prices
    ) internal {
        // in case of gasless relay the prices are not required if there is no need to swap fee tokens
        if (prices.length == 0) {
            return;
        }

        if (tokensWithPrices.length() != 0) {
            revert Errors.NonEmptyTokensWithPrices(tokensWithPrices.length());
        }

        uint256 _minTimestamp = prices[0].timestamp;
        uint256 _maxTimestamp = prices[0].timestamp;

        for (uint256 i; i < prices.length; i++) {
            OracleUtils.ValidatedPrice memory validatedPrice = prices[i];

            _setPrimaryPrice(validatedPrice.token, Price.Props(
                validatedPrice.min,
                validatedPrice.max
            ));

            if (validatedPrice.timestamp < _minTimestamp) {
                _minTimestamp = validatedPrice.timestamp;
            }

            if (validatedPrice.timestamp > _maxTimestamp) {
                _maxTimestamp = validatedPrice.timestamp;
            }

            _emitOraclePriceUpdated(
                validatedPrice.token,
                validatedPrice.min,
                validatedPrice.max,
                validatedPrice.timestamp,
                validatedPrice.provider
            );
        }

        uint256 maxRange = dataStore.getUint(Keys.MAX_ORACLE_TIMESTAMP_RANGE);
        if (_maxTimestamp - _minTimestamp > maxRange) {
            revert Errors.MaxOracleTimestampRangeExceeded(_maxTimestamp - _minTimestamp, maxRange);
        }

        minTimestamp = _minTimestamp;
        maxTimestamp = _maxTimestamp;
    }

    function _validatePrices(
        OracleUtils.SetPricesParams memory params,
        bool forAtomicAction
    ) internal returns (OracleUtils.ValidatedPrice[] memory) {
        if (params.tokens.length != params.providers.length) {
            revert Errors.InvalidOracleSetPricesProvidersParam(params.tokens.length, params.providers.length);
        }

        if (params.tokens.length != params.data.length) {
            revert Errors.InvalidOracleSetPricesDataParam(params.tokens.length, params.data.length);
        }

        OracleUtils.ValidatedPrice[] memory prices = new OracleUtils.ValidatedPrice[](params.tokens.length);

        if (params.tokens.length == 0) {
            return prices;
        }

        uint256 maxPriceAge = dataStore.getUint(Keys.MAX_ORACLE_PRICE_AGE);
        uint256 maxRefPriceDeviationFactor = dataStore.getUint(Keys.MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR);

        for (uint256 i; i < params.tokens.length; i++) {
            address provider = params.providers[i];

            if (!dataStore.getBool(Keys.isOracleProviderEnabledKey(provider))) {
                revert Errors.InvalidOracleProvider(provider);
            }

            address token = params.tokens[i];

            bool isAtomicProvider = dataStore.getBool(Keys.isAtomicOracleProviderKey(provider));

            // if the action is atomic then only validate that the provider is an
            // atomic provider
            // else, validate that the provider matches the oracleProviderForToken
            //
            // since for atomic actions, any atomic provider can be used, it is
            // recommended that only one atomic provider is configured per token
            // otherwise there is a risk that if there is a difference in pricing
            // between atomic oracle providers for a token, a user could use that
            // to gain a profit by alternating actions between the two atomic
            // providers
            if (forAtomicAction) {
                if (!isAtomicProvider) {
                    revert Errors.NonAtomicOracleProvider(provider);
                }
            } else {
                address expectedProvider = dataStore.getAddress(Keys.oracleProviderForTokenKey(token));
                if (provider != expectedProvider) {
                    revert Errors.InvalidOracleProviderForToken(provider, expectedProvider);
                }
            }

            bytes memory data = params.data[i];

            OracleUtils.ValidatedPrice memory validatedPrice = IOracleProvider(provider).getOraclePrice(
                token,
                data
            );

            // for atomic providers, the timestamp will be the current block's timestamp
            // the timestamp should not be adjusted
            if (!isAtomicProvider) {
                uint256 timestampAdjustment = dataStore.getUint(Keys.oracleTimestampAdjustmentKey(provider, token));
                validatedPrice.timestamp -= timestampAdjustment;
            }

            if (validatedPrice.timestamp + maxPriceAge < Chain.currentTimestamp()) {
                revert Errors.MaxPriceAgeExceeded(validatedPrice.timestamp, Chain.currentTimestamp());
            }

            // for atomic providers, assume that Chainlink would be the main provider
            // so it would be redundant to re-fetch the Chainlink price for validation
            if (!isAtomicProvider) {
                (bool hasRefPrice, uint256 refPrice) = ChainlinkPriceFeedUtils.getPriceFeedPrice(dataStore, token);

                if (hasRefPrice) {
                    _validateRefPrice(
                        token,
                        validatedPrice.min,
                        refPrice,
                        maxRefPriceDeviationFactor
                    );

                    _validateRefPrice(
                        token,
                        validatedPrice.max,
                        refPrice,
                        maxRefPriceDeviationFactor
                    );
                }
            }

            prices[i] = validatedPrice;
        }

        return prices;
    }

    function _validateRefPrice(
        address token,
        uint256 price,
        uint256 refPrice,
        uint256 maxRefPriceDeviationFactor
    ) internal pure {
        uint256 diff = Calc.diff(price, refPrice);
        uint256 diffFactor = Precision.toFactor(diff, refPrice);

        if (diffFactor > maxRefPriceDeviationFactor) {
            revert Errors.MaxRefPriceDeviationExceeded(
                token,
                price,
                refPrice,
                maxRefPriceDeviationFactor
            );
        }
    }

    function _setPrimaryPrice(address token, Price.Props memory price) internal {
        if (price.min > price.max) {
            revert Errors.InvalidMinMaxForPrice(token, price.min, price.max);
        }

        Price.Props memory existingPrice = primaryPrices[token];

        if (!existingPrice.isEmpty()) {
            revert Errors.PriceAlreadySet(token, existingPrice.min, existingPrice.max);
        }

        primaryPrices[token] = price;
        tokensWithPrices.add(token);
    }

    function _removePrimaryPrice(address token) internal {
        delete primaryPrices[token];
        tokensWithPrices.remove(token);
    }

    function _emitOraclePriceUpdated(
        address token,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 timestamp,
        address provider
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "provider", provider);

        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "minPrice", minPrice);
        eventData.uintItems.setItem(1, "maxPrice", maxPrice);
        eventData.uintItems.setItem(2, "timestamp", timestamp);

        eventEmitter.emitEventLog1(
            "OraclePriceUpdate",
            Cast.toBytes32(token),
            eventData
        );
    }
}
