# GMX Synthetics

Contracts for GMX Synthetics.

# General Overview

This section provides a general overview of how the system works.

For a Technical Overview, please see the section further below.

## Markets

Markets support both spot and perp trading, they are created by specifying a long collateral token, short collateral token and index token.

Examples:

- ETH/USD market with long collateral as ETH, short collateral as a stablecoin, index token as ETH
- BTC/USD market with long collateral as WBTC, short collateral as a stablecoin, index token as BTC
- SOL/USD market with long collateral as ETH, short collateral as a stablecoin, index token as SOL

Liquidity providers can deposit either the long or short collateral token or both to mint liquidity tokens.

The long collateral token is used to back long positions, while the short collateral token is used to back short positions.

Liquidity providers take on the profits and losses of traders for the market that they provide liquidity for.

Having separate markets allows for risk isolation, liquidity providers are only exposed to the markets that they deposit into, this potentially allow for permissionless listings.

Traders can use either the long or short token as collateral for the market.

## Features

The contracts support the following main features:

- Deposit and withdrawal of liquidity
- Spot Trading (Swaps)
- Leverage Trading (Perps, Long / Short)
- Market orders, limit orders, stop-loss, take-profit orders

## Oracle System

To avoid front-running issues, most actions require two steps to execute:

- User sends transaction with request details, e.g. deposit / withdraw liquidity, swap, increase / decrease position
- Keepers listen for the transactions, include the prices for the request then send a transaction to execute the request

Prices are provided by an off-chain oracle system, which continually signs prices based on the time the prices were queried.

Both a minimum price and a maximum price is signed, this allows information about bid-ask spreads to be included.

Prices stored within the Oracle contract represent the price of one unit of the token using a value with 30 decimals of precision.

Representing the prices in this way allows for conversions between token amounts and fiat values to be simplified, e.g. to calculate the fiat value of a given number of tokens the calculation would just be: token amount \* oracle price, to calculate the token amount for a fiat value it would be: fiat value / oracle price.

## Fees and Pricing

Funding fees and price impact keep longs / shorts balanced while reducing the risk of price manipulation.

- Funding fees: if there is an imbalance of longs / shorts, the larger side pays a funding fee to the smaller side
- Borrowing fees: to avoid a user opening equal longs / shorts and unnecessarily taking up capacity
- Price impact: this allows the contracts to simulate a price impact similar to if the trader were trading using an aggregator for the reference exchanges, there is a negative price impact if an action reduces balance, and a positive price impact if an action improves balance

## Keepers

There are a few keepers and nodes in the system:

- Oracle keepers: pull prices from reference exchanges, sign the information and publish it to Archive nodes
- Archive nodes: receives oracle keeper signatures and allows querying of this information
- Order keepers: checks for deposit / withdraw liquidity requests, order requests, bundles the signed oracle prices with the requests and executes them

## Structure

There are a few main types of contracts:

- Bank contracts which hold funds
- Data storage which stores data
- \*storeUtils utils to serialize, store and retrieve data for structs
- Logic contracts which do not hold funds and do not have internal state
- \*eventUtils utils to emit events

The contracts are separated into these types to allow for gradual upgradeability.

Majority of data is stored using the DataStore contract.

\*storeUtils contracts store struct data using the DataStore, this allows new keys to be added to structs.

EnumberableSets are used to allow order lists and position lists to be easily queried by interfaces or keepers, this is used over indexers as there may be a lag for indexers to sync the latest block. Having the lists stored directly in the contract also helps to ensure that accurate data can be retrieved and verified when needed.

\*eventUtils contracts emit events using the event emitter, the events are generalized to allow new key-values to be added to events without requiring an update of ABIs.

## GLV

Short for GMX Liquidity Vault: a wrapper of multiple markets with the same long and short tokens. Liquidity is automatically rebalanced between underlying markets based on markets utilisation.

# Technical Overview

This section provides a technical description of the contracts.

## Exchange Contracts

- Router: approve token spending using this contract
- ExchangeRouter: create requests for deposits, withdrawals, orders, tokens are transferred using the Router
- /exchange contracts: execute user requests

## Markets

Markets are created using `MarketFactory.createMarket`, this creates a MarketToken and stores a Market.Props struct in the MarketStore.

The MarketToken is used to keep track of liquidity providers share of the market pool and to store the tokens for each market.

At any point in time, the price of a MarketToken is `(worth of market pool) / MarketToken.totalSupply()`, the function `MarketUtils.getMarketTokenPrice` can be used to retrieve this value.

The worth of the market pool is the sum of

- worth of all tokens deposited into the pool
- total pending PnL of all open positions
- total pending borrow fees of all open positions

## Deposits

Deposits add long / short tokens to the market's pool and mints MarketTokens to the depositor.

Requests for deposits are created by calling ExchangeRouter.createDeposit, specifying:

- the market to deposit into
- amount of long tokens to deposit
- amount of short tokens to deposit

Deposit requests are executed using DepositHandler.executeDeposit, if the deposit was created at timestamp `n`, it should be executed with the oracle prices after timestamp `n`.

The amount of MarketTokens to be minted, before fees and price impact, is calculated as `(worth of tokens deposited) / (worth of market pool) * MarketToken.totalSupply()`.

## Withdrawals

Withdrawals burn MarketTokens in exchange for the long / short tokens of a market's pool.

