
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../market/MarketStoreUtils.sol";

/**
 * @title MarketStoreUtilsTest
 * @dev Contract to help test the MarketStoreUtils library
 */
contract MarketStoreUtilsTest {
    function getEmptyMarket() external pure returns (Market.Props memory) {
        Market.Props memory market;
        return market;
    }

    function setMarket(DataStore dataStore, address key, bytes32 salt, Market.Props memory market) external {
        MarketStoreUtils.set(dataStore, key, salt, market);
    }

    function removeMarket(DataStore dataStore, address key, bytes32 salt) external {
        MarketStoreUtils.remove(dataStore, key, salt);
    }
}
