import { ethers } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getSyntheticTokenAddress } from "../utils/token";
import { decimalToFloat, percentageToFloat } from "../utils/math";
import { BigNumberish } from "ethers";
import { TOKEN_ORACLE_TYPES } from "../utils/oracle";

import { OracleProvider } from "./types";

type OracleRealPriceFeed = {
  address: string;
  decimals: number;
  heartbeatDuration: number;
  stablePrice?: BigNumberish;
  deploy?: never;
  initPrice?: never;
};

type OracleTestPriceFeed = {
  address?: never;
  decimals: number;
  heartbeatDuration: number;
  stablePrice?: BigNumberish;
  deploy: true;
  initPrice: string;
};

type OraclePriceFeed = OracleRealPriceFeed | OracleTestPriceFeed;

type BaseTokenConfig = {
  decimals: number;
  transferGasLimit?: number;
  oracleProvider?: OracleProvider;
  oracleTimestampAdjustment?: number;
  dataStreamFeedId?: string;
  dataStreamFeedDecimals?: number;
  dataStreamSpreadReductionFactor?: BigNumberish;
  priceFeed?: OraclePriceFeed;
};

// synthetic token without corresponding token
// address will be generated in runtime in hardhat.config.ts
// should not be deployed
// should not be wrappedNative
type SyntheticTokenConfig = BaseTokenConfig & {
  address?: never;
  synthetic: true;
  wrappedNative?: never;
  deploy?: never;
  oracleType?: string;
};

type RealTokenConfig = BaseTokenConfig & {
  address: string;
  synthetic?: never;
  wrappedNative?: true;
  deploy?: never;
  buybackMaxPriceImpactFactor?: BigNumberish;
};

// test token to deploy in local and test networks
// automatically deployed in localhost and hardhat networks
// `deploy` should be set to `true` to deploy on live networks
export type TestTokenConfig = BaseTokenConfig & {
  address?: never;
  deploy: true;
  wrappedNative?: boolean;
  synthetic?: never;
};

export type TokenConfig = SyntheticTokenConfig | RealTokenConfig | TestTokenConfig;
export type TokensConfig = { [tokenSymbol: string]: TokenConfig };

const LOW_BUYBACK_IMPACT = percentageToFloat("0.20%");
const MID_BUYBACK_IMPACT = percentageToFloat("0.40%");