Requests for withdrawals are created by calling ExchangeRouter.createWithdrawal, specifying:

- the market to withdraw from
- the number of market tokens to burn for long tokens
- the number of market tokens to burn for short tokens

Withdrawal requests are executed using WithdrawalHandler.executeWithdrawal, if the withdrawal was created at timestamp `n`, it should be executed with the oracle prices after timestamp `n`.

The amount of long or short tokens to be redeemed, before fees and price impact, is calculated as `(worth of market tokens) / (long / short token price)`.

## Market Swaps

Long and short tokens of a market can be swapped for each other.

For example, if the ETH / USD market has WETH as the long token and USDC as the short token, WETH can be sent to the market to be swapped for USDC and USDC can be sent to the market to be swapped for WETH.

Swap order requests are created by calling ExchangeRouter.createOrder, specifying:

- the initial collateral token
- the array of markets to swap through
- the minimum expected output amount

The swap output amount, before fees and price impact, `(amount of tokens in) * (token in price) / (token out price)`.

Market swap order requests are executed using OrderHandler.executeOrder, if the order was created at timestamp `n`, it should be executed with the oracle prices after timestamp `n`.

## Limit Swaps

Passive swap orders that should be executed when the output amount matches the minimum output amount specified by the user.

Limit swap order requests are executed using OrderHandler.executeOrder, if the order was created at timestamp `n`, it should be executed with oracle prices after timestamp `n`.

## Market Increase

Open or increase a long / short perp position.

Market increase order requests are created by calling ExchangeRouter.createOrder, specifying:

- the initial collateral token
- the array of markets to swap through to get the actual collateral token
- the amount to increase the position by
- whether it is a long or short position

Market increase order requests are executed using OrderHandler.executeOrder, if the order was created at timestamp `n`, it should be executed with the oracle prices after timestamp `n`.

## Limit Increase

Passive increase position orders that should be executed when the index token price matches the acceptable price specified by the user.

Long position example: if the current index token price is $5000, a limit increase order can be created with acceptable price as $4990, the order can be executed when the index token price is <= $4990.

Short position example: if the current index token price is $5000, a limit increase order can be created with acceptable price as $5010, the order can be executed when the index token price is >= $5010.

Limit increase order requests are executed using OrderHandler.executeOrder, if the order was created at timestamp `n`, it should be executed with the oracle prices after timestamp `n`.

## Market Decrease

Close or decrease a long / short perp position.

Market decrease order requests are created by calling ExchangeRouter.createOrder, specifying:

- the initial collateral token
- the array of markets to swap through for the actual output token
- the amount to decrease the position by

Market decrease order requests are executed using OrderHandler.executeOrder, if the order was created at timestamp `n`, it should be executed with the oracle prices after timestamp `n`.

## Limit Decrease

Passive decrease position orders that should be executed when the index token price matches the acceptable price specified by the user.

Long position example: if the current index token price is $5000, a limit decrease order can be created with acceptable price as $5010, the order can be executed when the index token price is >= $5010.

Short position example: if the current index token price is $5000, a limit decrease order can be created with acceptable price as $4990, the order can be executed when the index token price is <= $4990.

Limit decrease order requests are executed using OrderHandler.executeOrder, if the order was created at timestamp `n`, it should be executed with the oracle prices after timestamp `n`.

## Stop-Loss Decrease

Passive decrease position orders that should be executed when the index token price crosses the acceptable price specified by the user.

Long position example: if the current index token price is $5000, a stop-loss decrease order can be created with acceptable price as $4990, the order can be executed when the index token price is <= $4990.

Short position example: if the current index token price is $5000, a stop-loss decrease order can be created with acceptable price as $5010, the order can be executed when the index token price is >= $5010.

Stop-loss decrease order requests are executed using OrderHandler.executeOrder, if the order was created at timestamp `n`, it should be executed with the oracle prices after timestamp `n`.

## Example 1

The price of ETH is 5000, and ETH has 18 decimals.

The price of one unit of ETH is `5000 / (10 ^ 18), 5 * (10 ^ -15)`.

To handle the decimals, multiply the value by `(10 ^ 30)`.

Price would be stored as `5000 / (10 ^ 18) * (10 ^ 30) => 5000 * (10 ^ 12)`.

For gas optimization, these prices are sent to the oracle in the form of a uint8 decimal multiplier value and uint32 price value.

If the decimal multiplier value is set to 8, the uint32 value would be `5000 * (10 ^ 12) / (10 ^ 8) => 5000 * (10 ^ 4)`.

With this config, ETH prices can have a maximum value of `(2 ^ 32) / (10 ^ 4) => 4,294,967,296 / (10 ^ 4) => 429,496.7296` with 4 decimals of precision.

## Example 2

The price of BTC is 60,000, and BTC has 8 decimals.

The price of one unit of BTC is `60,000 / (10 ^ 8), 6 * (10 ^ -4)`.

Price would be stored as `60,000 / (10 ^ 8) * (10 ^ 30) => 6 * (10 ^ 26) => 60,000 * (10 ^ 22)`.

BTC prices maximum value: `(2 ^ 64) / (10 ^ 2) => 4,294,967,296 / (10 ^ 2) => 42,949,672.96`.

Decimals of precision: 2.

## Example 3

