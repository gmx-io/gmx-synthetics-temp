// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {MultichainReaderUtils} from "../external/MultichainReaderUtils.sol";

import "../v1/IVaultV1.sol";
import "../v1/IRouterV1.sol";

import "../data/DataStore.sol";
import "../role/RoleModule.sol";
import "../event/EventEmitter.sol";
import "../external/MultichainReader.sol";
import "../router/IExchangeRouter.sol";

contract FeeDistributor is ReentrancyGuard, RoleModule {
    using EventUtils for EventUtils.BoolItems;

    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;
    MultichainReader public immutable multichainReader;

    IVaultV1 public immutable vaultV1;
    IRouterV1 public immutable routerV1;

    address public immutable routerV2;
    IExchangeRouter public immutable exchangeRouterV2;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        MultichainReader _multichainReader,
        IVaultV1 _vaultV1,
        IRouterV1 _routerV1,
        address _routerV2,
        IExchangeRouter _exchangeRouterV2
    ) RoleModule(_roleStore) {
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
        multichainReader = _multichainReader;

        vaultV1 = _vaultV1;
        routerV1 = _routerV1;

        routerV2 = _routerV2;
        exchangeRouterV2 = _exchangeRouterV2;
    }

    function initiateDistribute() external nonReentrant onlyFeeDistributionKeeper {
        _validateDistributionNotCompleted();
        uint256 chains = dataStore.getUint(Keys.FEE_DISTRIBUTOR_NUMBER_OF_CHAINS);
        MultichainReaderUtils.ReadRequestInputs[]
            memory readRequestsInputs = new MultichainReaderUtils.ReadRequestInputs[]((chains - 1) * 3);
        bool skippedCurrentChain;
        for (uint256 i; i < chains; i++) {
            uint256 chainId = dataStore.getUint(Keys.feeDistributorChainIdKey(i + 1));
            address gmx = dataStore.getAddress(
                Keys.feeDistributorStoredAddressesKey(chainId, keccak256(abi.encode("GMX")))
            );
            address feeKeeper = dataStore.getAddress(
                Keys.feeDistributorStoredAddressesKey(chainId, keccak256(abi.encode("FEE_KEEPER")))
            );
            address feeGmxTracker = dataStore.getAddress(
                Keys.feeDistributorStoredAddressesKey(chainId, keccak256(abi.encode("FEE_GMX_TRACKER")))
            );
            if (chainId == block.chainid) {
                uint256 feeAmount = dataStore.getUint(Keys.withdrawableBuybackTokenAmountKey(gmx)) +
                    IERC20(gmx).balanceOf(feeKeeper);
                uint256 stakedGmx = IERC20(feeGmxTracker).totalSupply();
                dataStore.setUint(Keys.feeDistributorFeeAmountKey(chainId), feeAmount);
                dataStore.setUint(Keys.feeDistributorStakedGmxKey(chainId), stakedGmx);
                skippedCurrentChain = true;
                continue;
            }

            uint32 layerZeroChainId = uint32(dataStore.getUint(Keys.feeDistributorLayerZeroChainIdKey(chainId)));
            uint256 readRequest = skippedCurrentChain ? (i - 1) * 3 : i * 3;
            readRequestsInputs[readRequest].chainId = layerZeroChainId;
            readRequestsInputs[readRequest].target = dataStore.getAddress(
                Keys.feeDistributorStoredAddressesKey(chainId, keccak256(abi.encode("DATASTORE")))
            );
            readRequestsInputs[readRequest].callData = abi.encodeWithSelector(
                DataStore.getUint.selector,
                Keys.withdrawableBuybackTokenAmountKey(gmx)
            );
            readRequest++;

            readRequestsInputs[readRequest].chainId = layerZeroChainId;
            readRequestsInputs[readRequest].target = gmx;
            readRequestsInputs[readRequest].callData = abi.encodeWithSelector(IERC20.balanceOf.selector, feeKeeper);
            readRequest++;

            readRequestsInputs[readRequest].chainId = layerZeroChainId;
            readRequestsInputs[readRequest].target = feeGmxTracker;
            readRequestsInputs[readRequest].callData = abi.encodeWithSelector(IERC20.totalSupply.selector);
        }

        MultichainReaderUtils.ExtraOptionsInputs memory extraOptionsInputs;
        extraOptionsInputs.gasLimit = uint128(dataStore.getUint(Keys.FEE_DISTRIBUTOR_GAS_LIMIT));
        extraOptionsInputs.returnDataSize = ((uint32(chains) - 1) * 96) + 8;

        MessagingFee memory messagingFee = multichainReader.quoteReadFee(readRequestsInputs, extraOptionsInputs);
        multichainReader.sendReadRequests{value: messagingFee.nativeFee}(readRequestsInputs, extraOptionsInputs);

        dataStore.setBool(Keys.FEE_DISTRIBUTOR_DISTRIBUTION_INITIATED, true);
    }

    function processLzReceive(
        bytes32 /*guid*/,
        MultichainReaderUtils.ReceivedData calldata receivedDataInput
    ) external {
        _validateReadResponseTimestamp(receivedDataInput.timestamp);
        dataStore.setUint(Keys.FEE_DISTRIBUTOR_READ_RESPONSE_TIMESTAMP, receivedDataInput.timestamp);

        uint256 chains = dataStore.getUint(Keys.FEE_DISTRIBUTOR_NUMBER_OF_CHAINS);
        for (uint256 i; i < chains; i++) {
            uint256 chainId = dataStore.getUint(Keys.feeDistributorChainIdKey(i + 1));
            bool skippedCurrentChain;
            if (chainId == block.chainid) {
                skippedCurrentChain = true;
                continue;
            }

            uint256 offset = skippedCurrentChain ? (i - 1) * 96 : i * 96;
            (uint256 feeAmount1, uint256 feeAmount2, uint256 stakedGmx) = abi.decode(
                receivedDataInput.readData[offset:offset + 96],
                (uint256, uint256, uint256)
            );
            dataStore.setUint(Keys.feeDistributorFeeAmountKey(chainId), feeAmount1 + feeAmount2);
            dataStore.setUint(Keys.feeDistributorStakedGmxKey(chainId), stakedGmx);
        }

        EventUtils.EventLogData memory eventData;
        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "distributeReferralRewards", false);

        eventEmitter.emitEventLog("TriggerReferralKeeper", eventData);
    }

    function distribute() external nonReentrant onlyFeeDistributionKeeper {
        if (!dataStore.getBool(Keys.FEE_DISTRIBUTOR_DISTRIBUTION_INITIATED)) {
            revert Errors.DistributionNotInitiated();
        }
        _validateReadResponseTimestamp(dataStore.getUint(Keys.FEE_DISTRIBUTOR_READ_RESPONSE_TIMESTAMP));
        _validateDistributionNotCompleted();

        uint256 chains = dataStore.getUint(Keys.FEE_DISTRIBUTOR_NUMBER_OF_CHAINS);
        uint256[] memory feeAmount = new uint256[](chains);
        uint256 totalFeeAmount;
        uint256[] memory stakedGmx = new uint256[](chains);
        uint256 totalStakedGmx;
        uint256 currentChain;
        for (uint256 i; i < chains; i++) {
            uint256 chainId = dataStore.getUint(Keys.feeDistributorChainIdKey(i + 1));
            if (chainId == block.chainid) {
                currentChain = i;
            }
            feeAmount[i] = dataStore.getUint(Keys.feeDistributorFeeAmountKey(chainId));
            totalFeeAmount = totalFeeAmount + feeAmount[i];
            stakedGmx[i] = dataStore.getUint(Keys.feeDistributorStakedGmxKey(chainId));
            totalStakedGmx = totalStakedGmx + stakedGmx[i];
        }

        // Need to add potential require checks on bridging calculation math
        // Need to account for rounding errors and the cost of the bridging as the numbers won't be exact
        uint256 requiredFeeAmount = (totalFeeAmount * stakedGmx[currentChain]) / totalStakedGmx;
        if (requiredFeeAmount > feeAmount[currentChain]) {
            dataStore.setBool(Keys.FEE_DISTRIBUTOR_FEE_DEFICIT, true);
            return;
        }
        if (!dataStore.getBool(Keys.FEE_DISTRIBUTOR_FEE_DEFICIT)) {
            uint256[] memory target = new uint256[](chains);
            for (uint256 i; i < chains; i++) {
                if (totalStakedGmx == 0) {
                    target[i] = 0;
                } else {
                    target[i] = (totalFeeAmount * stakedGmx[i]) / totalStakedGmx;
                }
            }

            int256[] memory difference = new int256[](chains);
            for (uint256 i; i < chains; i++) {
                difference[i] = int256(feeAmount[i]) - int256(target[i]);
            }

            uint256[][] memory bridging = new uint256[][](chains);
            for (uint256 i; i < chains; i++) {
                bridging[i] = new uint256[](chains);
            }

            uint256 deficit;
            for (uint256 surplus; surplus < chains; surplus++) {
                if (difference[surplus] <= 0) continue;

                while (deficit < chains && difference[deficit] >= 0) {
                    deficit++;
                }
                if (deficit == chains) break;

                while (difference[surplus] > 0 && deficit < chains) {
                    int256 needed = -difference[deficit];
                    if (needed > difference[surplus]) {
                        bridging[surplus][deficit] += uint256(difference[surplus]);
                        difference[deficit] += difference[surplus];
                        difference[surplus] = 0;
                    } else {
                        bridging[surplus][deficit] += uint256(needed);
                        difference[surplus] -= needed;
                        difference[deficit] = 0;
                        deficit++;
                        while (deficit < chains && difference[deficit] >= 0) {
                            deficit++;
                        }
                    }
                }
            }

            uint256 amountToBridgeOut;
            for (uint256 i; i < chains; i++) {
                uint256 sendAmount = bridging[currentChain][i];
                if (sendAmount > 0) {
                    // bridging transaction to be added
                }
                amountToBridgeOut += sendAmount;
            }
        }

        // after distribution completed
        if (dataStore.getBool(Keys.FEE_DISTRIBUTOR_FEE_DEFICIT)) {
            dataStore.setBool(Keys.FEE_DISTRIBUTOR_FEE_DEFICIT, false);
        }
        dataStore.setUint(Keys.FEE_DISTRIBUTOR_DISTRIBUTION_TIMESTAMP, block.timestamp);
        dataStore.setBool(Keys.FEE_DISTRIBUTOR_DISTRIBUTION_INITIATED, false);
    }

    function _validateDistributionNotCompleted() internal view {
        uint256 dayOfWeek = ((block.timestamp / 86400) + 4) % 7;
        uint256 daysSinceStartOfWeek = (dayOfWeek + 7 - dataStore.getUint(Keys.FEE_DISTRIBUTOR_DISTRIBUTION_DAY)) % 7;
        uint256 midnightToday = (block.timestamp - (block.timestamp % 86400));
        uint256 startOfWeek = midnightToday - (daysSinceStartOfWeek * 86400);
        uint256 lastDistributionTime = dataStore.getUint(Keys.FEE_DISTRIBUTOR_DISTRIBUTION_TIMESTAMP);
        if (lastDistributionTime > startOfWeek) {
            revert Errors.DistributionThisWeekAlreadyCompleted(lastDistributionTime, startOfWeek);
        }
    }

    function _validateReadResponseTimestamp(uint256 readResponseTimestamp) internal view {
        if (block.timestamp - readResponseTimestamp > dataStore.getUint(Keys.FEE_DISTRIBUTOR_MAX_READ_RESPONSE_DELAY)) {
            revert Errors.OutdatedReadResponse(readResponseTimestamp);
        }
    }
}
