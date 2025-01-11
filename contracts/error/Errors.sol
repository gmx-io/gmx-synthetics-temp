// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

library Errors {
    // AdlHandler errors
    error AdlNotRequired(int256 pnlToPoolFactor, uint256 maxPnlFactorForAdl);
    error InvalidAdl(int256 nextPnlToPoolFactor, int256 pnlToPoolFactor);
    error PnlOvercorrected(int256 nextPnlToPoolFactor, uint256 minPnlFactorForAdl);

    // AdlUtils errors
    error InvalidSizeDeltaForAdl(uint256 sizeDeltaUsd, uint256 positionSizeInUsd);
    error AdlNotEnabled();

    // AutoCancelUtils errors
    error MaxAutoCancelOrdersExceeded(uint256 count, uint256 maxAutoCancelOrders);

    // Bank errors
    error SelfTransferNotSupported(address receiver);
    error InvalidNativeTokenSender(address msgSender);

    // BaseHandler errors
    error RequestNotYetCancellable(uint256 requestAge, uint256 requestExpirationAge, string requestType);

    // CallbackUtils errors
    error MaxCallbackGasLimitExceeded(uint256 callbackGasLimit, uint256 maxCallbackGasLimit);
    error InsufficientGasLeftForCallback(uint256 gasToBeForwarded, uint256 callbackGasLimit);

    // Config errors
    error InvalidBaseKey(bytes32 baseKey);
    error ConfigValueExceedsAllowedRange(bytes32 baseKey, uint256 value);
    error InvalidClaimableFactor(uint256 value);
    error OracleProviderAlreadyExistsForToken(address token);
    error PriceFeedAlreadyExistsForToken(address token);
    error DataStreamIdAlreadyExistsForToken(address token);
    error MaxFundingFactorPerSecondLimitExceeded(uint256 maxFundingFactorPerSecond, uint256 limit);

    // ContributorHandler errors
    error InvalidSetContributorPaymentInput(uint256 tokensLength, uint256 amountsLength);
    error InvalidContributorToken(address token);
    error MaxTotalContributorTokenAmountExceeded(address token, uint256 totalAmount, uint256 maxTotalAmount);
    error MinContributorPaymentIntervalNotYetPassed(uint256 minPaymentInterval);
    error MinContributorPaymentIntervalBelowAllowedRange(uint256 interval);
    error InvalidSetMaxTotalContributorTokenAmountInput(uint256 tokensLength, uint256 amountsLength);

    // Timelock errors
    error ActionAlreadySignalled();
    error ActionNotSignalled();
    error SignalTimeNotYetPassed(uint256 signalTime);
    error InvalidTimelockDelay(uint256 timelockDelay);
    error MaxTimelockDelayExceeded(uint256 timelockDelay);
    error InvalidFeeReceiver(address receiver);
    error InvalidOracleSigner(address receiver);

    // GlvDepositStoreUtils errors
    error GlvDepositNotFound(bytes32 key);
    // GlvShiftStoreUtils errors
    error GlvShiftNotFound(bytes32 key);
    // GlvWithdrawalStoreUtils errors
    error GlvWithdrawalNotFound(bytes32 key);
    // GlvDepositUtils errors
    error EmptyGlvDepositAmounts();
    error EmptyGlvMarketAmount();
    error EmptyGlvDeposit();
    error InvalidMinGlvTokensForFirstGlvDeposit(uint256 minGlvTokens, uint256 expectedMinGlvTokens);
    error InvalidReceiverForFirstGlvDeposit(address receiver, address expectedReceiver);
    // GlvWithdrawalUtils errors
    error EmptyGlvWithdrawal();
    error EmptyGlvWithdrawalAmount();
    // GlvUtils errors
    error EmptyGlv(address glv);
    error EmptyGlvTokenSupply();
    error GlvNegativeMarketPoolValue(address glv, address market);
    error GlvUnsupportedMarket(address glv, address market);
    error GlvDisabledMarket(address glv, address market);
    error GlvEnabledMarket(address glv, address market);
    error GlvNonZeroMarketBalance(address glv, address market);
    error GlvMaxMarketCountExceeded(address glv, uint256 glvMaxMarketCount);
    error GlvMaxMarketTokenBalanceUsdExceeded(address glv, address market, uint256 maxMarketTokenBalanceUsd, uint256 marketTokenBalanceUsd);
    error GlvMaxMarketTokenBalanceAmountExceeded(address glv, address market, uint256 maxMarketTokenBalanceAmount, uint256 marketTokenBalanceAmount);
    error GlvInsufficientMarketTokenBalance(address glv, address market, uint256 marketTokenBalance, uint256 marketTokenAmount);
    error GlvMarketAlreadyExists(address glv, address market);
    error GlvInvalidLongToken(address glv, address provided, address expected);
    error GlvInvalidShortToken(address glv, address provided, address expected);
    // GlvShiftUtils
    error GlvShiftMaxPriceImpactExceeded(uint256 effectivePriceImpactFactor, uint256 glvMaxShiftPriceImpactFactor);
    error GlvShiftIntervalNotYetPassed(uint256 currentTimestamp, uint256 lastGlvShiftExecutedAt, uint256 glvShiftMinInterval);
    // GlvFactory
    error GlvAlreadyExists(bytes32 salt, address glv);
    error GlvSymbolTooLong();
    error GlvNameTooLong();
    // GlvStoreUtils
    error GlvNotFound(address key);

    // DepositStoreUtils errors
    error DepositNotFound(bytes32 key);

    // DepositUtils errors
    error EmptyDeposit();
    error EmptyDepositAmounts();

    // ExecuteDepositUtils errors
    error MinMarketTokens(uint256 received, uint256 expected);
    error EmptyDepositAmountsAfterSwap();
    error InvalidPoolValueForDeposit(int256 poolValue);
    error InvalidSwapOutputToken(address outputToken, address expectedOutputToken);
    error InvalidReceiverForFirstDeposit(address receiver, address expectedReceiver);
    error InvalidMinMarketTokensForFirstDeposit(uint256 minMarketTokens, uint256 expectedMinMarketTokens);

    // ExternalHandler errors
    error ExternalCallFailed(bytes data);
    error InvalidExternalCallInput(uint256 targetsLength, uint256 dataListLength);
    error InvalidExternalReceiversInput(uint256 refundTokensLength, uint256 refundReceiversLength);
    error InvalidExternalCallTarget(address target);

    // FeeBatchStoreUtils errors
    error FeeBatchNotFound(bytes32 key);

    // FeeDistributor errors
    error InvalidFeeBatchTokenIndex(uint256 tokenIndex, uint256 feeBatchTokensLength);
    error InvalidAmountInForFeeBatch(uint256 amountIn, uint256 remainingAmount);
    error InvalidSwapPathForV1(address[] path, address bridgingToken);

    // GlpMigrator errors
    error InvalidGlpAmount(uint256 totalGlpAmountToRedeem, uint256 totalGlpAmount);
    error InvalidExecutionFeeForMigration(uint256 totalExecutionFee, uint256 msgValue);

    // GlvHandler errors
    error InvalidGlvDepositInitialLongToken(address initialLongToken);
    error InvalidGlvDepositInitialShortToken(address initialShortToken);
    error InvalidGlvDepositSwapPath(uint256 longTokenSwapPathLength, uint256 shortTokenSwapPathLength);
    error MinGlvTokens(uint256 received, uint256 expected);

    // OrderHandler errors
    error OrderNotUpdatable(uint256 orderType);
    error InvalidKeeperForFrozenOrder(address keeper);

    // FeatureUtils errors
    error DisabledFeature(bytes32 key);

    // FeeHandler errors
    error InvalidBuybackToken(address buybackToken);
    error InvalidVersion(uint256 version);
    error InsufficientBuybackOutputAmount(address feeToken, address buybackToken, uint256 outputAmount, uint256 minOutputAmount);
    error BuybackAndFeeTokenAreEqual(address feeToken, address buybackToken);
    error AvailableFeeAmountIsZero(address feeToken, address buybackToken, uint256 availableFeeAmount);
    error MaxBuybackPriceAgeExceeded(uint256 priceTimestamp, uint256 buybackMaxPriceAge, uint256 currentTimestamp);
    error EmptyClaimFeesMarket();

    // GasUtils errors
    error InsufficientExecutionFee(uint256 minExecutionFee, uint256 executionFee);
    error InsufficientWntAmountForExecutionFee(uint256 wntAmount, uint256 executionFee);
    error InsufficientExecutionGasForErrorHandling(uint256 startingGas, uint256 minHandleErrorGas);
    error InsufficientExecutionGas(uint256 startingGas, uint256 estimatedGasLimit, uint256 minAdditionalGasForExecution);
    error InsufficientHandleExecutionErrorGas(uint256 gas, uint256 minHandleExecutionErrorGas);
    error InsufficientGasForCancellation(uint256 gas, uint256 minHandleExecutionErrorGas);

    // MarketFactory errors
    error MarketAlreadyExists(bytes32 salt, address existingMarketAddress);

    // MarketStoreUtils errors
    error MarketNotFound(address key);

    // MarketUtils errors
    error EmptyMarket();
    error DisabledMarket(address market);
    error MaxSwapPathLengthExceeded(uint256 swapPathLengh, uint256 maxSwapPathLength);
    error InsufficientPoolAmount(uint256 poolAmount, uint256 amount);
    error InsufficientReserve(uint256 reservedUsd, uint256 maxReservedUsd);
    error InsufficientReserveForOpenInterest(uint256 reservedUsd, uint256 maxReservedUsd);
    error UnableToGetOppositeToken(address inputToken, address market);
    error UnexpectedTokenForVirtualInventory(address token, address market);
    error EmptyMarketTokenSupply();
    error InvalidSwapMarket(address market);
    error UnableToGetCachedTokenPrice(address token, address market);
    error CollateralAlreadyClaimed(uint256 adjustedClaimableAmount, uint256 claimedAmount);
    error OpenInterestCannotBeUpdatedForSwapOnlyMarket(address market);
    error MaxOpenInterestExceeded(uint256 openInterest, uint256 maxOpenInterest);
    error MaxPoolAmountExceeded(uint256 poolAmount, uint256 maxPoolAmount);
    error MaxPoolUsdForDepositExceeded(uint256 poolUsd, uint256 maxPoolUsdForDeposit);
    error UnexpectedBorrowingFactor(uint256 positionBorrowingFactor, uint256 cumulativeBorrowingFactor);
    error UnableToGetBorrowingFactorEmptyPoolUsd();
    error UnableToGetFundingFactorEmptyOpenInterest();
    error InvalidPositionMarket(address market);
    error InvalidCollateralTokenForMarket(address market, address token);
    error PnlFactorExceededForLongs(int256 pnlToPoolFactor, uint256 maxPnlFactor);
    error PnlFactorExceededForShorts(int256 pnlToPoolFactor, uint256 maxPnlFactor);
    error InvalidUiFeeFactor(uint256 uiFeeFactor, uint256 maxUiFeeFactor);
    error EmptyAddressInMarketTokenBalanceValidation(address market, address token);
    error InvalidMarketTokenBalance(address market, address token, uint256 balance, uint256 expectedMinBalance);
    error InvalidMarketTokenBalanceForCollateralAmount(address market, address token, uint256 balance, uint256 collateralAmount);
    error InvalidMarketTokenBalanceForClaimableFunding(address market, address token, uint256 balance, uint256 claimableFundingFeeAmount);
    error UnexpectedPoolValue(int256 poolValue);

    // Oracle errors
    error SequencerDown();
    error SequencerGraceDurationNotYetPassed(uint256 timeSinceUp, uint256 sequencerGraceDuration);
    error EmptyValidatedPrices();
    error InvalidOracleProvider(address provider);
    error InvalidOracleProviderForToken(address provider, address expectedProvider);
    error GmEmptySigner(uint256 signerIndex);
    error InvalidOracleSetPricesProvidersParam(uint256 tokensLength, uint256 providersLength);
    error InvalidOracleSetPricesDataParam(uint256 tokensLength, uint256 dataLength);
    error GmInvalidBlockNumber(uint256 minOracleBlockNumber, uint256 currentBlockNumber);
    error GmInvalidMinMaxBlockNumber(uint256 minOracleBlockNumber, uint256 maxOracleBlockNumber);
    error EmptyDataStreamFeedId(address token);
    error InvalidDataStreamFeedId(address token, bytes32 feedId, bytes32 expectedFeedId);
    error InvalidDataStreamBidAsk(address token, int192 bid, int192 ask);
    error InvalidDataStreamPrices(address token, int192 bid, int192 ask);
    error MaxPriceAgeExceeded(uint256 oracleTimestamp, uint256 currentTimestamp);
    error MaxOracleTimestampRangeExceeded(uint256 range, uint256 maxRange);
    error GmMinOracleSigners(uint256 oracleSigners, uint256 minOracleSigners);
    error GmMaxOracleSigners(uint256 oracleSigners, uint256 maxOracleSigners);
    error BlockNumbersNotSorted(uint256 minOracleBlockNumber, uint256 prevMinOracleBlockNumber);
    error GmMinPricesNotSorted(address token, uint256 price, uint256 prevPrice);
    error GmMaxPricesNotSorted(address token, uint256 price, uint256 prevPrice);
    error EmptyChainlinkPriceFeedMultiplier(address token);
    error EmptyDataStreamMultiplier(address token);
    error InvalidDataStreamSpreadReductionFactor(address token, uint256 spreadReductionFactor);
    error InvalidFeedPrice(address token, int256 price);
    error ChainlinkPriceFeedNotUpdated(address token, uint256 timestamp, uint256 heartbeatDuration);
    error GmMaxSignerIndex(uint256 signerIndex, uint256 maxSignerIndex);
    error InvalidGmOraclePrice(address token);
    error InvalidGmSignerMinMaxPrice(uint256 minPrice, uint256 maxPrice);
    error InvalidGmMedianMinMaxPrice(uint256 minPrice, uint256 maxPrice);
    error NonEmptyTokensWithPrices(uint256 tokensWithPricesLength);
    error InvalidMinMaxForPrice(address token, uint256 min, uint256 max);
    error EmptyChainlinkPriceFeed(address token);
    error PriceAlreadySet(address token, uint256 minPrice, uint256 maxPrice);
    error MaxRefPriceDeviationExceeded(
        address token,
        uint256 price,
        uint256 refPrice,
        uint256 maxRefPriceDeviationFactor
    );
    error InvalidBlockRangeSet(uint256 largestMinBlockNumber, uint256 smallestMaxBlockNumber);
    error EmptyChainlinkPaymentToken();
    error NonAtomicOracleProvider(address provider);

    // OracleModule errors
    error InvalidPrimaryPricesForSimulation(uint256 primaryTokensLength, uint256 primaryPricesLength);
    error EndOfOracleSimulation();

    // OracleUtils errors
    error InvalidGmSignature(address recoveredSigner, address expectedSigner);

    error EmptyPrimaryPrice(address token);

    error OracleTimestampsAreSmallerThanRequired(uint256 minOracleTimestamp, uint256 expectedTimestamp);
    error OracleTimestampsAreLargerThanRequestExpirationTime(uint256 maxOracleTimestamp, uint256 requestTimestamp, uint256 requestExpirationTime);

    // BaseOrderUtils errors
    error EmptyOrder();
    error UnsupportedOrderType(uint256 orderType);
    error InvalidOrderPrices(
        uint256 primaryPriceMin,
        uint256 primaryPriceMax,
        uint256 triggerPrice,
        uint256 orderType
    );
    error EmptySizeDeltaInTokens();
    error PriceImpactLargerThanOrderSize(int256 priceImpactUsd, uint256 sizeDeltaUsd);
    error NegativeExecutionPrice(int256 executionPrice, uint256 price, uint256 positionSizeInUsd, int256 priceImpactUsd, uint256 sizeDeltaUsd);
    error OrderNotFulfillableAtAcceptablePrice(uint256 price, uint256 acceptablePrice);
    error OrderValidFromTimeNotReached(uint256 validFromTime, uint256 currentTimestamp);

    // IncreaseOrderUtils errors
    error UnexpectedPositionState();

    // OrderUtils errors
    error OrderTypeCannotBeCreated(uint256 orderType);
    error OrderAlreadyFrozen();
    error MaxTotalCallbackGasLimitForAutoCancelOrdersExceeded(uint256 totalCallbackGasLimit, uint256 maxTotalCallbackGasLimit);
    error InvalidReceiver(address receiver);
    error UnexpectedValidFromTime(uint256 orderType);

    // OrderStoreUtils errors
    error OrderNotFound(bytes32 key);

    // SwapOrderUtils errors
    error UnexpectedMarket();

    // DecreasePositionCollateralUtils errors
    error InsufficientFundsToPayForCosts(uint256 remainingCostUsd, string step);
    error InvalidOutputToken(address tokenOut, address expectedTokenOut);

    // DecreasePositionUtils errors
    error InvalidDecreaseOrderSize(uint256 sizeDeltaUsd, uint256 positionSizeInUsd);
    error UnableToWithdrawCollateral(int256 estimatedRemainingCollateralUsd);
    error InvalidDecreasePositionSwapType(uint256 decreasePositionSwapType);
    error PositionShouldNotBeLiquidated(
        string reason,
        int256 remainingCollateralUsd,
        int256 minCollateralUsd,
        int256 minCollateralUsdForLeverage
    );

    // IncreasePositionUtils errors
    error InsufficientCollateralAmount(uint256 collateralAmount, int256 collateralDeltaAmount);
    error InsufficientCollateralUsd(int256 remainingCollateralUsd);

    // PositionStoreUtils errors
    error PositionNotFound(bytes32 key);

    // PositionUtils errors
    error LiquidatablePosition(
        string reason,
        int256 remainingCollateralUsd,
        int256 minCollateralUsd,
        int256 minCollateralUsdForLeverage
    );

    error EmptyPosition();
    error InvalidPositionSizeValues(uint256 sizeInUsd, uint256 sizeInTokens);
    error MinPositionSize(uint256 positionSizeInUsd, uint256 minPositionSizeUsd);

    // PositionPricingUtils errors
    error UsdDeltaExceedsLongOpenInterest(int256 usdDelta, uint256 longOpenInterest);
    error UsdDeltaExceedsShortOpenInterest(int256 usdDelta, uint256 shortOpenInterest);

    // ShiftStoreUtils errors
    error ShiftNotFound(bytes32 key);

    // ShiftUtils errors
    error EmptyShift();
    error EmptyShiftAmount();
    error ShiftFromAndToMarketAreEqual(address market);
    error LongTokensAreNotEqual(address fromMarketLongToken, address toMarketLongToken);
    error ShortTokensAreNotEqual(address fromMarketLongToken, address toMarketLongToken);

    // SwapPricingUtils errors
    error UsdDeltaExceedsPoolValue(int256 usdDelta, uint256 poolUsd);

    // RoleModule errors
    error Unauthorized(address msgSender, string role);

    // RoleStore errors
    error ThereMustBeAtLeastOneRoleAdmin();
    error ThereMustBeAtLeastOneTimelockMultiSig();

    // ExchangeRouter errors
    error InvalidClaimFundingFeesInput(uint256 marketsLength, uint256 tokensLength);
    error InvalidClaimCollateralInput(uint256 marketsLength, uint256 tokensLength, uint256 timeKeysLength);
    error InvalidClaimAffiliateRewardsInput(uint256 marketsLength, uint256 tokensLength);
    error InvalidClaimUiFeesInput(uint256 marketsLength, uint256 tokensLength);

    // SwapUtils errors
    error InvalidTokenIn(address tokenIn, address market);
    error InsufficientOutputAmount(uint256 outputAmount, uint256 minOutputAmount);
    error InsufficientSwapOutputAmount(uint256 outputAmount, uint256 minOutputAmount);
    error DuplicatedMarketInSwapPath(address market);
    error SwapPriceImpactExceedsAmountIn(uint256 amountAfterFees, int256 negativeImpactAmount);

    // SubaccountRouter errors
    error InvalidReceiverForSubaccountOrder(address receiver, address expectedReceiver);

    // SubaccountUtils errors
    error SubaccountNotAuthorized(address account, address subaccount);
    error MaxSubaccountActionCountExceeded(address account, address subaccount, uint256 count, uint256 maxCount);

    // TokenUtils errors
    error TokenTransferError(address token, address receiver, uint256 amount);
    error EmptyHoldingAddress();
    // Note that Transfer is misspelled as Tranfer in the EmptyTokenTranferGasLimit error
    // some contracts with this error cannot be re-deployed so it has been left as is
    error EmptyTokenTranferGasLimit(address token);

    // AccountUtils errors
    error EmptyAccount();
    error EmptyReceiver();

    // Array errors
    error CompactedArrayOutOfBounds(
        uint256[] compactedValues,
        uint256 index,
        uint256 slotIndex,
        string label
    );

    error ArrayOutOfBoundsUint256(
        uint256[] values,
        uint256 index,
        string label
    );

    error ArrayOutOfBoundsBytes(
        bytes[] values,
        uint256 index,
        string label
    );

    // WithdrawalHandler errors
    error SwapsNotAllowedForAtomicWithdrawal(uint256 longTokenSwapPathLength, uint256 shortTokenSwapPathLength);

    // WithdrawalStoreUtils errors
    error WithdrawalNotFound(bytes32 key);

    // WithdrawalUtils errors
    error EmptyWithdrawal();
    error EmptyWithdrawalAmount();
    error MinLongTokens(uint256 received, uint256 expected);
    error MinShortTokens(uint256 received, uint256 expected);
    error InsufficientMarketTokens(uint256 balance, uint256 expected);
    error InsufficientWntAmount(uint256 wntAmount, uint256 executionFee);
    error InvalidPoolValueForWithdrawal(int256 poolValue);

    // Uint256Mask errors
    error MaskIndexOutOfBounds(uint256 index, string label);
    error DuplicatedIndex(uint256 index, string label);

    // Cast errors
    error Uint256AsBytesLengthExceeds32Bytes(uint256 length);

    // ConfigSyncer errors
    error SyncConfigInvalidInputLengths(uint256 marketsLength, uint256 parametersLength);
    error SyncConfigUpdatesDisabledForMarket(address market);
    error SyncConfigUpdatesDisabledForParameter(string parameter);
    error SyncConfigUpdatesDisabledForMarketParameter(address market, string parameter);
    error SyncConfigInvalidMarketFromData(address market, address marketFromData);

    // Reader errors
    error EmptyMarketPrice(address market);

    // Gelato relay errors
    error InvalidFeeToken(address feeToken, address expectedFeeToken);
    error NotImplemented();
    error InvalidPermitSpender(address spender, address expectedSpender);
    error InvalidAccount(address recoveredSigner, address expectedSigner);
}
