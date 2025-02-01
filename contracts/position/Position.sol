// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

// @title Position
// @dev Stuct for positions
//
// borrowing fees for position require only a borrowingFactor to track
// an example on how this works is if the global cumulativeBorrowingFactor is 10020%
// a position would be opened with borrowingFactor as 10020%
// after some time, if the cumulativeBorrowingFactor is updated to 10025% the position would
// owe 5% of the position size as borrowing fees
// the total pending borrowing fees of all positions is factored into the calculation of the pool value for LPs
// when a position is increased or decreased, the pending borrowing fees for the position is deducted from the position's
// collateral and transferred into the LP pool
//
// the same borrowing fee factor tracking cannot be applied for funding fees as those calculations consider pending funding fees
// based on the fiat value of the position sizes
//
// for example, if the price of the longToken is $2000 and a long position owes $200 in funding fees, the opposing short position
// claims the funding fees of 0.1 longToken ($200), if the price of the longToken changes to $4000 later, the long position would
// only owe 0.05 longToken ($200)
// this would result in differences between the amounts deducted and amounts paid out, for this reason, the actual token amounts
// to be deducted and to be paid out need to be tracked instead
//
// for funding fees, there are four values to consider:
// 1. long positions with market.longToken as collateral
// 2. long positions with market.shortToken as collateral
// 3. short positions with market.longToken as collateral
// 4. short positions with market.shortToken as collateral
library Position {
    // @dev there is a limit on the number of fields a struct can have when being passed
    // or returned as a memory variable which can cause "Stack too deep" errors
    // use sub-structs to avoid this issue
    // @param addresses address values
    // @param numbers number values
    // @param flags boolean values
    struct Props {
        Addresses addresses;
        Numbers numbers;
        Flags flags;
    }

    // @param account the position's account
    // @param market the position's market
    // @param collateralToken the position's collateralToken
    struct Addresses {
        address account;
        address market;
        address collateralToken;
    }

    // @param sizeInUsd the position's size in USD
    // @param sizeInTokens the position's size in tokens
    // @param collateralAmount the amount of collateralToken for collateral
    // @param pendingImpactAmount the amount of pending impact for the position
    // @param borrowingFactor the position's borrowing factor
    // @param fundingFeeAmountPerSize the position's funding fee per size
    // @param longTokenClaimableFundingAmountPerSize the position's claimable funding amount per size
    // for the market.longToken
    // @param shortTokenClaimableFundingAmountPerSize the position's claimable funding amount per size
    // for the market.shortToken
    // @param increasedAtTime the time at which this position was increased
    // @param decreasedAtTime the time at which this position was decreased
    struct Numbers {
        uint256 sizeInUsd;
        uint256 sizeInTokens;
        uint256 collateralAmount;
        int256 pendingImpactAmount;
        uint256 borrowingFactor;
        uint256 fundingFeeAmountPerSize;
        uint256 longTokenClaimableFundingAmountPerSize;
        uint256 shortTokenClaimableFundingAmountPerSize;
        uint256 increasedAtTime;
        uint256 decreasedAtTime;
    }

    // @param isLong whether the position is a long or short
    struct Flags {
        bool isLong;
    }

    function account(Props memory props) internal pure returns (address) {
        return props.addresses.account;
    }

    function setAccount(Props memory props, address value) internal pure {
        props.addresses.account = value;
    }

    function market(Props memory props) internal pure returns (address) {
        return props.addresses.market;
    }

    function setMarket(Props memory props, address value) internal pure {
        props.addresses.market = value;
    }

    function collateralToken(Props memory props) internal pure returns (address) {
        return props.addresses.collateralToken;
    }

    function setCollateralToken(Props memory props, address value) internal pure {
        props.addresses.collateralToken = value;
    }

    function sizeInUsd(Props memory props) internal pure returns (uint256) {
        return props.numbers.sizeInUsd;
    }

    function setSizeInUsd(Props memory props, uint256 value) internal pure {
        props.numbers.sizeInUsd = value;
    }

    function sizeInTokens(Props memory props) internal pure returns (uint256) {
        return props.numbers.sizeInTokens;
    }

    function setSizeInTokens(Props memory props, uint256 value) internal pure {
        props.numbers.sizeInTokens = value;
    }

    function collateralAmount(Props memory props) internal pure returns (uint256) {
        return props.numbers.collateralAmount;
    }

    function setCollateralAmount(Props memory props, uint256 value) internal pure {
        props.numbers.collateralAmount = value;
    }

    function pendingImpactAmount(Props memory props) internal pure returns (int256) {
        return props.numbers.pendingImpactAmount;
    }

    function setPendingImpactAmount(Props memory props, int256 value) internal pure {
        props.numbers.pendingImpactAmount = value;
    }

    function borrowingFactor(Props memory props) internal pure returns (uint256) {
        return props.numbers.borrowingFactor;
    }

    function setBorrowingFactor(Props memory props, uint256 value) internal pure {
        props.numbers.borrowingFactor = value;
    }

    function fundingFeeAmountPerSize(Props memory props) internal pure returns (uint256) {
        return props.numbers.fundingFeeAmountPerSize;
    }

    function setFundingFeeAmountPerSize(Props memory props, uint256 value) internal pure {
        props.numbers.fundingFeeAmountPerSize = value;
    }

    function longTokenClaimableFundingAmountPerSize(Props memory props) internal pure returns (uint256) {
        return props.numbers.longTokenClaimableFundingAmountPerSize;
    }

    function setLongTokenClaimableFundingAmountPerSize(Props memory props, uint256 value) internal pure {
        props.numbers.longTokenClaimableFundingAmountPerSize = value;
    }

    function shortTokenClaimableFundingAmountPerSize(Props memory props) internal pure returns (uint256) {
        return props.numbers.shortTokenClaimableFundingAmountPerSize;
    }

    function setShortTokenClaimableFundingAmountPerSize(Props memory props, uint256 value) internal pure {
        props.numbers.shortTokenClaimableFundingAmountPerSize = value;
    }

    function increasedAtTime(Props memory props) internal pure returns (uint256) {
        return props.numbers.increasedAtTime;
    }

    function setIncreasedAtTime(Props memory props, uint256 value) internal pure {
        props.numbers.increasedAtTime = value;
    }

    function decreasedAtTime(Props memory props) internal pure returns (uint256) {
        return props.numbers.decreasedAtTime;
    }

    function setDecreasedAtTime(Props memory props, uint256 value) internal pure {
        props.numbers.decreasedAtTime = value;
    }

    function isLong(Props memory props) internal pure returns (bool) {
        return props.flags.isLong;
    }

    function setIsLong(Props memory props, bool value) internal pure {
        props.flags.isLong = value;
    }

    // @dev get the key for a position
    // @param account the position's account
    // @param market the position's market
    // @param collateralToken the position's collateralToken
    // @param isLong whether the position is long or short
    // @return the position key
    function getPositionKey(address _account, address _market, address _collateralToken, bool _isLong) internal pure returns (bytes32) {
        bytes32 _key = keccak256(abi.encode(_account, _market, _collateralToken, _isLong));
        return _key;
    }
}