The price of USDC is 1, and USDC has 6 decimals.

The price of one unit of USDC is `1 / (10 ^ 6), 1 * (10 ^ -6)`.

Price would be stored as `1 / (10 ^ 6) * (10 ^ 30) => 1 * (10 ^ 24)`.

USDC prices maximum value: `(2 ^ 64) / (10 ^ 6) => 4,294,967,296 / (10 ^ 6) => 4294.967296`.

Decimals of precision: 6.

## Example 4

The price of DG is 0.00000001, and DG has 18 decimals.

The price of one unit of DG is `0.00000001 / (10 ^ 18), 1 * (10 ^ -26)`.

Price would be stored as `1 * (10 ^ -26) * (10 ^ 30) => 1 * (10 ^ 3)`.

DG prices maximum value: `(2 ^ 64) / (10 ^ 11) => 4,294,967,296 / (10 ^ 11) => 0.04294967296`.

Decimals of precision: 11.

## Decimal Multiplier

The formula to calculate what the decimal multiplier value should be set to:

Decimals: 30 - (token decimals) - (number of decimals desired for precision)

- ETH: 30 - 18 - 4 => 8
- BTC: 30 - 8 - 2 => 20
- USDC: 30 - 6 - 6 => 18
- DG: 30 - 18 - 11 => 1

## For Data Stream Feeds

Example calculation for WNT:

- The number of data stream decimals: 8
- The number of token decimals for WNT: 18
- dataStreamPrice: price \* (10 ^ 8)
- The price per unit of token: `dataStreamPrice / (10 ^ 8) / (10 ^ 18) * (10 ^ 30)`
- e.g. `(5000 * (10 ^ 8)) / (10 ^ 8) / (10 ^ 18) * (10 ^ 30) = 5000 * (10 ^ 12)`
- The stored oracle price is: `dataStreamPrice * multiplier / (10 ^ 30)`
- In this case the multiplier should be (10 ^ 34)
- e.g. `(5000 * (10 ^ 8)) * (10 ^ 34) / (10 ^ 30) = 5000 * (10 ^ 12)`

Example calculation for WBTC:

- The number of data stream decimals: 8
- The number of token decimals for WBTC: 8
- dataStreamPrice: price \* (10 ^ 8)
- the price per unit of token: `dataStreamPrice / (10 ^ 8) / (10 ^ 8) * (10 ^ 30)`
- e.g. `(50,000 * (10 ^ 8)) / (10 ^ 8) / (10 ^ 8) * (10 ^ 30) = 50,000 * (10 ^ 22)`
- the stored oracle price is: `dataStreamPrice * multiplier / (10 ^ 30)`
- in this case the multiplier should be (10 ^ 44)
- e.g. `(50,000 * (10 ^ 8)) * (10 ^ 44) / (10 ^ 30) = 50,000 * (10 ^ 22)`

The formula for the multiplier is: `10 ^ (60 - dataStreamDecimals - tokenDecimals)`

# Funding Fees

Funding fees incentivise the balancing of long and short positions, the side with the larger open interest pays a funding fee to the side with the smaller open interest.

Funding fees for the larger side is calculated as `(funding factor per second) * (open interest imbalance) ^ (funding exponent factor) / (total open interest)`.

For example if the funding factor per second is 1 / 50,000, and the funding exponent factor is 1, and the long open interest is $150,000 and the short open interest is $50,000 then the funding fee per second for longs would be `(1 / 50,000) * 100,000 / 200,000 => 0.00001 => 0.001%`.

The funding fee per second for shorts would be `-0.00001 * 150,000 / 50,000 => 0.00003 => -0.003%`.

It is also possible to set a fundingIncreaseFactorPerSecond value, this would result in the following funding logic:

- The `longShortImbalance` is calculated as `[abs(longOpenInterest - shortOpenInterest) / totalOpenInterest] ^ fundingExponentFactor`
- If the current `longShortImbalance` is more than the `thresholdForStableFunding`, then the funding rate will increase by `longShortImbalance * fundingIncreaseFactorPerSecond`
- If the current `longShortImbalance` is more than `thresholdForDecreaseFunding` and less than `thresholdForStableFunding` and the skew is in the same direction as the funding, then the funding rate will not change
- If the current `longShortImbalance` is less than `thresholdForDecreaseFunding` and the skew is in the same direction as the funding, then the funding rate will decrease by `fundingDecreaseFactorPerSecond`

## Examples

### Example 1

- thresholdForDecreaseFunding is 3%
- thresholdForStableFunding is 5%
- fundingIncreaseFactorPerSecond is 0.0001%
- fundingDecreaseFactorPerSecond is 0.000002%
- durationInSeconds is 600 seconds
- longs are paying shorts funding
- there are more longs than shorts
- longShortImbalance is 6%

Since longShortImbalance > thresholdForStableFunding, savedFundingFactorPerSecond should increase by `0.0001% * 6% * 600 = 0.0036%`

### Example 2

- thresholdForDecreaseFunding is 3%
- thresholdForStableFunding is 5%
- fundingIncreaseFactorPerSecond is 0.0001%
- fundingDecreaseFactorPerSecond is 0.000002%
- durationInSeconds is 600 seconds
- longs are paying shorts funding
- there are more longs than shorts
- longShortImbalance is 4%

