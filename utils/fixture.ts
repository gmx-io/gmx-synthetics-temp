import hre from "hardhat";

import { expandDecimals } from "./math";
import { hashData } from "./hash";
import { getMarketTokenAddress, DEFAULT_MARKET_TYPE } from "./market";
import { getSyntheticTokenAddress } from "./token";
import { getGlvAddress } from "./glv";

export async function deployFixture() {
  await hre.deployments.fixture();
  const chainId = 31337; // hardhat chain id
  const accountList = await hre.ethers.getSigners();
  const [
    wallet,
    user0,
    user1,
    user2,
    user3,
    user4,
    user5,
    user6,
    user7,
    user8,
    signer0,
    signer1,
    signer2,
    signer3,
    signer4,
    signer5,
    signer6,
    signer7,
    signer8,
    signer9,
  ] = accountList;

  const wnt = await hre.ethers.getContract("WETH");
  await wnt.deposit({ value: expandDecimals(50, 18) });

  const gmx = await hre.ethers.getContract("GMX");

  const wbtc = await hre.ethers.getContract("WBTC");
  const sol = { address: getSyntheticTokenAddress(hre.network.config.chainId, "SOL") };

  const usdc = await hre.ethers.getContract("USDC");
  const usdt = await hre.ethers.getContract("USDT");

  const usdcPriceFeed = await hre.ethers.getContract("USDCPriceFeed");
  await usdcPriceFeed.setAnswer(expandDecimals(1, 8));

  const usdtPriceFeed = await hre.ethers.getContract("USDTPriceFeed");
  await usdtPriceFeed.setAnswer(expandDecimals(1, 8));

  const wethPriceFeed = await hre.ethers.getContract("WETHPriceFeed");
  await wethPriceFeed.setAnswer(expandDecimals(5000, 8));

  const gmxPriceFeed = await hre.ethers.getContract("GMXPriceFeed");
  await gmxPriceFeed.setAnswer(expandDecimals(20, 8));

  const oracleSalt = hashData(["uint256", "string"], [chainId, "xget-oracle-v1"]);

  const config = await hre.ethers.getContract("Config");
  const configSyncer = await hre.ethers.getContract("ConfigSyncer");
  const mockRiskOracle = await hre.ethers.getContract("MockRiskOracle");
  const timelock = await hre.ethers.getContract("Timelock");
  const reader = await hre.ethers.getContract("Reader");
  const glvReader = await hre.ethers.getContract("GlvReader");
  const roleStore = await hre.ethers.getContract("RoleStore");
  const dataStore = await hre.ethers.getContract("DataStore");
  const depositVault = await hre.ethers.getContract("DepositVault");
  const withdrawalVault = await hre.ethers.getContract("WithdrawalVault");
  const shiftVault = await hre.ethers.getContract("ShiftVault");
  const eventEmitter = await hre.ethers.getContract("EventEmitter");
  const oracleStore = await hre.ethers.getContract("OracleStore");
  const orderVault = await hre.ethers.getContract("OrderVault");
  const glvVault = await hre.ethers.getContract("GlvVault");
  const marketFactory = await hre.ethers.getContract("MarketFactory");
  const glvFactory = await hre.ethers.getContract("GlvFactory");
  const glvHandler = await hre.ethers.getContract("GlvHandler");
  const glvRouter = await hre.ethers.getContract("GlvRouter");
  const glvDepositStoreUtils = await hre.ethers.getContract("GlvDepositStoreUtils");
  const glvWithdrawalStoreUtils = await hre.ethers.getContract("GlvWithdrawalStoreUtils");
  const glvShiftStoreUtils = await hre.ethers.getContract("GlvShiftStoreUtils");
  const glvStoreUtils = await hre.ethers.getContract("GlvStoreUtils");
  const depositHandler = await hre.ethers.getContract("DepositHandler");
  const depositUtils = await hre.ethers.getContract("DepositUtils");
  const executeDepositUtils = await hre.ethers.getContract("ExecuteDepositUtils");
  const withdrawalHandler = await hre.ethers.getContract("WithdrawalHandler");
  const shiftHandler = await hre.ethers.getContract("ShiftHandler");
  const orderHandler = await hre.ethers.getContract("OrderHandler");
  const baseOrderUtils = await hre.ethers.getContract("BaseOrderUtils");
  const orderUtils = await hre.ethers.getContract("OrderUtils");
  const liquidationHandler = await hre.ethers.getContract("LiquidationHandler");
  const adlHandler = await hre.ethers.getContract("AdlHandler");
  const router = await hre.ethers.getContract("Router");
  const exchangeRouter = await hre.ethers.getContract("ExchangeRouter");
  const gelatoRelayRouter = await hre.ethers.getContract("GelatoRelayRouter");
  const subaccountGelatoRelayRouter = await hre.ethers.getContract("SubaccountGelatoRelayRouter");
  const subaccountRouter = await hre.ethers.getContract("SubaccountRouter");
  const oracle = await hre.ethers.getContract("Oracle");
  const gmOracleProvider = await hre.ethers.getContract("GmOracleProvider");
  const chainlinkPriceFeedProvider = await hre.ethers.getContract("ChainlinkPriceFeedProvider");
  const chainlinkDataStreamProvider = await hre.ethers.getContract("ChainlinkDataStreamProvider");
  const marketUtils = await hre.ethers.getContract("MarketUtils");
  const marketStoreUtils = await hre.ethers.getContract("MarketStoreUtils");
  const depositStoreUtils = await hre.ethers.getContract("DepositStoreUtils");
  const withdrawalStoreUtils = await hre.ethers.getContract("WithdrawalStoreUtils");
  const shiftStoreUtils = await hre.ethers.getContract("ShiftStoreUtils");
  const positionStoreUtils = await hre.ethers.getContract("PositionStoreUtils");
  const orderStoreUtils = await hre.ethers.getContract("OrderStoreUtils");
  const decreasePositionUtils = await hre.ethers.getContract("DecreasePositionUtils");
  const increaseOrderUtils = await hre.ethers.getContract("IncreaseOrderUtils");
  const increasePositionUtils = await hre.ethers.getContract("IncreasePositionUtils");
  const positionUtils = await hre.ethers.getContract("PositionUtils");
  const swapUtils = await hre.ethers.getContract("SwapUtils");
  const referralStorage = await hre.ethers.getContract("ReferralStorage");
  const feeHandler = await hre.ethers.getContract("FeeHandler");
  const mockVaultV1 = await hre.ethers.getContract("MockVaultV1");

  const ethUsdMarketAddress = getMarketTokenAddress(
    wnt.address,
    wnt.address,
    usdc.address,
    DEFAULT_MARKET_TYPE,
    marketFactory.address,
    roleStore.address,
    dataStore.address
  );
  const ethUsdMarket = await reader.getMarket(dataStore.address, ethUsdMarketAddress);

  const ethUsdtMarketAddress = getMarketTokenAddress(
    wnt.address,
    wnt.address,
    usdt.address,
    DEFAULT_MARKET_TYPE,
    marketFactory.address,
    roleStore.address,
    dataStore.address
  );
  const ethUsdtMarket = await reader.getMarket(dataStore.address, ethUsdtMarketAddress);

  const ethUsdSpotOnlyMarketAddress = getMarketTokenAddress(
    ethers.constants.AddressZero,
    wnt.address,
    usdc.address,
    DEFAULT_MARKET_TYPE,
    marketFactory.address,
    roleStore.address,
    dataStore.address
  );
  const ethUsdSpotOnlyMarket = await reader.getMarket(dataStore.address, ethUsdSpotOnlyMarketAddress);

  const ethUsdSingleTokenMarketAddress = getMarketTokenAddress(
    wnt.address,
    usdc.address,
    usdc.address,
    DEFAULT_MARKET_TYPE,
    marketFactory.address,
    roleStore.address,
    dataStore.address
  );
  const ethUsdSingleTokenMarket = await reader.getMarket(dataStore.address, ethUsdSingleTokenMarketAddress);

  const ethUsdSingleTokenMarket2Address = getMarketTokenAddress(
    wnt.address,
    wnt.address,
    wnt.address,
    DEFAULT_MARKET_TYPE,
    marketFactory.address,
    roleStore.address,
    dataStore.address
  );
  const ethUsdSingleTokenMarket2 = await reader.getMarket(dataStore.address, ethUsdSingleTokenMarket2Address);

  const btcUsdMarketAddress = getMarketTokenAddress(
    wbtc.address,
    wbtc.address,
    usdc.address,
    DEFAULT_MARKET_TYPE,
    marketFactory.address,
    roleStore.address,
    dataStore.address
  );
  const btcUsdMarket = await reader.getMarket(dataStore.address, btcUsdMarketAddress);

  const btcUsdSingleTokenMarketAddress = getMarketTokenAddress(
    wbtc.address,
    usdc.address,
    usdc.address,
    DEFAULT_MARKET_TYPE,
    marketFactory.address,
    roleStore.address,
    dataStore.address
  );
  const btcUsdSingleTokenMarket = await reader.getMarket(dataStore.address, btcUsdSingleTokenMarketAddress);

  const solUsdMarketAddress = getMarketTokenAddress(
    sol.address,
    wnt.address,
    usdc.address,
    DEFAULT_MARKET_TYPE,
    marketFactory.address,
    roleStore.address,
    dataStore.address
  );
  const solUsdMarket = await reader.getMarket(dataStore.address, solUsdMarketAddress);

  const ethUsdGlvAddress = getGlvAddress(
    wnt.address,
    usdc.address,
    ethers.constants.HashZero,
    "GMX Liquidity Vault [WETH-USDC]",
    "GLV [WETH-USDC]",
    glvFactory.address,
    roleStore.address,
    dataStore.address
  );

  return {
    accountList,
    getContract: async (contractName) => {
      return await hre.ethers.getContract(contractName);
    },
    accounts: {
      wallet,
      user0,
      user1,
      user2,
      user3,
      user4,
      user5,
      user6,
      user7,
      user8,
      signer0,
      signer1,
      signer2,
      signer3,
      signer4,
      signer5,
      signer6,
      signer7,
      signer8,
      signer9,
      signers: [signer0, signer1, signer2, signer3, signer4, signer5, signer6],
    },
    contracts: {
      config,
      configSyncer,
      mockRiskOracle,
      timelock,
      reader,
      roleStore,
      dataStore,
      depositVault,
      eventEmitter,
      withdrawalVault,
      shiftVault,
      oracleStore,
      orderVault,
      marketFactory,
      depositHandler,
      depositUtils,
      executeDepositUtils,
      withdrawalHandler,
      shiftHandler,
      orderHandler,
      baseOrderUtils,
      orderUtils,
      liquidationHandler,
      adlHandler,
      router,
      exchangeRouter,
      gelatoRelayRouter,
      subaccountGelatoRelayRouter,
      subaccountRouter,
      oracle,
      gmOracleProvider,
      chainlinkPriceFeedProvider,
      chainlinkDataStreamProvider,
      marketUtils,
      marketStoreUtils,
      depositStoreUtils,
      withdrawalStoreUtils,
      shiftStoreUtils,
      positionStoreUtils,
      orderStoreUtils,
      decreasePositionUtils,
      increaseOrderUtils,
      increasePositionUtils,
      positionUtils,
      swapUtils,
      referralStorage,
      usdcPriceFeed,
      wethPriceFeed,
      gmxPriceFeed,
      wnt,
      gmx,
      wbtc,
      sol,
      usdc,
      usdt,
      ethUsdMarket,
      ethUsdtMarket,
      ethUsdSpotOnlyMarket,
      ethUsdSingleTokenMarket,
      ethUsdSingleTokenMarket2,
      btcUsdMarket,
      btcUsdSingleTokenMarket,
      solUsdMarket,
      feeHandler,
      glvFactory,
      glvHandler,
      glvVault,
      glvRouter,
      ethUsdGlvAddress,
      glvDepositStoreUtils,
      glvWithdrawalStoreUtils,
      glvShiftStoreUtils,
      glvStoreUtils,
      glvReader,
      mockVaultV1,
    },
    props: { oracleSalt, signerIndexes: [0, 1, 2, 3, 4, 5, 6], executionFee: "1000000000000000" },
  };
}
