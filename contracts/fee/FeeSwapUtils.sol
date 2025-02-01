// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../v1/IRouterV1.sol";

import "../data/DataStore.sol";
import "../fee/FeeBatchStoreUtils.sol";
import "../market/Market.sol";
import "../router/IExchangeRouter.sol";

// @title FeeSwapUtils
library FeeSwapUtils {
    function swapFeesUsingV1(
        DataStore dataStore,
        IRouterV1 routerV1,
        address bridgingToken,
        bytes32 feeBatchKey,
        uint256 tokenIndex,
        address[] memory path,
        uint256 swapAmount,
        uint256 minOut
    ) external {
        (FeeBatch.Props memory feeBatch, address tokenIn) = _getSwapValues(
            dataStore,
            feeBatchKey,
            tokenIndex,
            swapAmount
        );

        if (path[path.length - 1] != bridgingToken) {
            revert Errors.InvalidSwapPathForV1(path, bridgingToken);
        }

        feeBatch.remainingAmounts[tokenIndex] -= swapAmount;
        FeeBatchStoreUtils.set(dataStore, feeBatchKey, feeBatch);

        IERC20(tokenIn).approve(address(routerV1), swapAmount);
        routerV1.swap(path, swapAmount, minOut, address(this));
    }

    function swapFeesUsingV2(
        DataStore dataStore,
        address routerV2,
        IExchangeRouter exchangeRouterV2,
        address bridgingToken,
        bytes32 feeBatchKey,
        uint256 tokenIndex,
        address market,
        address[] memory swapPath,
        uint256 swapAmount,
        uint256 executionFee,
        uint256 minOut
    ) external {
        (FeeBatch.Props memory feeBatch, address tokenIn) = _getSwapValues(
            dataStore,
            feeBatchKey,
            tokenIndex,
            swapAmount
        );

        SwapUtils.validateSwapOutputToken(dataStore, swapPath, tokenIn, bridgingToken);

        IBaseOrderUtils.CreateOrderParams memory params = _getSwapOrderParamsV2(
            dataStore,
            market,
            tokenIn,
            swapPath,
            swapAmount,
            executionFee,
            minOut
        );

        feeBatch.remainingAmounts[tokenIndex] -= swapAmount;
        FeeBatchStoreUtils.set(dataStore, feeBatchKey, feeBatch);

        IERC20(tokenIn).approve(routerV2, swapAmount);
        bytes32 orderKey = exchangeRouterV2.createOrder{ value: msg.value }(params);
        dataStore.setBytes32(Keys.feeDistributorSwapFeeBatchKey(orderKey), feeBatchKey);
        dataStore.setUint(Keys.feeDistributorSwapTokenIndexKey(orderKey), tokenIndex);
    }

    function _getSwapValues(
        DataStore dataStore,
        bytes32 feeBatchKey,
        uint256 tokenIndex,
        uint256 swapAmount
    ) internal view returns (FeeBatch.Props memory, address) {
        FeeBatch.Props memory feeBatch = FeeBatchStoreUtils.get(dataStore, feeBatchKey);

        if (tokenIndex > feeBatch.feeTokens.length) {
            revert Errors.InvalidFeeBatchTokenIndex(tokenIndex, feeBatch.feeTokens.length);
        }

        address tokenIn = feeBatch.feeTokens[tokenIndex];
        uint256 remainingAmount = feeBatch.remainingAmounts[tokenIndex];
        if (swapAmount > remainingAmount) {
            revert Errors.InvalidAmountInForFeeBatch(swapAmount, remainingAmount);
        }

        return (feeBatch, tokenIn);
    }

    function _getSwapOrderParamsV2(
        DataStore dataStore,
        address market,
        address tokenIn,
        address[] memory swapPath,
        uint256 swapAmount,
        uint256 executionFee,
        uint256 minOut
    ) internal view returns (IBaseOrderUtils.CreateOrderParams memory) {
        IBaseOrderUtils.CreateOrderParamsAddresses memory addresses = IBaseOrderUtils.CreateOrderParamsAddresses(
            address(this), // receiver
            address(this), // cancellationReceiver
            address(this), // callbackContract
            address(0), // uiFeeReceiver
            market, // market
            tokenIn, // initialCollateralToken
            swapPath // swapPath
        );

        uint256 maxCallbackGasLimit = dataStore.getUint(Keys.MAX_CALLBACK_GAS_LIMIT);

        IBaseOrderUtils.CreateOrderParamsNumbers memory numbers = IBaseOrderUtils.CreateOrderParamsNumbers(
            0, // sizeDeltaUsd
            swapAmount, // initialCollateralDeltaAmount
            0, // triggerPrice
            0, // acceptablePrice
            executionFee, // executionFee
            maxCallbackGasLimit, // callbackGasLimit
            minOut, // minOutputAmount
            0 // validFromTime
        );

        IBaseOrderUtils.CreateOrderParams memory params = IBaseOrderUtils.CreateOrderParams(
            addresses, // addresses
            numbers, // numbers
            Order.OrderType.MarketSwap, // orderType
            Order.DecreasePositionSwapType.NoSwap, // decreasePositionSwapType
            false, // isLong
            false, // shouldUnwrapNativeToken
            false, // autoCancel
            bytes32(0), // referralCode
            new bytes32[](0) // dataList
        );

        return params;
    }
}