Since longs are already paying shorts, the skew is the same, and the longShortImbalance < thresholdForStableFunding, savedFundingFactorPerSecond should not change

### Example 3

- thresholdForDecreaseFunding is 3%
- thresholdForStableFunding is 5%
- fundingIncreaseFactorPerSecond is 0.0001%
- fundingDecreaseFactorPerSecond is 0.000002%
- durationInSeconds is 600 seconds
- longs are paying shorts funding
- there are more longs than shorts
- longShortImbalance is 2%

Since longShortImbalance < thresholdForDecreaseFunding, savedFundingFactorPerSecond should decrease by `0.000002% * 600 = 0.0012%`

### Example 4

- thresholdForDecreaseFunding is 3%
- thresholdForStableFunding is 5%
- fundingIncreaseFactorPerSecond is 0.0001%
- fundingDecreaseFactorPerSecond is 0.000002%
- durationInSeconds is 600 seconds
- longs are paying shorts funding
- there are more shorts than longs
- longShortImbalance is 1%

Since the skew is in the other direction, savedFundingFactorPerSecond should decrease by `0.0001% * 1% * 600 = 0.0006%`

Note that there are possible ways to game the funding fees, the funding factors should be adjusted to minimize this possibility:

- If longOpenInterest > shortOpenInterest and longShortImbalance is within thresholdForStableFunding, a user holding a short position could open a long position to increase the longShortImbalance and attempt to cause the funding fee to increase. In an active market, it should be difficult to predict when an opposing short position would be opened by someone else to earn the increased funding fee which should make this gaming difficult, the funding factors can also be adjusted to help minimize the benefit of this gaming.

- If longOpenInterest > shortOpenInterest and longShortImbalance > thresholdForStableFunding, a trader holding a long position could make multiple small trades during this time to ensure that the funding factor is continually updated instead of a larger value being used for the entirety of the duration, this should minimize the funding fee for long positions but should not decrease the funding fee below the expected rates.

# Borrowing Fees

There is a borrowing fee paid to liquidity providers, this helps prevent users from opening both long and short positions to take up pool capacity without paying any fees.

Borrowing fees can use a curve model or kink model.

To use the curve model, the keys to configure would be `BORROWING_FACTOR` and `BORROWING_EXPONENT_FACTOR`, the borrowing factor per second would be calculated as:

```
// reservedUsd is the total USD value reserved for positions
reservedUsd = MarketUtils.getReservedUsd(...)

// poolUsd is the USD value of the pool excluding pending trader PnL
poolUsd = MarketUtils.getPoolUsdWithoutPnl(...)

// reservedUsdAfterExponent is the reservedUsd after applying the borrowingExponentFactor for the market

reservedUsdAfterExponent = applyExponentFactor(reservedUsd, borrowingExponentFactor)

borrowingFactorPerSecond = borrowingFactor * reservedUsdAfterExponent / poolUsd
```

To use the kink model, the keys to configure would be `OPTIMAL_USAGE_FACTOR`, `BASE_BORROWING_FACTOR` and `ABOVE_OPTIMAL_USAGE_BORROWING_FACTOR`, the borrowing factor per second would be calculated as:

```
// usageFactor is the ratio of value reserved for positions to available value that can be reserved
usageFactor = MarketUtils.getUsageFactor(...)

borrowingFactorPerSecond = baseBorrowingFactor * usageFactor

if (usageFactor > optimalUsageFactor) {
  diff = usageFactor - optimalUsageFactor
  additionalBorrowingFactorPerSecond = aboveOptimalUsageBorrowingFactor - baseBorrowingFactor

  borrowingFactorPerSecond += additionalBorrowingFactorPerSecond * diff / (Precision.FLOAT_PRECISION - optimalUsageFactor)
}
```

There is also an option to set a skipBorrowingFeeForSmallerSide flag, this would result in the borrowing fee for the smaller side being set to zero. For example, if there are more longs than shorts and skipBorrowingFeeForSmallerSide is true, then the borrowing fee for shorts would be zero.

## Price Impact

The code for price impact can be found in the `/pricing` contracts.

Price impact is calculated as:

```
(initial USD difference) ^ (price impact exponent) * (price impact factor) - (next USD difference) ^ (price impact exponent) * (price impact factor)
```

For swaps, imbalance is calculated as the difference in the worth of the long tokens and short tokens.

For example:

- A pool has 10 long tokens, each long token is worth $5000
- The pool also has 50,000 short tokens, each short token is worth $1
- The `price impact exponent` is set to 2 and `price impact factor` is set to `0.01 / 50,000`
- The pool is equally balanced with $50,000 of long tokens and $50,000 of short tokens
- If a user deposits 10 long tokens, the pool would now have $100,000 of long tokens and $50,000 of short tokens
- The change in imbalance would be from $0 to -$50,000
- There would be negative price impact charged on the user's deposit, calculated as `0 ^ 2 * (0.01 / 50,000) - 50,000 ^ 2 * (0.01 / 50,000) => -$500`
- If the user now withdraws 5 long tokens, the balance would change from -$50,000 to -$25,000, a net change of +$25,000
- There would be a positive price impact rebated to the user in the form of additional long tokens, calculated as `50,000 ^ 2 * (0.01 / 50,000) - 25,000 ^ 2 * (0.01 / 50,000) => $375`

