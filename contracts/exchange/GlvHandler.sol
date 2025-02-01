// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./BaseHandler.sol";

import "../glv/glvDeposit/GlvDepositUtils.sol";
import "../glv/glvWithdrawal/GlvWithdrawalUtils.sol";
import "../glv/glvShift/GlvShiftUtils.sol";

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
        validateDataListLength(params.dataList.length);

        return GlvDepositUtils.createGlvDeposit(dataStore, eventEmitter, glvVault, account, params);
    }

    // @key glvDeposit key
    // @oracleParams prices for all markets in GLV are required
    function executeGlvDeposit(
        bytes32 key,
        OracleUtils.SetPricesParams calldata oracleParams
    ) external globalNonReentrant onlyOrderKeeper withOraclePrices(oracleParams) {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;

        GlvDeposit.Props memory glvDeposit = GlvDepositStoreUtils.get(_dataStore, key);
        uint256 marketCount = GlvUtils.getGlvMarketCount(_dataStore, glvDeposit.glv());
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

        FeatureUtils.validateFeature(dataStore, Keys.executeGlvDepositFeatureDisabledKey(address(this)));

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

        validateNonKeeperError(errorSelector, reasonBytes);

        (string memory reason /* bool hasRevertMessage */, ) = ErrorUtils.getRevertMessage(reasonBytes);

        GlvDepositUtils.CancelGlvDepositParams memory params = GlvDepositUtils.CancelGlvDepositParams({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            glvVault: glvVault,
            key: key,
            keeper: msg.sender,
            startingGas: startingGas,
            reason: reason,
            reasonBytes: reasonBytes
        });
        GlvDepositUtils.cancelGlvDeposit(params);
    }

    function cancelGlvDeposit(bytes32 key) external globalNonReentrant onlyController {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(_dataStore, Keys.cancelGlvDepositFeatureDisabledKey(address(this)));

        GlvDeposit.Props memory glvDeposit = GlvDepositStoreUtils.get(_dataStore, key);
        validateRequestCancellation(glvDeposit.updatedAtTime(), "GlvDeposit");

        GlvDepositUtils.CancelGlvDepositParams memory params = GlvDepositUtils.CancelGlvDepositParams({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            glvVault: glvVault,
            key: key,
            keeper: glvDeposit.account(),
            startingGas: startingGas,
            reason: Keys.USER_INITIATED_CANCEL,
            reasonBytes: ""
        });
        GlvDepositUtils.cancelGlvDeposit(params);
    }

    function createGlvWithdrawal(
        address account,
        GlvWithdrawalUtils.CreateGlvWithdrawalParams calldata params
    ) external globalNonReentrant onlyController returns (bytes32) {
        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(_dataStore, Keys.createGlvWithdrawalFeatureDisabledKey(address(this)));

        return GlvWithdrawalUtils.createGlvWithdrawal(_dataStore, eventEmitter, glvVault, account, params);
    }

    // @key glvDeposit key
    // @oracleParams prices for all markets in GLV are required
    function executeGlvWithdrawal(
        bytes32 key,
        OracleUtils.SetPricesParams calldata oracleParams
    ) external globalNonReentrant onlyOrderKeeper withOraclePrices(oracleParams) {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;

        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawalStoreUtils.get(_dataStore, key);
        uint256 marketCount = GlvUtils.getGlvMarketCount(_dataStore, glvWithdrawal.glv());
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

        FeatureUtils.validateFeature(dataStore, Keys.executeGlvWithdrawalFeatureDisabledKey(address(this)));

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

        validateNonKeeperError(errorSelector, reasonBytes);

        (string memory reason /* bool hasRevertMessage */, ) = ErrorUtils.getRevertMessage(reasonBytes);

        GlvWithdrawalUtils.CancelGlvWithdrawalParams memory params = GlvWithdrawalUtils.CancelGlvWithdrawalParams({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            glvVault: glvVault,
            key: key,
            keeper: msg.sender,
            startingGas: startingGas,
            reason: reason,
            reasonBytes: reasonBytes
        });
        GlvWithdrawalUtils.cancelGlvWithdrawal(params);
    }

    function cancelGlvWithdrawal(bytes32 key) external globalNonReentrant onlyController {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        FeatureUtils.validateFeature(_dataStore, Keys.cancelGlvWithdrawalFeatureDisabledKey(address(this)));

        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawalStoreUtils.get(_dataStore, key);
        validateRequestCancellation(glvWithdrawal.updatedAtTime(), "GlvWithdrawal");

        GlvWithdrawalUtils.CancelGlvWithdrawalParams memory params = GlvWithdrawalUtils.CancelGlvWithdrawalParams({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            glvVault: glvVault,
            key: key,
            keeper: glvWithdrawal.account(),
            startingGas: startingGas,
            reason: Keys.USER_INITIATED_CANCEL,
            reasonBytes: ""
        });
        GlvWithdrawalUtils.cancelGlvWithdrawal(params);
    }

    function simulateExecuteGlvDeposit(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory params
    ) external onlyController withSimulatedOraclePrices(params) globalNonReentrant {
        GlvDeposit.Props memory glvDeposit = GlvDepositStoreUtils.get(dataStore, key);

        this._executeGlvDeposit(key, glvDeposit, msg.sender);
    }

    function simulateExecuteGlvWithdrawal(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory params
    ) external onlyController withSimulatedOraclePrices(params) globalNonReentrant {
        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawalStoreUtils.get(dataStore, key);

        this._executeGlvWithdrawal(key, glvWithdrawal, msg.sender);
    }

    function createGlvShift(
        GlvShiftUtils.CreateGlvShiftParams memory params
    ) external globalNonReentrant onlyOrderKeeper returns (bytes32) {
        FeatureUtils.validateFeature(dataStore, Keys.createGlvShiftFeatureDisabledKey(address(this)));

        return GlvShiftUtils.createGlvShift(dataStore, eventEmitter, params);
    }

    // @key glvDeposit key
    // @oracleParams prices for `fromMarket` and `toMarket` are required
    function executeGlvShift(
        bytes32 key,
        OracleUtils.SetPricesParams calldata oracleParams
    ) external globalNonReentrant onlyOrderKeeper withOraclePrices(oracleParams) {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;

        GlvShift.Props memory glvShift = GlvShiftStoreUtils.get(_dataStore, key);
        uint256 estimatedGasLimit = GasUtils.estimateExecuteGlvShiftGasLimit(_dataStore);
        GasUtils.validateExecutionGas(_dataStore, startingGas, estimatedGasLimit);

        uint256 executionGas = GasUtils.getExecutionGas(_dataStore, startingGas);

        try this._executeGlvShift{gas: executionGas}(key, glvShift, msg.sender) {} catch (bytes memory reasonBytes) {
            _handleGlvShiftError(key, reasonBytes);
        }
    }

    function _executeGlvShift(bytes32 key, GlvShift.Props memory glvShift, address keeper) external onlySelf {
        FeatureUtils.validateFeature(dataStore, Keys.executeGlvShiftFeatureDisabledKey(address(this)));

        GlvShiftUtils.ExecuteGlvShiftParams memory params = GlvShiftUtils.ExecuteGlvShiftParams({
            key: key,
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            shiftVault: shiftVault,
            glvVault: glvVault,
            oracle: oracle,
            keeper: keeper
        });

        GlvShiftUtils.executeGlvShift(params, glvShift);
    }

    function _handleGlvShiftError(bytes32 key, bytes memory reasonBytes) internal {
        GasUtils.validateExecutionErrorGas(dataStore, reasonBytes);

        bytes4 errorSelector = ErrorUtils.getErrorSelectorFromData(reasonBytes);

        validateNonKeeperError(errorSelector, reasonBytes);

        (string memory reason /* bool hasRevertMessage */, ) = ErrorUtils.getRevertMessage(reasonBytes);

        GlvShiftUtils.cancelGlvShift(
            dataStore,
            eventEmitter,
            key,
            reason,
            reasonBytes
        );
    }

    function addMarketToGlv(address glv, address market) external globalNonReentrant onlyConfigKeeper {
        GlvUtils.addMarketToGlv(dataStore, eventEmitter, glv, market);
    }

    function removeMarketFromGlv(address glv, address market) external globalNonReentrant onlyConfigKeeper {
        GlvUtils.removeMarketFromGlv(dataStore, eventEmitter, glv, market);
    }
}
