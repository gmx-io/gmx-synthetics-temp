// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./BaseHandler.sol";
import "../shift/ShiftVault.sol";
import "../shift/Shift.sol";
import "../shift/ShiftUtils.sol";
import "./IShiftHandler.sol";

contract ShiftHandler is IShiftHandler, BaseHandler {
    using Shift for Shift.Props;

    ShiftVault public immutable shiftVault;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        ShiftVault _shiftVault
    ) BaseHandler(_roleStore, _dataStore, _eventEmitter, _oracle) {
        shiftVault = _shiftVault;
    }

    function createShift(
        address account,
        ShiftUtils.CreateShiftParams calldata params
    ) external override globalNonReentrant onlyController returns (bytes32) {
        FeatureUtils.validateFeature(dataStore, Keys.createShiftFeatureDisabledKey(address(this)));
        validateDataListLength(params.dataList.length);

        return ShiftUtils.createShift(
            dataStore,
            eventEmitter,
            shiftVault,
            account,
            params
        );
    }

    function cancelShift(bytes32 key) external override globalNonReentrant onlyController {
        uint256 startingGas = gasleft();

        DataStore _dataStore = dataStore;
        Shift.Props memory shift = ShiftStoreUtils.get(_dataStore, key);

        FeatureUtils.validateFeature(_dataStore, Keys.cancelShiftFeatureDisabledKey(address(this)));

        validateRequestCancellation(
            shift.updatedAtTime(),
            "Shift"
        );

        ShiftUtils.cancelShift(
            _dataStore,
            eventEmitter,
            shiftVault,
            key,
            shift.account(),
            startingGas,
            Keys.USER_INITIATED_CANCEL,
            ""
        );
    }

    function executeShift(
        bytes32 key,
        OracleUtils.SetPricesParams calldata oracleParams
    ) external
        globalNonReentrant
        onlyOrderKeeper
        withOraclePrices(oracleParams)
    {
        uint256 startingGas = gasleft();

        Shift.Props memory shift = ShiftStoreUtils.get(dataStore, key);
        uint256 estimatedGasLimit = GasUtils.estimateExecuteShiftGasLimit(dataStore, shift);
        GasUtils.validateExecutionGas(dataStore, startingGas, estimatedGasLimit);

        uint256 executionGas = GasUtils.getExecutionGas(dataStore, startingGas);

        try this._executeShift{ gas: executionGas }(
            key,
            shift,
            msg.sender
        ) {
        } catch (bytes memory reasonBytes) {
            _handleShiftError(
                key,
                startingGas,
                reasonBytes
            );
        }
    }

    function simulateExecuteShift(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory params
    ) external
        override
        onlyController
        withSimulatedOraclePrices(params)
        globalNonReentrant
    {
        Shift.Props memory shift = ShiftStoreUtils.get(dataStore, key);

        this._executeShift(
            key,
            shift,
            msg.sender
        );
    }

    function _executeShift(
        bytes32 key,
        Shift.Props memory shift,
        address keeper
    ) external onlySelf {
        uint256 startingGas = gasleft();

        FeatureUtils.validateFeature(dataStore, Keys.executeShiftFeatureDisabledKey(address(this)));

        ShiftUtils.ExecuteShiftParams memory params = ShiftUtils.ExecuteShiftParams(
            dataStore,
            eventEmitter,
            shiftVault,
            oracle,
            key,
            keeper,
            startingGas
        );

        ShiftUtils.executeShift(params, shift);
    }

    function _handleShiftError(
        bytes32 key,
        uint256 startingGas,
        bytes memory reasonBytes
    ) internal {
        GasUtils.validateExecutionErrorGas(dataStore, reasonBytes);

        bytes4 errorSelector = ErrorUtils.getErrorSelectorFromData(reasonBytes);

        validateNonKeeperError(errorSelector, reasonBytes);

        (string memory reason, /* bool hasRevertMessage */) = ErrorUtils.getRevertMessage(reasonBytes);

        ShiftUtils.cancelShift(
            dataStore,
            eventEmitter,
            shiftVault,
            key,
            msg.sender,
            startingGas,
            reason,
            reasonBytes
        );
    }
}