For position actions (increase / decrease position), imbalance is calculated as the difference in the long and short open interest.

`price impact exponents` and `price impact factors` are configured per market and can differ for spot and position actions.

Note that this calculation is the price impact for a user's trade not the price impact on the pool. For example, a user's trade may have a 0.25% price impact, the next trade for a very small amount may have a 0.5% price impact.

The purpose of the price impact is to:

- Incentivise balance of tokens in pools
- Incentivise balance of longs / shorts
- Reduce risk of price manipulation

Since the contracts use an oracle price which would be an average or median price of multiple reference exchanges. Without a price impact, it may be profitable to manipulate the prices on reference exchanges while executing orders on the contracts.

This risk will also be present if the positive and negative price impact values are similar, for that reason the positive price impact should be set to a low value in times of volatility or irregular price movements.

For the price impact on position increases / decreases, if negative price impact is deducted as collateral from the position, this could lead to the position having a different leverage from what the user intended, so instead of deducting collateral the position's entry / exit price is adjusted based on the price impact.

For example:

- The oracle price of the index token is $5000
- A user opens a long position of size $50,000 with a negative price impact of 0.1%
- The user's position size is in USD is $50,000 and the size in tokens is (50,000 / 5000) \* (100 - 0.1)% => 9.99
- This gives the position an entry price of 50,000 / 9.99 => ~$5005
- The negative price impact is tracked as a number of index tokens in the pool
- In this case there would be 0.01 index tokens in the position impact pool
- The pending PnL of the user at this point would be (50,000 - 9.99 \* 5000) => $50
- The tokens in the position impact pool should be accounted for when calculating the pool value to offset this pending PnL
- The net impact on the pool is zero, +$50 from the pending negative PnL due to price impact and -$50 from the 0.01 index tokens in the position impact pool worth $50
- If the user closes the position at a negative price impact of 0.2%, the position impact pool would increase to 0.03 index tokens
- The user would receive (original position collateral - $150)
- The pool would have an extra $150 of collateral which continues to have a net zero impact on the pool value due to the 0.03 index tokens in the position impact pool

If the index token is different from both the long and short token of the market, then it is possible that the pool value becomes significantly affected by the position impact pool, if the position impact pool is very large and the index token has a large price increase. An option to gradually reduce the size of the position impact pool may be added if this becomes an issue.

Price impact is also tracked using a virtual inventory value for positions and swaps, this tracks the imbalance of tokens across similar markets, e.g. ETH/USDC, ETH/USDT.

In case of a large price movement, it is possible that a large amount of positions are decreased or liquidated on one side causing a significant imbalance between long and short open interest, this could lead to very high price impact values. To mitigate this, a max position impact factor value can be configured. If the current price impact exceeds the max negative price impact, then any excess collateral deducted beyond the max negative price impact would be held within the contract, if there was no price manipulation detected, this collateral can be released to the user. When the negative price impact is capped, it may be profitable to open and immediately close positions, since the positive price impact may now be more than the capped negative price impact. To avoid this, the max positive price impact should be configured to be below the max negative price impact.

# Fees

There are configurable swap fees and position fees and per market.

Execution fees are also estimated and accounted for on creation of deposit, withdrawal, order requests so that keepers can execute transactions at a close to net zero cost.

# Reserve Amounts

If a market has stablecoins as the short collateral token it should be able to fully pay short profits if the max short open interest does not exceed the amount of stablecoins in the pool.

If a market has a long collateral token that is different from the index token, the long profits may not be fully paid out if the price increase of the index token exceeds the price increase of the long collateral token.

Markets have a reserve factor that allows open interest to be capped to a percentage of the pool size, this reduces the impact of profits of short positions and reduces the risk that long positions cannot be fully paid out.

# Market Token Price

The price of a market token depends on the worth of the assets in the pool, and the net pending PnL of traders' open positions.

It is possible for the pending PnL to be capped, the factors used to calculate the market token price can differ depending on the activity:

- Keys.MAX_PNL_FACTOR_FOR_DEPOSITS: this is the PnL factor cap when calculating the market token price for deposits

- Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS: this is the PnL factor cap when calculating the market token price for withdrawals

- Keys.MAX_PNL_FACTOR_FOR_TRADERS: this is the PnL factor cap when calculating the market token price for closing a position

These different factors can be configured to help liquidity providers manage risk and to incentivise deposits when needed, e.g. capping of trader PnL helps cap the amount the market token price can be decreased by due to trader PnL, capping of PnL for deposits and withdrawals can lead to a lower market token price for deposits compared to withdrawals which can incentivise deposits when pending PnL is high.

# Parameters

- minCollateralFactor: This determines the minimum allowed ratio of (position collateral) / (position size)

- maxPoolAmount: The maximum amount of tokens that can be deposited into a market

- maxOpenInterest: The maximum open interest that can be opened for a market

- reserveFactor: This determines the maximum allowed ratio of (worth of tokens reserved for positions) / (tokens in the pool)

- maxPnlFactor: The maximum ratio of (PnL / worth of tokens in the pool)

- positionFeeFactor: This determines the percentage amount of fees to be deducted for position increase / decrease actions, the fee amount is based on the change in position size

- positionImpactFactor: This is the "price impact factor" for positions described in the "Price Impact" section

