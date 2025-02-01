// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../data/Keys.sol";

import "../event/EventEmitter.sol";
import "../market/MarketToken.sol";
import "../market/MarketUtils.sol";

import "./IReferralStorage.sol";
import "./ReferralEventUtils.sol";

import "../utils/Precision.sol";

import "../feature/FeatureUtils.sol";

// @title ReferralUtils
// @dev Library for referral functions
library ReferralUtils {
    // @dev set the referral code for a trader
    // @param referralStorage The referral storage instance to use.
    // @param account The account of the trader.
    // @param referralCode The referral code.
    function setTraderReferralCode(
        IReferralStorage referralStorage,
        address account,
        bytes32 referralCode
    ) internal {
        if (referralCode == bytes32(0)) { return; }

        // skip setting of the referral code if the user already has a referral code
        if (referralStorage.traderReferralCodes(account) != bytes32(0)) { return; }

        referralStorage.setTraderReferralCode(account, referralCode);
    }

    // @dev Increments the affiliate's reward balance by the specified delta.
    // @param dataStore The data store instance to use.
    // @param eventEmitter The event emitter instance to use.
    // @param market The market address.
    // @param token The token address.
    // @param affiliate The affiliate's address.
    // @param trader The trader's address.
    // @param delta The amount to increment the reward balance by.
    function incrementAffiliateReward(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        address affiliate,
        uint256 delta
    ) internal {
        if (delta == 0) { return; }

        uint256 nextValue = dataStore.incrementUint(Keys.affiliateRewardKey(market, token, affiliate), delta);
        uint256 nextPoolValue = dataStore.incrementUint(Keys.affiliateRewardKey(market, token), delta);

        ReferralEventUtils.emitAffiliateRewardUpdated(
            eventEmitter,
            market,
            token,
            affiliate,
            delta,
            nextValue,
            nextPoolValue
        );
    }

    // @dev Gets the referral information for the specified trader.
    // @param referralStorage The referral storage instance to use.
    // @param trader The trader's address.
    // @return The affiliate's address, the total rebate, and the discount share.
    function getReferralInfo(
        DataStore dataStore,
        IReferralStorage referralStorage,
        address trader
    ) internal view returns (bytes32, address, uint256, uint256, uint256) {
        bytes32 code = referralStorage.traderReferralCodes(trader);
        address affiliate;
        uint256 totalRebate;
        uint256 discountShare;
        uint256 minAffiliateRewardFactor;

        if (code != bytes32(0)) {
            affiliate = referralStorage.codeOwners(code);
            uint256 referralTierLevel = referralStorage.referrerTiers(affiliate);
            (totalRebate, discountShare) = referralStorage.tiers(referralTierLevel);
            minAffiliateRewardFactor = dataStore.getUint(Keys.minAffiliateRewardFactorKey(referralTierLevel));

            uint256 customDiscountShare = referralStorage.referrerDiscountShares(affiliate);
            if (customDiscountShare != 0) {
                discountShare = customDiscountShare;
            }
        }

        uint256 traderDiscountFactor = Precision.basisPointsToFloat(totalRebate * discountShare / Precision.BASIS_POINTS_DIVISOR);
        uint256 totalRebateFactor = Precision.basisPointsToFloat(totalRebate);
        uint256 affiliateRewardFactor = totalRebateFactor - traderDiscountFactor;

        return (
            code,
            affiliate,
            affiliateRewardFactor,
            traderDiscountFactor,
            minAffiliateRewardFactor
        );
    }

    // @dev Claims affiliate rewards for the given markets and tokens and sends the rewards to the specified receiver.
    // @param dataStore The data store instance to use.
    // @param eventEmitter The event emitter instance to use.
    // @param markets An array of market addresses
    // @param tokens An array of token addresses, corresponding to the given markets
    // @param receiver The address to which the claimed rewards should be sent
    // @param account The affiliate's address.
    function batchClaimAffiliateRewards(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address[] memory markets,
        address[] memory tokens,
        address receiver,
        address account
    ) external returns (uint256[] memory) {
        if (markets.length != tokens.length) {
            revert Errors.InvalidClaimAffiliateRewardsInput(markets.length, tokens.length);
        }

        FeatureUtils.validateFeature(dataStore, Keys.claimAffiliateRewardsFeatureDisabledKey(address(this)));

        uint256[] memory claimedAmounts = new uint256[](markets.length);

        for (uint256 i; i < markets.length; i++) {
            claimedAmounts[i] = claimAffiliateReward(
                dataStore,
                eventEmitter,
                markets[i],
                tokens[i],
                account,
                receiver
            );
        }

        return claimedAmounts;
    }

    // @dev Claims the affiliate's reward balance and transfers it to the specified receiver.
    // @param dataStore The data store instance to use.
    // @param eventEmitter The event emitter instance to use.
    // @param market The market address.
    // @param token The token address.
    // @param account The affiliate's address.
    // @param receiver The address to receive the reward.
    function claimAffiliateReward(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        address account,
        address receiver
    ) internal returns (uint256) {
        bytes32 key = Keys.affiliateRewardKey(market, token, account);

        uint256 rewardAmount = dataStore.getUint(key);
        dataStore.setUint(key, 0);

        uint256 nextPoolValue = dataStore.decrementUint(Keys.affiliateRewardKey(market, token), rewardAmount);

        MarketToken(payable(market)).transferOut(
            token,
            receiver,
            rewardAmount
        );

        MarketUtils.validateMarketTokenBalance(dataStore, market);

        ReferralEventUtils.emitAffiliateRewardClaimed(
            eventEmitter,
            market,
            token,
            account,
            receiver,
            rewardAmount,
            nextPoolValue
        );

        return rewardAmount;
    }
}
