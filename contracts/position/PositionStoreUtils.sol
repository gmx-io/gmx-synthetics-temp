// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/Keys.sol";
import "../data/DataStore.sol";

import "./Position.sol";

/**
 * @title PositionStoreUtils
 * @dev Library for position storage functions
 */
library PositionStoreUtils {
    using Position for Position.Props;

    bytes32 public constant ACCOUNT = keccak256(abi.encode("ACCOUNT"));
    bytes32 public constant MARKET = keccak256(abi.encode("MARKET"));
    bytes32 public constant COLLATERAL_TOKEN = keccak256(abi.encode("COLLATERAL_TOKEN"));

    bytes32 public constant SIZE_IN_USD = keccak256(abi.encode("SIZE_IN_USD"));
    bytes32 public constant SIZE_IN_TOKENS = keccak256(abi.encode("SIZE_IN_TOKENS"));
    bytes32 public constant COLLATERAL_AMOUNT = keccak256(abi.encode("COLLATERAL_AMOUNT"));
    bytes32 public constant PENDING_IMPACT_AMOUNT = keccak256(abi.encode("PENDING_IMPACT_AMOUNT"));
    bytes32 public constant BORROWING_FACTOR = keccak256(abi.encode("BORROWING_FACTOR"));
    bytes32 public constant FUNDING_FEE_AMOUNT_PER_SIZE = keccak256(abi.encode("FUNDING_FEE_AMOUNT_PER_SIZE"));
    bytes32 public constant LONG_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE = keccak256(abi.encode("LONG_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE"));
    bytes32 public constant SHORT_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE = keccak256(abi.encode("SHORT_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE"));
    bytes32 public constant INCREASED_AT_TIME = keccak256(abi.encode("INCREASED_AT_TIME"));
    bytes32 public constant DECREASED_AT_TIME = keccak256(abi.encode("DECREASED_AT_TIME"));

    bytes32 public constant IS_LONG = keccak256(abi.encode("IS_LONG"));

    function get(DataStore dataStore, bytes32 key) external view returns (Position.Props memory) {
        Position.Props memory position;
        if (!dataStore.containsBytes32(Keys.POSITION_LIST, key)) {
            return position;
        }

        position.setAccount(dataStore.getAddress(
            keccak256(abi.encode(key, ACCOUNT))
        ));

        position.setMarket(dataStore.getAddress(
            keccak256(abi.encode(key, MARKET))
        ));

        position.setCollateralToken(dataStore.getAddress(
            keccak256(abi.encode(key, COLLATERAL_TOKEN))
        ));

        position.setSizeInUsd(dataStore.getUint(
            keccak256(abi.encode(key, SIZE_IN_USD))
        ));

        position.setSizeInTokens(dataStore.getUint(
            keccak256(abi.encode(key, SIZE_IN_TOKENS))
        ));

        position.setCollateralAmount(dataStore.getUint(
            keccak256(abi.encode(key, COLLATERAL_AMOUNT))
        ));

        position.setPendingImpactAmount(dataStore.getInt(
            keccak256(abi.encode(key, PENDING_IMPACT_AMOUNT))
        ));

        position.setBorrowingFactor(dataStore.getUint(
            keccak256(abi.encode(key, BORROWING_FACTOR))
        ));

        position.setFundingFeeAmountPerSize(dataStore.getUint(
            keccak256(abi.encode(key, FUNDING_FEE_AMOUNT_PER_SIZE))
        ));

        position.setLongTokenClaimableFundingAmountPerSize(dataStore.getUint(
            keccak256(abi.encode(key, LONG_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE))
        ));

        position.setShortTokenClaimableFundingAmountPerSize(dataStore.getUint(
            keccak256(abi.encode(key, SHORT_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE))
        ));

        position.setIncreasedAtTime(dataStore.getUint(
            keccak256(abi.encode(key, INCREASED_AT_TIME))
        ));

        position.setDecreasedAtTime(dataStore.getUint(
            keccak256(abi.encode(key, DECREASED_AT_TIME))
        ));

        position.setIsLong(dataStore.getBool(
            keccak256(abi.encode(key, IS_LONG))
        ));

        return position;
    }

    function set(DataStore dataStore, bytes32 key, Position.Props memory position) external {
        dataStore.addBytes32(
            Keys.POSITION_LIST,
            key
        );

        dataStore.addBytes32(
            Keys.accountPositionListKey(position.account()),
            key
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, ACCOUNT)),
            position.account()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, MARKET)),
            position.market()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, COLLATERAL_TOKEN)),
            position.collateralToken()
        );

        dataStore.setInt(
            keccak256(abi.encode(key, PENDING_IMPACT_AMOUNT)),
            position.pendingImpactAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, SIZE_IN_USD)),
            position.sizeInUsd()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, SIZE_IN_TOKENS)),
            position.sizeInTokens()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, COLLATERAL_AMOUNT)),
            position.collateralAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, BORROWING_FACTOR)),
            position.borrowingFactor()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, FUNDING_FEE_AMOUNT_PER_SIZE)),
            position.fundingFeeAmountPerSize()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, LONG_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE)),
            position.longTokenClaimableFundingAmountPerSize()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, SHORT_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE)),
            position.shortTokenClaimableFundingAmountPerSize()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, INCREASED_AT_TIME)),
            position.increasedAtTime()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, DECREASED_AT_TIME)),
            position.decreasedAtTime()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, IS_LONG)),
            position.isLong()
        );
    }

    function remove(DataStore dataStore, bytes32 key, address account) external {
        if (!dataStore.containsBytes32(Keys.POSITION_LIST, key)) {
            revert Errors.PositionNotFound(key);
        }

        dataStore.removeBytes32(
            Keys.POSITION_LIST,
            key
        );

        dataStore.removeBytes32(
            Keys.accountPositionListKey(account),
            key
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, ACCOUNT))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, MARKET))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, COLLATERAL_TOKEN))
        );

        dataStore.removeInt(
            keccak256(abi.encode(key, PENDING_IMPACT_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, SIZE_IN_USD))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, SIZE_IN_TOKENS))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, COLLATERAL_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, BORROWING_FACTOR))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, FUNDING_FEE_AMOUNT_PER_SIZE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, LONG_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, SHORT_TOKEN_CLAIMABLE_FUNDING_AMOUNT_PER_SIZE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, INCREASED_AT_TIME))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, DECREASED_AT_TIME))
        );

        dataStore.removeBool(
            keccak256(abi.encode(key, IS_LONG))
        );
    }

    function getPositionCount(DataStore dataStore) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.POSITION_LIST);
    }

    function getPositionKeys(DataStore dataStore, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.POSITION_LIST, start, end);
    }

    function getAccountPositionCount(DataStore dataStore, address account) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.accountPositionListKey(account));
    }

    function getAccountPositionKeys(DataStore dataStore, address account, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.accountPositionListKey(account), start, end);
    }
}