- maxPositionImpactFactor: This is the "max price impact" for positions described in the "Price Impact" section

- positionImpactExponentFactor: This is the "price impact exponent" value for position actions, described in the "Price Impact" section

- swapFeeFactor: This determines the percentage amount of fees to be deducted for swaps, the fee amount is based on the swap amount

- swapImpactFactor: This is the "price impact factor" described in the "Price Impact" section

- swapImpactExponentFactor: This is the "price impact exponent" value for deposits and swaps, described in the "Price Impact" section above

- fundingFactor: This is the "funding factor per second" value described in the "Funding Fees" section

- borrowingFactorForLongs: This is the "borrowing factor" for long positions described in the "Borrowing Fees" section

- borrowingFactorForShorts: This is the "borrowing factor" for short positions described in the "Borrowing Fees" section

- borrowingExponentFactorForLongs: This is the "borrowing exponent factor" for long positions described in the "Borrowing Fees" section

- borrowingExponentFactorForShorts: This is the "borrowing exponent factor" for long positions described in the "Borrowing Fees" section

# Roles

Roles are managed in the RoleStore, the RoleAdmin has access to grant and revoke any role.

The RoleAdmin will be the deployer initially, but this should be removed after roles have been setup.

After the initial setup:

- Only the Timelock contract should have the RoleAdmin role

- New roles can be granted by timelock admins with a time delay

- System values should only be set using the Config contract

- No EOA should have a Controller role

- Config keepers and timelock admins could potentially disrupt regular operation through the disabling of features, incorrect setting of values, whitelisting malicious tokens, abusing the positive price impact value, etc

- It is expected that the timelock multisig should revoke the permissions of malicious or compromised accounts

- Order keepers and frozen order keepers could potentially extract value through transaction ordering, delayed transaction execution, ADL execution, etc, this will be partially mitigated with a keeper network

- Oracle signers are expected to accurately report the price of tokens

# Known Issues

## Tokens

- Collateral tokens need to be whitelisted with a configured TOKEN_TRANSFER_GAS_LIMIT

- Rebasing tokens, tokens that change balance on transfer, with token burns, tokens with callbacks e.g. ERC-777 tokens, etc, are not compatible with the system and should not be whitelisted

## Keepers

- Order keepers can use prices from different timestamps for limit orders with a swap, which would lead to different output amounts

- Order keepers are expected to validate whether a transaction will revert before sending the transaction to minimize gas wastage

- Order keepers may cause requests to be cancelled instead of executed by executing the request with insufficient gas

- If an execution transaction requires a large amount of gas that is close to the maximum block gas limit, it may be possible to stuff blocks to prevent the transaction from being included in blocks

- In certain blockchains it is possible for the keeper to have control over the tx.gasprice used to execute a transaction which would affect the execution fee paid to the keeper

- Orders may be prevented from execution by a malicious user intentionally causing a market to be unbalanced resulting in a high price impact, this should be costly and difficult to benefit from

## Price Impact

- Price impact can be reduced by using positions and swaps and trading across markets, chains, forks, other protocols, this is partially mitigated with virtual inventory tracking

- A user can reduce price impact by using high leverage positions, this is partially mitigated with the MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER value

- Calculation of price impact values do not account for fees and the effects resulting from the price impact itself, for most cases the effect on the price impact calculation should be small

## Market Token Price

- It is rare but possible for a pool's value to become negative, this can happen since the impactPoolAmount and pending PnL is subtracted from the worth of the tokens in the pool

- Due to the difference in positive and negative position price impact, there can be a build up of virtual token amounts in the position impact pool which would affect the pricing of market tokens, the position impact pool should be gradually distributed if needed

## Virtual Inventory

- Virtual inventory tracks the amount of tokens in pools, it must be ensured that the tokens in each grouping are the same type and have the same decimals, i.e. the long tokens across pools in the group should have the same decimals, the short tokens across pools in the group should have the same decimals, assuming USDC has 6 decimals and DAI has 18 decimals, markets like ETH-USDC, ETH-DAI should not be grouped

- Virtual IDs must be set before market creation / token whitelisting, if it is set after trading for the token / market is done, the tracking would not be accurate and may need to be adjusted

## Blockchain

- For L2s with sequencers, there is no contract validation to check if the L2 sequencer is active, oracle keepers should stop signing prices if no blocks are being created by the sequencer, if the sequencer resumes regular operation, the oracle keepers should sign prices for the latest blocks using the latest fetched prices

- In case an L2 sequencer is down, it may prevent deposits into positions to prevent liquidations

- For transactions that can be executed entirely using on-chain price feeds, it may be possible to take advantage of stale pricing due to price latency or the chain being down, usage of on-chain price feeds should be temporary and low latency feeds should be used instead once all tokens are supported

- Block re-orgs could allow a user to retroactively cancel an order after it has been executed if price did not move favourably for the user, care should be taken to handle this case if using the contracts on chains where long re-orgs are possible

- Updating and cancellation of orders could be front-run to prevent order execution, this should not be an issue if the probability of a successful front-running is less than or equal to 50%, if the probability is higher than 50%, fees and price impact should be adjusted to ensure that the strategy is not net profitable, adjusting the ui fee or referral discount could similarly be used to cause order cancellations

- In case of downtime of the blockchain or oracle, orders may be executed at significantly different prices or may not execute if the order's acceptable price cannot be fulfilled