const config: {
  [network: string]: TokensConfig;
} = {
  arbitrum: {
    APE: {
      address: "0x7f9FBf9bDd3F4105C478b996B648FE6e828a1e98",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000316d702a8e25e6b4ef4d449e3413dff067ee77dd366f0550251c07daf05ee",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x221912ce795669f628c51c69b7d0873eDA9C03bB",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    BTC: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x00039d9e45394f473ab1f050a1b963e6b05351e52d71e507509ada0c95ed75b8",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x6ce185860a4963106506C203335A2910413708e9",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      dataStreamSpreadReductionFactor: percentageToFloat("100%"),
    },
    "WBTC.e": {
      address: "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f",
      decimals: 8,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00039d9e45394f473ab1f050a1b963e6b05351e52d71e507509ada0c95ed75b8",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        // use the BTC price feed since the oracle would report the BTC price as well
        address: "0x6ce185860a4963106506C203335A2910413708e9",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
      dataStreamSpreadReductionFactor: percentageToFloat("100%"),
    },
    tBTC: {
      address: "0x6c84a8f1c29108f47a79964b5fe888d4f4d0de40",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00039d9e45394f473ab1f050a1b963e6b05351e52d71e507509ada0c95ed75b8",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        // use the BTC price feed since the oracle would report the BTC price as well
        address: "0x6ce185860a4963106506C203335A2910413708e9",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    WETH: {
      address: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
      decimals: 18,
      wrappedNative: true,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
      dataStreamSpreadReductionFactor: percentageToFloat("100%"),
    },
    wstETH: {
      address: "0x5979D7b546E38E414F7E9822514be443A4800529",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003db069f3010212c213d1a0d4bc2cce328471aca2bff86bbfc0226fd060e90", // note that this must be for wstETH/USD and not wstETH/ETH
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    BNB: {
      address: "0xa9004A5421372E1D83fB1f85b0fc986c912f91f3",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000335fd3f3ffa06cfd9297b97367f77145d7a5f132e84c736cc471dd98621fe",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x6970460aabF80C5BE983C6b74e5D06dEDCA95D4A",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    XRP: {
      synthetic: true,
      decimals: 6,
      dataStreamFeedId: "0x0003c16c6aed42294f5cb4741f6e59ba2d728f0eae2eb9e6d3f555808c59fc45",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    DOGE: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x000356ca64d3b32135e17dc0dc721a645bf50d0303be8ceb2cdca0a50bab8fdc",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x9A7FB1b3950837a8D9b40517626E11D4127C098C",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    EIGEN: {
      address: "0x606c3e5075e5555e79aa15f1e9facb776f96c248",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00032f3b5e95e313e484cac35ccff3904358100010b5f3ac2cf8e263c2ccc873",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    SHIB: {
      synthetic: true,
      decimals: 18,
      dataStreamFeedId: "0x0003591ce9a9d662c43124ca14fd6f8603c9ab856ee45358189a2ce6904b5a3c",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    SOL: {
      address: "0x2bcC6D6CdBbDC0a4071e48bb3B969b06B3330c07",
      decimals: 9,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003b778d3f6b2ac4991302b89cb313f99a42467d6c9c5f96f57c29c0d2bc24f",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x24ceA4b8ce57cdA5058b924B9B9987992450590c",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    STX: {
      synthetic: true,
      decimals: 6,
      dataStreamFeedId: "0x0003364401fcbe3153adf158017cd18a2833655db5cc5eb8fad2c16cb0ec82f4",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    SATS: {
      synthetic: true,
      decimals: 6,
      dataStreamFeedId: "0x000308eb21e48b6673ee81b8baf25b34468597824a7897f3392c499c6a080606",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    LTC: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x00033a4f1021830ac0e7b7a03f70ed56fecb0ac2a10c8ea5328c240c847b71f3",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    UNI: {
      address: "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000367a3674cdd7cc83dbbd7d19f3768b9d1329586e82e32a1bf388fc5ffd0eb",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    LINK: {
      address: "0xf97f4df75117a78c1A5a0DBb814Af92458539FB4",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00036d7a1251e3f67d6658466b5e9e7fe8418af7feac9567ff322bff95cc2401",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x86E53CF1B870786351Da77A57575e79CB55812CB",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    ARB: {
      address: "0x912CE59144191C1204E64559FE8253a0e49E6548",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00030ab7d02fbba9c6304f98824524407b1f494741174320cfd17a2c22eec1de",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    ATOM: {
      synthetic: true,
      decimals: 6,
      dataStreamFeedId: "0x0003c93d9477344d0f2516c4605008399e6750d492a60ab85a9ecb2e441e87b3",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xCDA67618e51762235eacA373894F0C79256768fa",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    NEAR: {
      synthetic: true,
      decimals: 24,
      dataStreamFeedId: "0x00036e9386eda6b177c6f7e9d493e60ae9ebaeb732a271b880b4d6a131d6b3f5",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xBF5C3fB2633e924598A46B9D07a174a9DBcF57C0",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    POL: {
      synthetic: true,
      decimals: 18,
      dataStreamFeedId: "0x0003a845b2e108468ec6f42a5c88609082e9ec86fe9d2529c9e5f8af440079f8",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // there seems to be a Chainlink on-chain feed, but it is indicated as
      // a High Market Risk feed so has not been added
    },
    SUI: {
      synthetic: true,
      decimals: 9,
      dataStreamFeedId: "0x000348ce31679e9ce1f80ec929f1d7c86499569d67f1cea80a90d6e5e3c127a7",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    SEI: {
      synthetic: true,
      decimals: 18,
      dataStreamFeedId: "0x0003487e79423ea3c34f4edfc8bb112b0d0fbe054906644912b04bd5a3c6243b",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    APT: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x0003c6405661f306b96c352b0ed428e190b76e1f14641fb5b68652f9ca8d9af5",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    TIA: {
      synthetic: true,
      decimals: 6,
      dataStreamFeedId: "0x00034a6c27424c06b3441b8714c9b11bb4e7dc38548a525cee36ee232ffea013",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x4096b9bfB4c34497B7a3939D4f629cf65EBf5634",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    TRX: {
      synthetic: true,
      decimals: 6,
      dataStreamFeedId: "0x000310286f692877b46996d4c597fea8270d1922cc4ddf486165a192ed70111a",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    TAO: {
      synthetic: true,
      decimals: 9,
      dataStreamFeedId: "0x0003194c47ff85edd20e877289d23f0cac00f425ea9b558b5b015df87e162cb2",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x6aCcBB82aF71B8a576B4C05D4aF92A83A035B991",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    BONK: {
      synthetic: true,
      decimals: 5,
      dataStreamFeedId: "0x00033bba2b72b1d4220f0519eacd8a4d01e12aabb3eedb2c442db6e3d8994d99",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    WLD: {
      synthetic: true,
      decimals: 18,
      dataStreamFeedId: "0x000365f820b0633946b78232bb91a97cf48100c426518e732465c3a050edb9f1",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    TON: {
      synthetic: true,
      decimals: 9,
      dataStreamFeedId: "0x0003f9ec12942ff27b28ab151905c8fc1cb280518d8bbd3885d410eaa50ddc56",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    PENDLE: {
      address: "0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003bed8b27802e5a77d457035227acd3ac5dc9ce941a3ba0eef310bfa9ba89f",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x66853E19d73c0F9301fe099c324A1E9726953433",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    BOME: {
      synthetic: true,
      decimals: 6, // https://solscan.io/token/ukHH6c7mMyiWCf1b9pnWe25TSpkDDt3H5pQZgZ74J82
      dataStreamFeedId: "0x0003bf78b6030628c512b439169066c7db546a4dea5a978b54dde6350b6764ad",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    MEME: {
      synthetic: true,
      decimals: 18, // https://etherscan.io/token/0xb131f4a55907b10d1f0a50d8ab8fa09ec342cd74#readContract
      dataStreamFeedId: "0x0003f43194e41b8cb88e552eb5399be7d1f5d0c36b366eaa09e73fa9baf7bfd3",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    FLOKI: {
      synthetic: true,
      decimals: 9, // https://etherscan.io/token/0xcf0c122c6b73ff809c693db761e7baebe62b6a2e#readContract
      dataStreamFeedId: "0x000346d0958f98acea3450ce438790e5618fdfe50f8e36a80cabc622fe3e25ed",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    MEW: {
      synthetic: true,
      decimals: 5, // https://solscan.io/token/MEW1gQWJ3nEXg2qgERiKu7FAFj79PHvQVREQUzScPP5
      dataStreamFeedId: "0x0003d0d97dfc557e862e944a4581956aff826e59ca3b57b19e22744055c11539",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    ADA: {
      synthetic: true,
      decimals: 6,
      dataStreamFeedId: "0x00038580225b924c69e28ea101d4723d90c1b44ab83548a995c3d86ad9e92eb0",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xD9f615A9b820225edbA2d821c4A696a0924051c6",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    XLM: {
      synthetic: true,
      decimals: 7,
      dataStreamFeedId: "0x000358cb12b1f5bbeca8b5b4666025a40b15520af1f82516ee2fb9a335055e9a",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    BCH: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x00031dcbdf6f280392039ea6381b85a23bc0b90a40b676c4ec0b669dd8f0f38e",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      dataStreamSpreadReductionFactor: percentageToFloat("1%"),
      // Chainlink on-chain feed not available
    },
    DOT: {
      synthetic: true,
      decimals: 10,
      dataStreamFeedId: "0x0003fdcc3acfa677b4f82bd4b8a6efaca91adcd9ae028e9f8cb65d1a85122b23",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xa6bC5bAF2000424e90434bA7104ee399dEe80DEc",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    ICP: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x000379340f2deb2576ae338fc1043d63054326bc86862f7d8fc1519434712862",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    RENDER: {
      synthetic: true,
      decimals: 18, // https://etherscan.io/token/0x6de037ef9ad2725eb40118bb1702ebb27e4aeb24#readProxyContract
      dataStreamFeedId: "0x00034e3ab3a1c0809fe3f56ffe755155ace8564512cbc3884e9463dba081c02a",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    FIL: {
      synthetic: true,
      decimals: 18, // https://docs.filecoin.io/basics/assets/the-fil-token
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00036d46e681d182bbf68be46c5e5670c5b94329dba90ce5c52bf76c42bee68d",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    INJ: {
      synthetic: true,
      decimals: 18, // https://docs.injective.network/getting-started/token-standards/inj-coin
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000344d7a7d81f051ee273a63f94f8bef7d44ca89aa03e0c5bf4d085df19adb6",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    DYDX: {
      synthetic: true,
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000348d8c6f4ff9e51a1baa88354d97749b3c1ffcdbfb9cf962b1882dba8cafb",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    TRUMP: {
      synthetic: true,
      decimals: 6, // https://solscan.io/token/6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003eae10f93ab9aeb6d1aa757b07938eed75a0d09cbe15df8521dc3d6bfb633",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x373510BDa1ab7e873c731968f4D81B685f520E4B", // indicated as New Token Feed
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    MELANIA: {
      synthetic: true,
      decimals: 6, // https://solscan.io/token/FUAfBo2jgks6gB4Z4LfZkqSZgzNucisEHqnNebaRxM1P
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000334e8e9fd64bd9068f44e7779f9b6437c86b1c148549d026c00b3a642caeb",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xE2CB592D636c500a6e469628054F09d58e4d91BB", // no category ranking
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    ENA: {
      synthetic: true,
      decimals: 18, // https://etherscan.io/token/0x57e114b691db790c35207b2e685d4a43181e6061#readContract
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00033e05a40dd8c25ffa1b88a35234845c067635f7ddf5edde701f859f8894c1",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x9eE96caa9972c801058CAA8E23419fc6516FbF7e", // no category ranking
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
    FARTCOIN: {
      synthetic: true,
      decimals: 6, // https://solscan.io/token/9BB6NFEcjBCtnNLFko2FqVQBq8HHM13kCyYcdQbgpump
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00030e00d1ce95c5749cb258e583b96d072ca103d4552cda2593c96fca954c16",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    AI16Z: {
      synthetic: true,
      decimals: 9, // https://solscan.io/token/HeLp6NuQkmYB4pYWo2zYs22mESHXPQYzXbB8n4V98jwC
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003aa72a9b718ab413209e03abb04233846991294336169fc6a7a03081adb70",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    AAVE: {
      address: "0xba5ddd1f9d7f570dc94a51479a000e3bce967196",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003481a2f7fe21c01d427f39035541d2b7a53db9c76234dc36082e6ad6db7f5",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    AVAX: {
      address: "0x565609fAF65B92F7be02468acF86f8979423e514",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003b1cb55b8a00a18111ff745b56d70f04c2d41e03fc7fd8d3d9b09f142aad9",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x8bf61728eeDCE2F32c456454d87B5d6eD6150208",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    OP: {
      address: "0xaC800FD6159c2a2CB8fC31EF74621eB430287a5A",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003ba5e477371c9cd5446281354a91e66c233dd50e26efe6abbfdc310b92dab",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x205aaD468a11fd5D34fA7211bC6Bad5b3deB9b98",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    ORDI: {
      synthetic: true,
      decimals: 18,
      dataStreamFeedId: "0x0003db12da014dbc5a928b9e7a8c6bc1fbab0c60d332ce26c644cc7477b6fe7f",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    GMX: {
      address: "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003169a4ebb9178e5ec6281913d1a8a4f676f414c94b60a4cb2e432f9081c60",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xDB98056FecFff59D032aB628337A4887110df3dB",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    PEPE: {
      address: "0x25d887Ce7a35172C62FeBFD67a1856F20FaEbB00",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00032fd010bde9fb3b8b53c126bd8a0bd2c3b3fbaceb33605cd46a7e461e4da8",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x02DEd5a7EDDA750E3Eb240b54437a54d57b74dBE",
        decimals: 18,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    WIF: {
      address: "0xA1b91fe9FD52141Ff8cac388Ce3F10BFDc1dE79d",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003d5a1e39f957e312e307d535c8c28315172442ae0c39d9488e908c3762c85",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xF7Ee427318d2Bd0EEd3c63382D0d52Ad8A68f90D",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    ANIME: {
      address: "0x37a645648df29205c6261289983fb04ecd70b4b3",
      decimals: 18, // https://arbiscan.io/address/0x37a645648df29205c6261289983fb04ecd70b4b3#readContract
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003f41975760eb180ad9f92ea069bbee557c655d6606884a5d810f42b22ee08",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      // Chainlink on-chain feed not available
    },
    USDC: {
      address: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd992",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
      dataStreamSpreadReductionFactor: percentageToFloat("100%"),
    },
    "USDC.e": {
      address: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd992",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    USDT: {
      address: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003a910a43485e0685ff5d6d366541f5c21150f0634c5b14254392d1a1c06db",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    DAI: {
      address: "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003571a596aab1cafe1a883795dab90cd8cca48e25f53ab3665aa67d008f386",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    USDe: {
      address: "0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000379477abdca006db92300211242ba44479369a15be0ad8d59cabe00e63074",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x88AC7Bca36567525A866138F03a6F6844868E0Bc",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
  },
  avalanche: {
    "BTC.b": {
      address: "0x152b9d0FdC40C096757F570A51E494bd4b943E50",
      decimals: 8,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00039d9e45394f473ab1f050a1b963e6b05351e52d71e507509ada0c95ed75b8",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x2779D32d5166BAaa2B2b658333bA7e6Ec0C65743",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    "WETH.e": {
      address: "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x976B3D034E162d8bD72D6b9C989d545b839003b0",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    XRP: {
      synthetic: true,
      decimals: 6,
      dataStreamFeedId: "0x0003c16c6aed42294f5cb4741f6e59ba2d728f0eae2eb9e6d3f555808c59fc45",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    DOGE: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x000356ca64d3b32135e17dc0dc721a645bf50d0303be8ceb2cdca0a50bab8fdc",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    SOL: {
      address: "0xFE6B19286885a4F7F55AdAD09C3Cd1f906D2478F",
      decimals: 9,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003b778d3f6b2ac4991302b89cb313f99a42467d6c9c5f96f57c29c0d2bc24f",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    LTC: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x00033a4f1021830ac0e7b7a03f70ed56fecb0ac2a10c8ea5328c240c847b71f3",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
    },
    TRUMP: {
      synthetic: true,
      decimals: 6, // https://solscan.io/token/6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003eae10f93ab9aeb6d1aa757b07938eed75a0d09cbe15df8521dc3d6bfb633",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x0000000000000000000000000000000000000000",
        decimals: 0,
        heartbeatDuration: 0,
      },
    },
    MELANIA: {
      synthetic: true,
      decimals: 6, // https://solscan.io/token/FUAfBo2jgks6gB4Z4LfZkqSZgzNucisEHqnNebaRxM1P
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000334e8e9fd64bd9068f44e7779f9b6437c86b1c148549d026c00b3a642caeb",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x0000000000000000000000000000000000000000",
        decimals: 0,
        heartbeatDuration: 0,
      },
    },
    WAVAX: {
      address: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
      decimals: 18,
      wrappedNative: true,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003b1cb55b8a00a18111ff745b56d70f04c2d41e03fc7fd8d3d9b09f142aad9",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x0A77230d17318075983913bC2145DB16C7366156",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
      buybackMaxPriceImpactFactor: MID_BUYBACK_IMPACT,
    },
    USDC: {
      address: "0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd992",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0xF096872672F44d6EBA71458D74fe67F9a77a23B9",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    "USDC.e": {
      address: "0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd992",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0xF096872672F44d6EBA71458D74fe67F9a77a23B9",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    USDT: {
      address: "0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003a910a43485e0685ff5d6d366541f5c21150f0634c5b14254392d1a1c06db",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xEBE676ee90Fe1112671f19b6B7459bC678B67e8a",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    "USDT.e": {
      address: "0xc7198437980c041c805A1EDcbA50c1Ce5db95118",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003a910a43485e0685ff5d6d366541f5c21150f0634c5b14254392d1a1c06db",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0xEBE676ee90Fe1112671f19b6B7459bC678B67e8a",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    "DAI.e": {
      address: "0xd586E7F844cEa2F87f50152665BCbc2C279D8d70",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003571a596aab1cafe1a883795dab90cd8cca48e25f53ab3665aa67d008f386",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x51D7180edA2260cc4F6e4EebB82FEF5c3c2B8300",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
      buybackMaxPriceImpactFactor: LOW_BUYBACK_IMPACT,
    },
    GMX: {
      address: "0x62edc0692BD897D2295872a9FFCac5425011c661",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003169a4ebb9178e5ec6281913d1a8a4f676f414c94b60a4cb2e432f9081c60",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 1,
      priceFeed: {
        address: "0x3F968A21647d7ca81Fb8A5b69c0A452701d5DCe8",
        decimals: 8,
        heartbeatDuration: (24 + 1) * 60 * 60,
      },
    },
  },
  arbitrumSepolia: {
    WETH: {
      address: "0x980b62da83eff3d4576c647993b0c1d7faf17c73", // not verified
      decimals: 18,
      wrappedNative: true,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0001d678deabc04f0494b78138727170ff1cf1daf91fca6954de59e41fa0965c",
      dataStreamFeedDecimals: 18,
    },
    BTC: {
      address: "0xF79cE1Cf38A09D572b021B4C5548b75A14082F12",
      decimals: 8,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0001ef0379c835e64d03082e561403cc14b2779b525d93149b25df0ee3ef9456",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69",
        decimals: 8,
        heartbeatDuration: 3 * 24 * 60 * 60,
        stablePrice: decimalToFloat(44000),
      },
    },
    USDC: {
      address: "0x3321Fd36aEaB0d5CdfD26f4A3A93E2D2aAcCB99f",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0001829d7d4c7c5badcd54d2126e621c51eabf32393ffab969e311b18ed80138",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x0153002d20B96532C639313c2d54c3dA09109309",
        decimals: 8,
        heartbeatDuration: 3 * 24 * 60 * 60,
        stablePrice: decimalToFloat(1),
      },
    },
    GLV_WETH_USDC: {
      address: "0x528A5bac7E746C9A509A1f4F6dF58A03d44279F9",
      decimals: 18,
      transferGasLimit: 200 * 1000,
    },
  },
  arbitrumGoerli: {
    WETH: {
      address: "0xe39Ab88f8A4777030A534146A9Ca3B52bd5D43A3",
      decimals: 18,
      wrappedNative: true,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x4554482d5553442d415242495452554d2d544553544e45540000000000000000",
      dataStreamFeedDecimals: 18,
    },
    BTC: {
      synthetic: true,
      decimals: 8,
      dataStreamFeedId: "0x4254432d5553442d415242495452554d2d544553544e45540000000000000000",
      dataStreamFeedDecimals: 18,
    },
    WBTC: {
      decimals: 8,
      transferGasLimit: 200 * 1000,
      address: "0xCcF73F4Dcbbb573296BFA656b754Fe94BB957d62",
      dataStreamFeedId: "0x4254432d5553442d415242495452554d2d544553544e45540000000000000000",
      dataStreamFeedDecimals: 18,
    },
    USDC: {
      decimals: 6,
      transferGasLimit: 200 * 1000,
      address: "0x04FC936a15352a1b15b3B9c56EA002051e3DB3e5",
      dataStreamFeedId: "0x555344432d5553442d415242495452554d2d544553544e455400000000000000",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x1692Bdd32F31b831caAc1b0c9fAF68613682813b",
        decimals: 8,
        heartbeatDuration: 3 * 24 * 60 * 60,
      },
    },
    SOL: {
      synthetic: true,
      decimals: 18,
    },
    USDT: {
      decimals: 6,
      transferGasLimit: 200 * 1000,
      address: "0xBFcBcdCbcc1b765843dCe4DF044B92FE68182a62",
      dataStreamFeedId: "0x12be1859ee43f46bab53750915f20855f54e891f88ddd524f26a72d6f4deed1d",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x0a023a3423D9b27A0BE48c768CCF2dD7877fEf5E",
        decimals: 8,
        heartbeatDuration: 3 * 24 * 60 * 60,
      },
    },
    DAI: {
      decimals: 18,
      transferGasLimit: 200 * 1000,
      address: "0x7b7c6c49fA99b37270077FBFA398748c27046984",
      dataStreamFeedId: "0xbf1febc8c335cb236c1995c1007a928a3f7ae8307a1a20cb31334e6d316c62d1",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        address: "0x103b53E977DA6E4Fa92f76369c8b7e20E7fb7fe1",
        decimals: 8,
        heartbeatDuration: 3 * 24 * 60 * 60,
      },
    },
    TEST: {
      synthetic: true,
      decimals: 18,
    },
    BNB: {
      decimals: 18,
      synthetic: true,
      dataStreamFeedId: "0x26c16f2054b7a1d77ae83a0429dace9f3000ba4dbf1690236e8f575742e98f66",
      dataStreamFeedDecimals: 18,
    },
    DOGE: {
      decimals: 8,
      synthetic: true,
      dataStreamFeedId: "0x4ce52cf28e49f4673198074968aeea280f13b5f897c687eb713bcfc1eeab89ba",
      dataStreamFeedDecimals: 18,
    },
    LINK: {
      decimals: 18,
      synthetic: true,
      dataStreamFeedId: "0x14e044f932bb959cc2aa8dc1ba110c09224e639aae00264c1ffc2a0830904a3c",
      dataStreamFeedDecimals: 18,
    },
    ADA: {
      decimals: 18,
      synthetic: true,
    },
    DOT: {
      decimals: 18,
      synthetic: true,
    },
    MATIC: {
      decimals: 18,
      synthetic: true,
    },
    UNI: {
      decimals: 18,
      synthetic: true,
    },
    TRX: {
      decimals: 18,
      synthetic: true,
    },
  },
  avalancheFuji: {
    WAVAX: {
      address: "0x1D308089a2D1Ced3f1Ce36B1FcaF815b07217be3",
      wrappedNative: true,
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003735a076086936550bd316b18e5e27fc4f280ee5b6530ce68f5aad404c796",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 3,
      dataStreamSpreadReductionFactor: percentageToFloat("100%"),
    },
    TEST: {
      synthetic: true,
      decimals: 18,
      oracleProvider: "gmOracle",
    },
    WBTC: {
      decimals: 8,
      address: "0x3Bd8e00c25B12E6E60fc8B6f1E1E2236102073Ca",
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00037da06d56d083fe599397a4769a042d63aa73dc4ef57709d31e9971a5b439",
      dataStreamFeedDecimals: 18,
    },
    SOL: {
      synthetic: true,
      decimals: 18,
      dataStreamFeedId: "0x0003d338ea2ac3be9e026033b1aa601673c37bab5e13851c59966f9f820754d6",
      dataStreamFeedDecimals: 18,
    },
    USDC: {
      address: "0x3eBDeaA0DB3FfDe96E7a0DBBAFEC961FC50F725F",
      decimals: 6,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x0003dc85e8b01946bf9dfd8b0db860129181eb6105a8c8981d9f28e00b6f60d9",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        // this is USDT price feed, there is no USDC feed on Avalanche Fuji
        address: "0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad",
        decimals: 8,
        heartbeatDuration: 3 * 24 * 60 * 60,
      },
    },
    USDT: {
      decimals: 6,
      address: "0x50df4892Bd13f01E4e1Cd077ff394A8fa1A3fD7c",
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x00032874077216155926e26c159c1c20a572921371d9de605fe9633e48d136f9",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        // this is USDT price feed, there is no USDC feed on Avalanche Fuji
        address: "0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad",
        decimals: 8,
        heartbeatDuration: 3 * 24 * 60 * 60,
      },
    },
    DAI: {
      decimals: 6,
      transferGasLimit: 200 * 1000,
      address: "0x51290cb93bE5062A6497f16D9cd3376Adf54F920",
      dataStreamFeedId: "0x0003649272a19e143a7f4c2d98905b413e98dce81fb09287dcf4c513cba5cc72",
      dataStreamFeedDecimals: 18,
      priceFeed: {
        // this is USDT price feed, there is no USDC feed on Avalanche Fuji
        address: "0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad",
        decimals: 8,
        heartbeatDuration: 3 * 24 * 60 * 60,
      },
    },
    WETH: {
      address: "0x82F0b3695Ed2324e55bbD9A9554cB4192EC3a514",
      decimals: 18,
      transferGasLimit: 200 * 1000,
      dataStreamFeedId: "0x000359843a543ee2fe414dc14c7e7920ef10f4372990b79d6361cdc0dd1ba782",
      dataStreamFeedDecimals: 18,
    },
    BNB: {
      decimals: 18,
      synthetic: true,
      dataStreamFeedId: "0x000387d7c042a9d5c97c15354b531bd01bf6d3a351e190f2394403cf2f79bde9",
      dataStreamFeedDecimals: 18,
    },
    DOGE: {
      decimals: 8,
      synthetic: true,
      dataStreamFeedId: "0x00032057c7f224d0266b4311a81cdc3e38145e36442713350d3300fb12e85c99",
      dataStreamFeedDecimals: 18,
    },
    LINK: {
      decimals: 18,
      synthetic: true,
      dataStreamFeedId: "0x00036fe43f87884450b4c7e093cd5ed99cac6640d8c2000e6afc02c8838d0265",
      dataStreamFeedDecimals: 18,
      oracleTimestampAdjustment: 10,
    },
    ADA: {
      decimals: 18,
      synthetic: true,
      oracleProvider: "gmOracle",
      oracleTimestampAdjustment: 1,
    },
    DOT: {
      decimals: 18,
      synthetic: true,
      oracleProvider: "gmOracle",
    },
    MATIC: {
      decimals: 18,
      synthetic: true,
      dataStreamFeedId: "0x0003fd6ff25e1a28ddd55c85882279987be478a66a75abdf05a468beb5b8b467",
      dataStreamFeedDecimals: 18,
      oracleProvider: "gmOracle",
    },
    UNI: {
      decimals: 18,
      synthetic: true,
      dataStreamFeedId: "0x00032b6edb94b883e95693b8fdae3deeedab2c48dd699cafa43a8d134d344813",
      dataStreamFeedDecimals: 18,
    },
    TRX: {
      decimals: 18,
      synthetic: true,
      oracleProvider: "gmOracle",
    },
  },
  // token addresses are retrieved in runtime for hardhat and localhost networks
  hardhat: {
    WETH: {
      wrappedNative: true,
      decimals: 18,
      transferGasLimit: 200 * 1000,
      deploy: true,
      priceFeed: {
        decimals: 8,
        heartbeatDuration: 24 * 60 * 60,
        deploy: true,
        initPrice: "500000000000",
      },
    },
    GMX: {
      decimals: 18,
      transferGasLimit: 200 * 1000,
      deploy: true,
      priceFeed: {
        decimals: 8,
        heartbeatDuration: 24 * 60 * 60,
        deploy: true,
        initPrice: "10000000000",
      },
    },
    WBTC: {
      decimals: 8,
      transferGasLimit: 200 * 1000,
      deploy: true,
    },
    USDC: {
      decimals: 6,
      transferGasLimit: 200 * 1000,
      deploy: true,
      priceFeed: {
        decimals: 8,
        heartbeatDuration: 24 * 60 * 60,
        deploy: true,
        initPrice: "100000000",
      },
    },
    USDT: {
      decimals: 6,
      transferGasLimit: 200 * 1000,
      deploy: true,
      priceFeed: {
        decimals: 8,
        heartbeatDuration: 24 * 60 * 60,
        deploy: true,
        initPrice: "100000000",
      },
    },
    SOL: {
      synthetic: true,
      decimals: 18,
    },
  },
  localhost: {
    WETH: {
      wrappedNative: true,
      decimals: 18,
      transferGasLimit: 200 * 1000,
      deploy: true,
    },
    GMX: {
      decimals: 18,
      transferGasLimit: 200 * 1000,
      deploy: true,
    },
    WBTC: {
      decimals: 8,
      transferGasLimit: 200 * 1000,
      deploy: true,
    },
    USDC: {
      decimals: 6,
      transferGasLimit: 200 * 1000,
      deploy: true,
    },
    USDT: {
      decimals: 6,
      transferGasLimit: 200 * 1000,
      deploy: true,
    },
    SOL: {
      synthetic: true,
      decimals: 18,
    },
  },
};

export default async function (hre: HardhatRuntimeEnvironment): Promise<TokensConfig> {
  const tokens = config[hre.network.name];

  for (const [tokenSymbol, token] of Object.entries(tokens as TokensConfig)) {
    (token as any).symbol = tokenSymbol;
    if (token.synthetic) {
      (token as any).address = getSyntheticTokenAddress(hre.network.config.chainId, tokenSymbol);
    }
    if (token.address) {
      (token as any).address = ethers.utils.getAddress(token.address);
    }
    if (!hre.network.live) {
      (token as any).deploy = true;
    }

    if (token.oracleType === undefined) {
      token.oracleType = TOKEN_ORACLE_TYPES.DEFAULT;
    }
  }

  return tokens;
}
