// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../data/Keys.sol";
import "./IOracleProvider.sol";
import "./IChainlinkDataStreamVerifier.sol";
import "../utils/Precision.sol";
import "../chain/Chain.sol";

contract ChainlinkDataStreamProvider is IOracleProvider {

    DataStore public immutable dataStore;
    address public immutable oracle;
    IChainlinkDataStreamVerifier public immutable verifier;

    // bid: min price, highest buy price
    // ask: max price, lowest sell price
    struct Report {
        bytes32 feedId; // The feed ID the report has data for
        uint32 validFromTimestamp; // Earliest timestamp for which price is applicable
        uint32 observationsTimestamp; // Latest timestamp for which price is applicable
        uint192 nativeFee; // Base cost to validate a transaction using the report, denominated in the chain’s native token (WETH/ETH)
        uint192 linkFee; // Base cost to validate a transaction using the report, denominated in LINK
        uint32 expiresAt; // Latest timestamp where the report can be verified onchain
        int192 price; // DON consensus median price, carried to 8 decimal places
        int192 bid; // Simulated price impact of a buy order up to the X% depth of liquidity utilisation
        int192 ask; // Simulated price impact of a sell order up to the X% depth of liquidity utilisation
    }

    modifier onlyOracle() {
        if (msg.sender != oracle) {
            revert Errors.Unauthorized(msg.sender, "Oracle");
        }
        _;
    }

    constructor(
        DataStore _dataStore,
        address _oracle,
        IChainlinkDataStreamVerifier _verifier
    ) {
        dataStore = _dataStore;
        oracle = _oracle;
        verifier = _verifier;
    }

    function getOraclePrice(
        address token,
        bytes memory data
    ) external onlyOracle returns (OracleUtils.ValidatedPrice memory) {

        bytes32 feedId = dataStore.getBytes32(Keys.dataStreamIdKey(token));
        if (feedId == bytes32(0)) {
            revert Errors.EmptyDataStreamFeedId(token);
        }

        bytes memory payloadParameter = _getPayloadParameter();
        bytes memory verifierResponse = verifier.verify(data, payloadParameter);

        Report memory report = abi.decode(verifierResponse, (Report));

        if (feedId != report.feedId) {
            revert Errors.InvalidDataStreamFeedId(token, report.feedId, feedId);
        }

        if (report.bid <= 0 || report.ask <= 0) {
            revert Errors.InvalidDataStreamPrices(token, report.bid, report.ask);
        }

        if (report.bid > report.ask) {
            revert Errors.InvalidDataStreamBidAsk(token, report.bid, report.ask);
        }

        uint256 precision = _getDataStreamMultiplier(token);
        uint256 adjustedBidPrice = Precision.mulDiv(uint256(uint192(report.bid)), precision, Precision.FLOAT_PRECISION);
        uint256 adjustedAskPrice = Precision.mulDiv(uint256(uint192(report.ask)), precision, Precision.FLOAT_PRECISION);

        uint256 spreadReductionFactor = _getDataStreamSpreadReductionFactor(token);
        if (spreadReductionFactor != 0) {
            // small optimization for full reduction
            if (spreadReductionFactor == Precision.FLOAT_PRECISION) {
                adjustedBidPrice = (adjustedAskPrice + adjustedBidPrice) / 2;
                adjustedAskPrice = adjustedBidPrice;
            } else {
                uint256 halfSpread = (adjustedAskPrice - adjustedBidPrice) / 2;
                adjustedBidPrice = adjustedBidPrice + Precision.applyFactor(halfSpread, spreadReductionFactor);
                adjustedAskPrice = adjustedAskPrice - Precision.applyFactor(halfSpread, spreadReductionFactor);
            }
        }

        return OracleUtils.ValidatedPrice({
            token: token,
            min: adjustedBidPrice,
            max: adjustedAskPrice,
            timestamp: report.observationsTimestamp,
            provider: address(this)
        });
    }

    function _getDataStreamSpreadReductionFactor(address token) internal view returns (uint256) {
        uint256 spreadReductionFactor = dataStore.getUint(Keys.dataStreamSpreadReductionFactorKey(token));
        if (spreadReductionFactor > Precision.FLOAT_PRECISION) {
            revert Errors.InvalidDataStreamSpreadReductionFactor(token, spreadReductionFactor);
        }

        return spreadReductionFactor;
    }

    function _getDataStreamMultiplier(address token) internal view returns (uint256) {
        uint256 multiplier = dataStore.getUint(Keys.dataStreamMultiplierKey(token));

        if (multiplier == 0) {
            revert Errors.EmptyDataStreamMultiplier(token);
        }

        return multiplier;
    }

    function _getPayloadParameter() internal view returns (bytes memory) {
        // LINK token address
        address feeToken = dataStore.getAddress(Keys.CHAINLINK_PAYMENT_TOKEN);

        if (feeToken == address(0)) {
            revert Errors.EmptyChainlinkPaymentToken();
        }

        return abi.encode(feeToken);
    }
}
