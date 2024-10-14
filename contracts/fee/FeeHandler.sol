// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../role/RoleModule.sol";
import "../oracle/OracleModule.sol";
import "../utils/BasicMulticall.sol";
import "../fee/FeeUtils.sol";
import "../v1/IVaultV1.sol";
import "../v1/IVaultGovV1.sol";

// @title FeeHandler
contract FeeHandler is ReentrancyGuard, RoleModule, OracleModule, BasicMulticall {
    using SafeERC20 for IERC20;

    struct FeeAmounts {
        uint256 gmx;
        uint256 wnt;
    }

    uint256 public constant v1 = 1;
    uint256 public constant v2 = 2;

    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;
    IVaultV1 public immutable vaultV1;
    address public immutable gmx;

    constructor(
        RoleStore _roleStore,
        Oracle _oracle,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        IVaultV1 _vaultV1,
        address _gmx
    ) RoleModule(_roleStore) OracleModule(_oracle) {
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
        vaultV1 = _vaultV1;
        gmx = _gmx;
    }

    // @dev withdraw fees in buybackTokens from this contract
    // @param marketTokens the markets from which to withdraw fees
    // @param buybackToken the token for which to withdraw fees
    function withdrawFees(address[] calldata markets, address buybackToken) external nonReentrant onlyFeeKeeper {
        _validateBuybackToken(_getBatchSize(buybackToken), buybackToken);

        for (uint256 i; i < markets.length; i++) {
            FeeUtils.claimFees(dataStore, eventEmitter, markets[i], buybackToken, address(this));
        }

        address receiver = dataStore.getAddress(Keys.FEE_RECEIVER);
        IERC20(buybackToken).safeTransfer(receiver, IERC20(buybackToken).balanceOf(address(this)));
    }

    // @dev claim fees in feeToken from the specified markets
    // @param market the market from which to claim fees
    // @param feeToken the fee tokens to claim from the market
    function claimFees(address market, address feeToken, uint256 version) external nonReentrant {
        if (_getBatchSize(feeToken) != 0) {
            revert Errors.InvalidFeeToken(feeToken);
        }

        uint256 feeAmount;
        if (version == v1) {
            feeAmount = IVaultGovV1(vaultV1.gov()).withdrawFees(address(vaultV1), feeToken, address(this));
        } else if (version == v2) {
            feeAmount = FeeUtils.claimFees(dataStore, eventEmitter, market, feeToken, address(this));
        } else {
            revert Errors.InvalidVersion(version);
        }

        _incrementAvailableFeeAmounts(version, feeToken, feeAmount);
    }

    // @dev receive an amount in feeToken by depositing the batchSize amount of the buybackToken
    // @param feeToken the token to receive with the fee amount calculated via an oracle price
    // @param buybackToken the token to deposit in the amount of batchSize in return for fees
    // @param minOutputAmount the minimum amount of the feeToken that the caller will receive
    function buyback(
        address feeToken,
        address buybackToken,
        uint256 minOutputAmount,
        OracleUtils.SetPricesParams memory params
    ) external nonReentrant withOraclePrices(params) {
        if (feeToken == buybackToken) {
            revert Errors.BuybackAndFeeTokenAreEqual(feeToken, buybackToken);
        }

        uint256 batchSize = _getBatchSize(buybackToken);
        _validateBuybackToken(batchSize, buybackToken);

        uint256 availableFeeAmount = _getAvailableFeeAmount(feeToken, buybackToken);
        if (availableFeeAmount == 0) {
            revert Errors.AvailableFeeAmountIsZero(feeToken, buybackToken, availableFeeAmount);
        }

        uint256 maxFeeTokenAmount = _getMaxFeeTokenAmount(feeToken, buybackToken, batchSize);
        uint256 outputAmount = availableFeeAmount < maxFeeTokenAmount ? availableFeeAmount : maxFeeTokenAmount;

        if (outputAmount < minOutputAmount) {
            revert Errors.InsufficientBuybackOutputAmount(feeToken, buybackToken, outputAmount, minOutputAmount);
        }

        _buybackFees(feeToken, buybackToken, batchSize, outputAmount, availableFeeAmount);
    }

    function getOutputAmount(
        address[] calldata markets,
        address feeToken,
        address buybackToken,
        uint256 version
    ) external view returns (uint256) {
        uint256 batchSize = _getBatchSize(buybackToken);
        _validateBuybackToken(batchSize, buybackToken);

        uint256 feeAmount;
        uint256 availableFeeAmount = _getAvailableFeeAmount(feeToken, buybackToken);
        for (uint256 i; i < markets.length; i++) {
            if (version == v1) {
                feeAmount = vaultV1.feeReserves(feeToken);
            } else if (version == v2) {
                feeAmount = _getUint(Keys.claimableFeeAmountKey(markets[i], feeToken));
            } else {
                revert Errors.InvalidVersion(version);
            }

            FeeAmounts memory feeAmounts = _getFeeAmounts(version, feeAmount);
            feeAmount = buybackToken == gmx ? feeAmounts.gmx : feeAmounts.wnt;
            availableFeeAmount = availableFeeAmount + feeAmount;
        }

        uint256 maxFeeTokenAmount = _getMaxFeeTokenAmount(feeToken, buybackToken, batchSize);
        if (availableFeeAmount >= maxFeeTokenAmount) {
            return maxFeeTokenAmount;
        } else {
            return availableFeeAmount;
        }
    }

    function _buybackFees(
        address feeToken,
        address buybackToken,
        uint256 batchSize,
        uint256 buybackAmount,
        uint256 availableFeeAmount
    ) private {
        IERC20(buybackToken).safeTransferFrom(msg.sender, address(this), batchSize);
        IERC20(feeToken).safeTransfer(msg.sender, buybackAmount);

        _setAvailableFeeAmount(feeToken, buybackToken, availableFeeAmount - buybackAmount);
    }

    function _incrementAvailableFeeAmounts(uint256 version, address feeToken, uint256 feeAmount) private {
        address wnt = dataStore.getAddress(Keys.WNT);

        FeeAmounts memory feeAmounts = _getFeeAmounts(version, feeAmount);

        uint256 availableFeeAmountGmx = _getAvailableFeeAmount(feeToken, gmx) + feeAmounts.gmx;
        uint256 availableFeeAmountWnt = _getAvailableFeeAmount(feeToken, wnt) + feeAmounts.wnt;

        _setAvailableFeeAmount(feeToken, gmx, availableFeeAmountGmx);
        _setAvailableFeeAmount(feeToken, wnt, availableFeeAmountWnt);
    }

    function _setAvailableFeeAmount(address feeToken, address buybackToken, uint256 availableFeeAmount) private {
        dataStore.setUint(Keys.buybackAvailableFeeAmountKey(feeToken, buybackToken), availableFeeAmount);
    }

    function _getAvailableFeeAmount(address feeToken, address buybackToken) private view returns (uint256) {
        return _getUint(Keys.buybackAvailableFeeAmountKey(feeToken, buybackToken));
    }

    function _getFeeAmounts(uint256 version, uint256 feeAmount) private view returns (FeeAmounts memory) {
        uint256 gmxFactor = _getUint(Keys.buybackGmxFactorKey(version));
        FeeAmounts memory feeAmounts;

        feeAmounts.gmx = Precision.applyFactor(feeAmount, gmxFactor);
        feeAmounts.wnt = feeAmount - feeAmounts.gmx;
        return feeAmounts;
    }

    function _getMaxFeeTokenAmount(
        address feeToken,
        address buybackToken,
        uint256 batchSize
    ) private view returns (uint256) {
        uint256 priceTimestamp = oracle.minTimestamp();
        uint256 maxPriceAge = _getUint(Keys.buybackMaxPriceAgeKey());
        uint256 currentTimestamp = Chain.currentTimestamp();
        if ((priceTimestamp + maxPriceAge) < currentTimestamp) {
            revert Errors.PricesOlderThanMaxPriceAge(priceTimestamp, maxPriceAge, currentTimestamp);
        }

        uint256 feeTokenPrice = oracle.getPrimaryPrice(feeToken).max;
        uint256 buybackTokenPrice = oracle.getPrimaryPrice(buybackToken).min;

        uint256 expectedFeeTokenAmount = Precision.mulDiv(batchSize, buybackTokenPrice, feeTokenPrice);
        uint256 maxPriceImpactFactor = _getUint(Keys.buybackMaxPriceImpactFactorKey(feeToken)) +
            _getUint(Keys.buybackMaxPriceImpactFactorKey(buybackToken));

        return Precision.applyFactor(expectedFeeTokenAmount, maxPriceImpactFactor + Precision.FLOAT_PRECISION);
    }

    function _getBatchSize(address buybackToken) private view returns (uint256) {
        return _getUint(Keys.buybackBatchAmountKey(buybackToken));
    }

    function _getUint(bytes32 fullKey) private view returns (uint256) {
        return dataStore.getUint(fullKey);
    }

    function _validateBuybackToken(uint256 batchSize, address buybackToken) private pure {
        if (batchSize == 0) {
            revert Errors.InvalidBuybackToken(buybackToken);
        }
    }
}