- There is a dependency on the accuracy of the block timestamp because oracle prices are validated against this value, for blockchains where the blockchain nodes have some control over the timestamp, care should be taken to set the oracleTimestampAdjustment to a value that would make manipulation of the timestamp unprofitable

## GLV

- The GLV shift feature can be exploited by temporarily increasing the utilization in a market that typically has low utilization. Once the keeper executes the shift, the attacker can lower the utilization back to its normal levels. Position fees and price impact should be configured in a way that makes this attack expensive enough to cover the GLV loss.

- In GLV there may be GM markets which are above their maximum pnlToPoolFactorForTraders. If this GM market's maxPnlFactorForDeposits is higher than maxPnlFactorForTraders then the GM market is valued lower during deposits than it will be once traders have realized their capped profits. Malicious user may observe a GM market in such a condition and deposit into the GLV containing it in order to gain from ADLs which will soon follow. To avoid this maxPnlFactorForDeposits should be less than or equal to maxPnlFactorForTraders.

- It's technically possible for market value to become negative. In this case the GLV would be unusable until the market value becomes positive.

- GM tokens could become illiquid due to high pnl factor or high reserved usd. Users can deposit illiquid GM tokens into GVL and withdraw liquidity from a different market, leaving the GLV with illiquid tokens. The glvMaxMarketTokenBalanceUsd and glvMaxMarketTokenBalanceAmount parameters should account for the riskiness of a market to avoid having too many GM tokens from a risky market.

## Factories

- Upon adding a Market with the MarketStoreUtils.set function, the Market is given a lookup where the Market address can be obtained with the Market salt. This lookup is not cleared upon market deletion. The same applies to GLV.

# Notes

## Deployment

- `scripts/verifyFallback.ts` can be used to verify contracts
- One MarketToken contract would need to be verified using `npx hardhat verify`, thereafter all MarketToken contracts should be verified as the source code would be the same

## Configuration

- The `MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR` is used mainly as a sanity check to help guard against incorrect oracle decimal configuration or incorrect price feed configuration, this should be set to a sufficiently high value to prevent reverts during times of high volatility

## Upgrades

- If new contracts are added that may lead to a difference in pricing, e.g. of market tokens between the old and new contracts, then care should be taken to disable the old contracts before the new contracts are enabled

- Any external protocols that use the Reader contract or potentially outdated calculations for pricing should be reminded to use the latest contracts and calculations, e.g. Chainlink price feeds for GM tokens

- It is recommended to publish a best effort Changelog documenting important changes that integrations should be aware about, e.g. if a field is added to a struct that is passed into a callback function, this change may not be obvious to integrations

- If the contracts are used to support equity synthetic markets, care should be taken to ensure that stock splits and similar changes can be handled

- Contracts with the "CONTROLLER" role have access to important functions such as setting DataStore values, due to this, care should be taken to ensure that such contracts do not have generic functions or functions that can be used to change important values

- Tests should be added for the different market types, e.g. spot only markets, single token markets

- The ordering of values in the eventData for callbacks should not be modified unless strictly necessary, since callback contracts may reference the values by a fixed index

- Note that if a struct that is passed into callbacks is changed, e.g. Deposit, Withdrawal, Order structs, this would cause the functions of callback contracts expecting the previous struct to stop working, due to this, the changes in structs should be highlighted to integrations

- If the referral system is being used, the OrderHandler should be given access to update the referral code for traders

## Integrations

- Deposits, withdrawals and orders may be cancelled if the requirements specified in the request cannot be fulfilled, e.g. min amount out. Do check where funds and gas refunds will be sent to on cancellation to ensure it matches expectations.

- Decrease position orders can output two tokens instead of a single token, in case the decrease position swap fails, it is also possible that the output amount and collateral may not be sufficient to cover fees, causing the order to not be executed

- If there is a large spread, it is possible that opening / closing a position can significantly change the min and max price of the market token, this should not be manipulatable in a profitable way

- Changes in config values such as FUNDING_FACTOR, STABLE_FUNDING_FACTOR, BORROWING_FACTOR, SKIP_BORROWING_FEE_FOR_SMALLER_SIDE, BORROWING_FEE_RECEIVER_FACTOR, could lead to additional charges for users, it could also result in a change in the price of market tokens

- If trader PnL is capped due to MAX_PNL_FACTOR_FOR_TRADERS, the percentage of profit paid out to traders may differ depending on the ordering of when positions are decreased / closed since the cap is re-calculated based on the current state of the pool

- Event data may be passed to callback contracts, the ordering of the params in the eventData will be attempted to be unchanged, so params can be accessed by index, for safety the key of the param should still be validated before use to check if it matches the expected value

- Some parameters such as order.sizeDelta and order.initialCollateralDeltaAmount may be updated during execution, the updated values may not be passed to the callback contract

- When creating a callback contract, the callback contract may need to whitelist the DepositHandler, OrderHandler or WithdrawalHandler, it should be noted that new versions of these handlers may be deployed as new code is added to the handlers, it is also possible for two handlers to temporarily exist at the same time, e.g. OrderHandler(1), OrderHandler(2), due to this, the callback contract should be able to whitelist and simultaneously accept callbacks from multiple DepositHandlers, OrderHandlers and WithdrawalHandlers

