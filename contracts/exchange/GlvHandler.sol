// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./BaseHandler.sol";

import "../glv/Glv.sol";
import "../glv/GlvUtils.sol";
import "../glv/GlvDepositUtils.sol";
import "../glv/GlvDepositStoreUtils.sol";
import "../glv/GlvWithdrawalUtils.sol";
import "../glv/GlvWithdrawalStoreUtils.sol";
import "../glv/GlvVault.sol";
import "../glv/GlvShiftUtils.sol";
import "../glv/GlvDeposit.sol";
import "../glv/GlvWithdrawal.sol";

contract GlvHandler is BaseHandler, ReentrancyGuard {
    using GlvDeposit for GlvDeposit.Props;
    using GlvShift for GlvShift.Props;
    using GlvWithdrawal for GlvWithdrawal.Props;

    GlvVault public immutable glvVault;
    ShiftVault public immutable shiftVault;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        GlvVault _glvVault,
        ShiftVault _shiftVault
    ) BaseHandler(_roleStore, _dataStore, _eventEmitter, _oracle) {
        glvVault = _glvVault;
        shiftVault = _shiftVault;
    }

    function createGlvDeposit(
        address account,
        GlvDepositUtils.CreateGlvDepositParams calldata params
    ) external globalNonReentrant onlyController returns (bytes32) {
        FeatureUtils.validateFeature(dataStore, Keys.createGlvDepositFeatureDisabledKey(address(this)));

        return GlvDepositUtils.createGlvDeposit(dataStore, eventEmitter, glvVault, account, params);
    }

    function executeGlvDeposit(
        bytes32 key,
        OracleUtils.SetPricesParams calldata oracleParams
    ) external globalNonReentrant onlyOrderKeeper withOraclePrices(oracleParams) {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(_dataStore, Keys.executeGlvDepositFeatureDisabledKey(address(this)));

        GlvDeposit.Props memory glvDeposit = GlvDepositStoreUtils.get(_dataStore, key);
        uint256 marketCount = GlvUtils.getMarketCount(_dataStore, glvDeposit.glv());
        uint256 estimatedGasLimit = GasUtils.estimateExecuteGlvDepositGasLimit(_dataStore, glvDeposit, marketCount);
        GasUtils.validateExecutionGas(_dataStore, startingGas, estimatedGasLimit);

        uint256 executionGas = GasUtils.getExecutionGas(_dataStore, startingGas);

        try this._executeGlvDeposit{gas: executionGas}(key, glvDeposit, msg.sender) {} catch (
            bytes memory reasonBytes
        ) {
            _handleGlvDepositError(key, startingGas, reasonBytes);
        }
    }

    function _executeGlvDeposit(bytes32 key, GlvDeposit.Props memory glvDeposit, address keeper) external onlySelf {
        uint256 startingGas = gasleft();

        GlvDepositUtils.ExecuteGlvDepositParams memory params = GlvDepositUtils.ExecuteGlvDepositParams({
            key: key,
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            glvVault: glvVault,
            oracle: oracle,
            startingGas: startingGas,
            keeper: keeper
        });

        GlvDepositUtils.executeGlvDeposit(params, glvDeposit);
    }

    function _handleGlvDepositError(bytes32 key, uint256 startingGas, bytes memory reasonBytes) internal {
        GasUtils.validateExecutionErrorGas(dataStore, reasonBytes);

        bytes4 errorSelector = ErrorUtils.getErrorSelectorFromData(reasonBytes);

        if (OracleUtils.isOracleError(errorSelector) || errorSelector == Errors.DisabledFeature.selector) {
            ErrorUtils.revertWithCustomError(reasonBytes);
        }

        (string memory reason /* bool hasRevertMessage */, ) = ErrorUtils.getRevertMessage(reasonBytes);

        GlvDepositUtils.cancelGlvDeposit(
            dataStore,
            eventEmitter,
            glvVault,
            key,
            msg.sender,
            startingGas,
            reason,
            reasonBytes
        );
    }

    function cancelGlvDeposit(bytes32 key) external globalNonReentrant onlyController {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(_dataStore, Keys.cancelGlvDepositFeatureDisabledKey(address(this)));

        GlvDeposit.Props memory glvDeposit = GlvDepositStoreUtils.get(_dataStore, key);
        validateRequestCancellation(glvDeposit.updatedAtTime(), "GlvDeposit");

        GlvDepositUtils.cancelGlvDeposit(
            _dataStore,
            eventEmitter,
            glvVault,
            key,
            msg.sender,
            startingGas,
            Keys.USER_INITIATED_CANCEL,
            ""
        );
    }

    function createGlvWithdrawal(
        address account,
        GlvWithdrawalUtils.CreateGlvWithdrawalParams calldata params
    ) external globalNonReentrant onlyController returns (bytes32) {
        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(_dataStore, Keys.createGlvWithdrawalFeatureDisabledKey(address(this)));

        return GlvWithdrawalUtils.createGlvWithdrawal(_dataStore, eventEmitter, glvVault, account, params);
    }

    function executeGlvWithdrawal(
        bytes32 key,
        OracleUtils.SetPricesParams calldata oracleParams
    ) external globalNonReentrant onlyOrderKeeper withOraclePrices(oracleParams) {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(_dataStore, Keys.executeGlvWithdrawalFeatureDisabledKey(address(this)));

        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawalStoreUtils.get(_dataStore, key);
        uint256 marketCount = GlvUtils.getMarketCount(_dataStore, glvWithdrawal.glv());
        uint256 estimatedGasLimit = GasUtils.estimateExecuteGlvWithdrawalGasLimit(
            _dataStore,
            glvWithdrawal,
            marketCount
        );
        GasUtils.validateExecutionGas(_dataStore, startingGas, estimatedGasLimit);

        uint256 executionGas = GasUtils.getExecutionGas(_dataStore, startingGas);

        try this._executeGlvWithdrawal{gas: executionGas}(key, glvWithdrawal, msg.sender) {} catch (
            bytes memory reasonBytes
        ) {
            _handleGlvWithdrawalError(key, startingGas, reasonBytes);
        }
    }

    function _executeGlvWithdrawal(
        bytes32 key,
        GlvWithdrawal.Props memory glvWithdrawal,
        address keeper
    ) external onlySelf {
        uint256 startingGas = gasleft();

        GlvWithdrawalUtils.ExecuteGlvWithdrawalParams memory params = GlvWithdrawalUtils.ExecuteGlvWithdrawalParams({
            key: key,
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            glvVault: glvVault,
            oracle: oracle,
            startingGas: startingGas,
            keeper: keeper
        });

        GlvWithdrawalUtils.executeGlvWithdrawal(params, glvWithdrawal);
    }

    function _handleGlvWithdrawalError(bytes32 key, uint256 startingGas, bytes memory reasonBytes) internal {
        GasUtils.validateExecutionErrorGas(dataStore, reasonBytes);

        bytes4 errorSelector = ErrorUtils.getErrorSelectorFromData(reasonBytes);

        if (OracleUtils.isOracleError(errorSelector) || errorSelector == Errors.DisabledFeature.selector) {
            ErrorUtils.revertWithCustomError(reasonBytes);
        }

        (string memory reason /* bool hasRevertMessage */, ) = ErrorUtils.getRevertMessage(reasonBytes);

        GlvWithdrawalUtils.cancelGlvWithdrawal(
            dataStore,
            eventEmitter,
            glvVault,
            key,
            msg.sender,
            startingGas,
            reason,
            reasonBytes
        );
    }

    function cancelGlvWithdrawal(bytes32 key) external globalNonReentrant onlyController {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(_dataStore, Keys.cancelGlvWithdrawalFeatureDisabledKey(address(this)));

        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawalStoreUtils.get(_dataStore, key);
        validateRequestCancellation(glvWithdrawal.updatedAtTime(), "GlvWithdrawal");

        GlvWithdrawalUtils.cancelGlvWithdrawal(
            _dataStore,
            eventEmitter,
            glvVault,
            key,
            msg.sender,
            startingGas,
            Keys.USER_INITIATED_CANCEL,
            ""
        );
    }

    // @dev simulate execution of a glv deposit to check for any errors
    // @param key the glv deposit key
    // @param params OracleUtils.SimulatePricesParams
    function simulateExecuteGlvDeposit(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory params
    ) external onlyController withSimulatedOraclePrices(params) globalNonReentrant {
        GlvDeposit.Props memory glvDeposit = GlvDepositStoreUtils.get(dataStore, key);

        this._executeGlvDeposit(key, glvDeposit, msg.sender);
    }

    // @dev simulate execution of a glv withdrawal to check for any errors
    // @param key the glv withdrawal key
    // @param params OracleUtils.SimulatePricesParams
    function simulateExecuteGlvWithdrawal(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory params
    ) external onlyController withSimulatedOraclePrices(params) globalNonReentrant {
        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawalStoreUtils.get(dataStore, key);

        this._executeGlvWithdrawal(key, glvWithdrawal, msg.sender);
    }

    function createGlvShift(
        address glv,
        GlvShiftUtils.CreateGlvShiftParams memory params
    ) external globalNonReentrant onlyOrderKeeper returns (bytes32) {
        FeatureUtils.validateFeature(dataStore, Keys.glvCreateShiftFeatureDisabledKey(address(this)));

        return GlvShiftUtils.createGlvShift(dataStore, eventEmitter, glvVault, glv, params);
    }

    function executeGlvShift(
        bytes32 key,
        OracleUtils.SetPricesParams calldata oracleParams
    ) external globalNonReentrant onlyOrderKeeper withOraclePrices(oracleParams) {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(dataStore, Keys.glvExecuteShiftFeatureDisabledKey(address(this)));

        GlvShift.Props memory glvShift = GlvShiftStoreUtils.get(_dataStore, key);
        uint256 estimatedGasLimit = GasUtils.estimateExecuteGlvShiftGasLimit(_dataStore);
        GasUtils.validateExecutionGas(_dataStore, startingGas, estimatedGasLimit);

        uint256 executionGas = GasUtils.getExecutionGas(_dataStore, startingGas);

        try this._executeGlvShift{gas: executionGas}(key, glvShift, msg.sender) {} catch (bytes memory reasonBytes) {
            _handleGlvShiftError(key, startingGas, reasonBytes);
        }
    }

    function _executeGlvShift(bytes32 key, GlvShift.Props memory glvShift, address keeper) external onlySelf {
        uint256 startingGas = gasleft();

        GlvShiftUtils.ExecuteGlvShiftParams memory params = GlvShiftUtils.ExecuteGlvShiftParams({
            key: key,
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            shiftVault: shiftVault,
            oracle: oracle,
            startingGas: startingGas,
            keeper: keeper
        });

        GlvShiftUtils.executeGlvShift(params, glvShift);
    }

    function _handleGlvShiftError(bytes32 key, uint256 startingGas, bytes memory reasonBytes) internal {
        GasUtils.validateExecutionErrorGas(dataStore, reasonBytes);

        bytes4 errorSelector = ErrorUtils.getErrorSelectorFromData(reasonBytes);

        if (OracleUtils.isOracleError(errorSelector) || errorSelector == Errors.DisabledFeature.selector) {
            ErrorUtils.revertWithCustomError(reasonBytes);
        }

        (string memory reason /* bool hasRevertMessage */, ) = ErrorUtils.getRevertMessage(reasonBytes);

        GlvShiftUtils.cancelGlvShift(
            dataStore,
            eventEmitter,
            glvVault,
            key,
            msg.sender,
            startingGas,
            reason,
            reasonBytes
        );
    }

    function addMarket(address glv, address market) external onlyConfigKeeper {
        GlvUtils.addMarket(dataStore, glv, market);
    }
}