- For callback contracts instead of maintaining a separate whitelist for DepositHandlers, OrderHandlers, WithdrawalHandlers, a possible solution would be to validate the role of the msg.sender in the RoleStore, e.g. `RoleStore.hasRole(msg.sender, Role.CONTROLLER)`, this would check that the msg.sender is a valid handler

- If using contracts such as the ExchangeRouter, Oracle or Reader do note that their addresses will change as new logic is added

- If contracts such as the ExchangeRouter, Oracle or Reader are updated, effort should be made to keep the function parameters the same, however, this may not always be possible, e.g. if a new order property is to be supported, the ExchangeRouter.createOrder params will have to be changed

- The RoleStore and DataStore for deployments should not change, if they are changed a migration of funds from the previous contracts to the new contracts will likely be needed

- While the code has been structured to minimize the risk of [read-only reentrancy](https://officercia.mirror.xyz/DBzFiDuxmDOTQEbfXhvLdK0DXVpKu1Nkurk0Cqk3QKc), care should be taken to guard against this possibility

- Token airdrops may occur to the accounts of GM token holders, integrating contracts holding GM tokens must be able to claim these tokens otherwise the tokens would be locked, the exact implementation for this will vary depending on the integrating contract, one possibility is to allow claiming of tokens that are not market tokens, this can be checked using the `Keys.MARKET_LIST` value

- ETH transfers are sent with NATIVE_TOKEN_TRANSFER_GAS_LIMIT for the gas limit, if the transfer fails due to insufficient gas or other errors, the ETH is sent as WETH instead

- Accounts may receive ETH for ADLs / liquidations, if the account cannot receive ETH then WETH would be sent instead

- Positive price impact is capped by the amount of tokens in the impact pools and based on configured values

- Negative price impact may be capped by configured values

- If negative price impact is capped, the additional amount would be kept in the claimable collateral pool, this needs to be manually claimed using the ExchangeRouter.claimCollateral function

- Positive funding fees need to be manually claimed using the ExchangeRouter.claimFundingFees function

- Affiliate rewards need to be manually claimed using the ExchangeRouter.claimAffiliateRewards function

- Markets or features may be disabled

- Execution will still continue even if a callback reverts

- Ensure callbacks have sufficient gas

- Subaccounts can create, update, and cancel any order for an account

- Subaccounts can spend wnt and collateral from the account

- UI fees can be changed

- Referral discounts can be changed

- Funds for blacklisted addresses will be kept within the protocol

- The index token is not always guaranteed to be the long token

- Fee rates change depending on whether there is a positive or negative impact

### Deposits

- Consider PnL Factor when estimating GM price

- Handle deposit cancellations

- Ensure only handlers with the CONTROLLER role can call the afterDepositExecution and afterDepositCancellation callback functions

- Ensure only the correct deposit execution can call callback functions

- Consider markets with the same long and short token, swaps are not supported for these markets

- Consider positive and negative price impact

- There is a request cancellation period for a configured delay where deposit requests cannot be cancelled

- Output amounts are subject to price impact and fees

- Deposits are not allowed above the MAX_PNL_FACTOR_FOR_DEPOSITS

- The first deposit in any market must go to the RECEIVER_FOR_FIRST_DEPOSIT

### Withdrawals

- Two minimum outputs must be used for withdrawals

- Handle withdrawal cancellations

- Ensure only handlers with the CONTROLLER role can call the afterWithdrawalExecution and afterWithdrawalCancellation callback functions

- Ensure only the correct withdrawal execution can call callback functions

- Consider markets with the same long and short token, swaps are not supported for these markets

- Consider positive and negative price impact

- There is a request cancellation period for a configured delay where withdrawal requests cannot be cancelled

- Output amounts are subject to price impact and fees

- Withdrawals are not allowed above the MAX_PNL_FACTOR_FOR_WITHDRAWALS

### Orders

- Handle order cancellations

- Liquidations and ADLs can trigger the saved callback contract

- Orders can become frozen

- Ensure only handlers with the CONTROLLER role can call the afterOrderExecution, afterOrderCancellation and afterOrderFrozen callback functions

- Ensure only the correct order execution can call callback functions

- Consider markets with the same long and short token, swaps are not supported for these markets

- Consider positive and negative price impact

- Saved callback contracts can be changed

- There is a request cancellation period for a configured delay where order requests cannot be cancelled

- Output amounts are subject to price impact and fees

- The position impact pool is distributed to liquidity providers over time

- If attempting to compute price impact, the virtual inventory should be consulted

- Trader PnL is capped above the MAX_PNL_FACTOR_FOR_TRADERS

- Negative Price Impact can be capped on position decreases

- Decrease order sizeDelta and collateralDelta will be auto-updated if they are greater than the position can handle

- Consider willPositionCollateralBeSufficient validation

- Consider decreasePositionSwapTypes

- Consider the minimum collateral amount

- Referrals are still paid out during liquidation

- It is possible for positions to have zero collateral

- Positions with zero size cannot exist

# Commands

To compile contracts:

```
npx hardhat compile
```

To run all tests:

```
npx hardhat test

```

`export NODE_OPTIONS=--max_old_space_size=4096` may be needed to run tests.

To print code metrics:

```
npx ts-node metrics.ts
```

To print test coverage:

```
npx hardhat coverage
```
