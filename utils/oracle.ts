import { bigNumberify, expandDecimals, MAX_UINT8, MAX_UINT32, MAX_UINT64 } from "./math";
import { hashString, hashData } from "./hash";
import * as keys from "./keys";

import BN from "bn.js";
import { OracleProvider } from "../config/types";

export const TOKEN_ORACLE_TYPES: { [key: string]: string } = {
  ONE_PERCENT_PER_MINUTE: hashString("one-percent-per-minute"),
};

TOKEN_ORACLE_TYPES.DEFAULT = TOKEN_ORACLE_TYPES.ONE_PERCENT_PER_MINUTE;

export async function signPrice({
  signer,
  salt,
  minOracleBlockNumber,
  maxOracleBlockNumber,
  oracleTimestamp,
  blockHash,
  token,
  tokenOracleType,
  precision,
  minPrice,
  maxPrice,
}) {
  if (bigNumberify(minOracleBlockNumber).gt(MAX_UINT64)) {
    throw new Error(`minOracleBlockNumber exceeds max value: ${minOracleBlockNumber.toString()}`);
  }

  if (bigNumberify(maxOracleBlockNumber).gt(MAX_UINT64)) {
    throw new Error(`maxOracleBlockNumber exceeds max value: ${maxOracleBlockNumber.toString()}`);
  }

  if (bigNumberify(oracleTimestamp).gt(MAX_UINT64)) {
    throw new Error(`oracleTimestamp exceeds max value: ${oracleTimestamp.toString()}`);
  }

  if (bigNumberify(precision).gt(MAX_UINT8)) {
    throw new Error(`precision exceeds max value: ${precision.toString()}`);
  }

  if (bigNumberify(minPrice).gt(MAX_UINT32)) {
    throw new Error(`minPrice exceeds max value: ${minPrice.toString()}`);
  }

  if (bigNumberify(maxPrice).gt(MAX_UINT32)) {
    throw new Error(`maxPrice exceeds max value: ${maxPrice.toString()}`);
  }

  const expandedPrecision = expandDecimals(1, precision);
  const hash = hashData(
    ["bytes32", "uint256", "uint256", "uint256", "bytes32", "address", "bytes32", "uint256", "uint256", "uint256"],
    [
      salt,
      minOracleBlockNumber,
      maxOracleBlockNumber,
      oracleTimestamp,
      blockHash,
      token,
      tokenOracleType,
      expandedPrecision,
      minPrice,
      maxPrice,
    ]
  );

  return await signer.signMessage(ethers.utils.arrayify(hash));
}

export async function signPrices({
  signers,
  salt,
  minOracleBlockNumber,
  maxOracleBlockNumber,
  oracleTimestamp,
  blockHash,
  token,
  tokenOracleType,
  precision,
  minPrices,
  maxPrices,
}) {
  const signatures = [];
  for (let i = 0; i < signers.length; i++) {
    const signature = await signPrice({
      signer: signers[i],
      salt,
      minOracleBlockNumber,
      maxOracleBlockNumber,
      oracleTimestamp,
      blockHash,
      token,
      tokenOracleType,
      precision,
      minPrice: minPrices[i],
      maxPrice: maxPrices[i],
    });
    signatures.push(signature);
  }
  return signatures;
}

export function getSignerInfo(signerIndexes) {
  const signerIndexLength = 16;
  let signerInfo = new BN(signerIndexes.length);
  for (let i = 0; i < signerIndexes.length; i++) {
    const signerIndex = new BN(signerIndexes[i]);
    if (signerIndex.gt(new BN(MAX_UINT8))) {
      throw new Error(`Max signer index exceeded: ${signerIndex.toString()}`);
    }
    signerInfo = signerInfo.or(signerIndex.shln((i + 1) * signerIndexLength));
  }
  return signerInfo.toString();
}

function getCompactedValues({ values, compactedValueBitLength, maxValue }) {
  const compactedValuesPerSlot = 256 / compactedValueBitLength;
  const compactedValues = [];
  let shouldExit = false;

  for (let i = 0; i < Math.floor((values.length - 1) / compactedValuesPerSlot) + 1; i++) {
    let valueBits = new BN("0");
    for (let j = 0; j < compactedValuesPerSlot; j++) {
      const index = i * compactedValuesPerSlot + j;
      if (index >= values.length) {
        shouldExit = true;
        break;
      }

      const value = new BN(values[index].toString());

      if (value.gt(new BN(maxValue))) {
        throw new Error(`Max value exceeded: ${value.toString()}`);
      }

      valueBits = valueBits.or(value.shln(j * compactedValueBitLength));
    }

    compactedValues.push(valueBits.toString());

    if (shouldExit) {
      break;
    }
  }

  return compactedValues;
}

export function getCompactedPrices(prices) {
  return getCompactedValues({
    values: prices,
    compactedValueBitLength: 32,
    maxValue: MAX_UINT32,
  });
}

export function getCompactedPriceIndexes(priceIndexes) {
  return getCompactedValues({
    values: priceIndexes,
    compactedValueBitLength: 8,
    maxValue: MAX_UINT8,
  });
}

export function getCompactedDecimals(decimals) {
  return getCompactedValues({
    values: decimals,
    compactedValueBitLength: 8,
    maxValue: MAX_UINT8,
  });
}

export function getCompactedOracleBlockNumbers(blockNumbers) {
  return getCompactedValues({
    values: blockNumbers,
    compactedValueBitLength: 64,
    maxValue: MAX_UINT64,
  });
}

export function getCompactedOracleTimestamps(timestamps) {
  return getCompactedValues({
    values: timestamps,
    compactedValueBitLength: 64,
    maxValue: MAX_UINT64,
  });
}

export async function getOracleParamsForSimulation({ tokens, minPrices, maxPrices, precisions, oracleTimestamps }) {
  if (tokens.length !== minPrices.length) {
    throw new Error(`Invalid input, tokens.length != minPrices.length ${tokens}, ${minPrices}`);
  }

  if (tokens.length !== maxPrices.length) {
    throw new Error(`Invalid input, tokens.length != maxPrices.length ${tokens}, ${maxPrices}`);
  }

  const currentTimestamp = (await ethers.provider.getBlock("latest")).timestamp + 2;
  let minTimestamp = currentTimestamp;
  let maxTimestamp = currentTimestamp;
  for (const timestamp of oracleTimestamps) {
    if (timestamp < minTimestamp) {
      minTimestamp = timestamp;
    }
    if (timestamp > maxTimestamp) {
      maxTimestamp = timestamp;
    }
  }

  const primaryTokens = [];
  const primaryPrices = [];

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    const precisionMultiplier = expandDecimals(1, precisions[i]);
    const minPrice = minPrices[i].mul(precisionMultiplier);
    const maxPrice = maxPrices[i].mul(precisionMultiplier);
    primaryTokens.push(token);
    primaryPrices.push({
      min: minPrice,
      max: maxPrice,
    });
  }

  return {
    primaryTokens,
    primaryPrices,
    minTimestamp,
    maxTimestamp,
  };
}

export async function getOracleParams({
  oracleSalt,
  minOracleBlockNumbers,
  maxOracleBlockNumbers,
  oracleTimestamps,
  blockHashes,
  signerIndexes,
  tokens,
  tokenOracleTypes,
  precisions,
  minPrices,
  maxPrices,
  signers,
  dataStreamTokens,
  dataStreamData,
  priceFeedTokens,
}) {
  const signerInfo = getSignerInfo(signerIndexes);

  const dataStore = await hre.ethers.getContract("DataStore");
  const gmOracleProvider = await hre.ethers.getContract("GmOracleProvider");
  const chainlinkPriceFeedProvider = await hre.ethers.getContract("ChainlinkPriceFeedProvider");
  const chainlinkDataStreamFeedProvider = await hre.ethers.getContract("ChainlinkDataStreamProvider");

  const params = {
    tokens: [],
    providers: [],
    data: [],
  };

  for (let i = 0; i < tokens.length; i++) {
    const minOracleBlockNumber = minOracleBlockNumbers[i];
    const maxOracleBlockNumber = maxOracleBlockNumbers[i];
    const oracleTimestamp = oracleTimestamps[i];
    const blockHash = blockHashes[i];
    const token = tokens[i];
    const tokenOracleType = tokenOracleTypes[i];
    const precision = precisions[i];

    const minPrice = minPrices[i];
    const maxPrice = maxPrices[i];

    const signatures = [];
    const signedMinPrices = [];
    const signedMaxPrices = [];

    for (let j = 0; j < signers.length; j++) {
      const signature = await signPrice({
        signer: signers[j],
        salt: oracleSalt,
        minOracleBlockNumber,
        maxOracleBlockNumber,
        oracleTimestamp,
        blockHash,
        token,
        tokenOracleType,
        precision,
        minPrice,
        maxPrice,
      });

      signedMinPrices.push(minPrice);
      signedMaxPrices.push(maxPrice);
      signatures.push(signature);
    }

    const data = ethers.utils.defaultAbiCoder.encode(
      ["tuple(address, uint256, uint256, uint256, uint256, uint256, bytes32, uint256[], uint256[], bytes[])"],
      [
        [
          token,
          signerInfo,
          precision,
          minOracleBlockNumber,
          maxOracleBlockNumber,
          oracleTimestamp,
          blockHash,
          signedMinPrices,
          signedMaxPrices,
          signatures,
        ],
      ]
    );

    params.tokens.push(token);
    params.providers.push(gmOracleProvider.address);
    params.data.push(data);
  }

  for (let i = 0; i < priceFeedTokens.length; i++) {
    const token = priceFeedTokens[i];
    await dataStore.setAddress(keys.oracleProviderForTokenKey(token), chainlinkPriceFeedProvider.address);
    params.tokens.push(token);
    params.providers.push(chainlinkPriceFeedProvider.address);
    params.data.push("0x");
  }

  for (let i = 0; i < dataStreamTokens.length; i++) {
    const token = dataStreamTokens[i];
    await dataStore.setAddress(keys.oracleProviderForTokenKey(token), chainlinkDataStreamFeedProvider.address);
    params.tokens.push(token);
    params.providers.push(chainlinkDataStreamFeedProvider.address);
    params.data.push(dataStreamData[i]);
  }

  return params;
}

const DEFAULT_ORACLE_PROVIDER: OracleProvider = "chainlinkDataStream";

export async function getOracleProviderAddress(oracleProviderKey: OracleProvider) {
  if (!oracleProviderKey) {
    oracleProviderKey = DEFAULT_ORACLE_PROVIDER;
  }

  const oracleProviderMap = await getOracleProviderMap();
  if (!oracleProviderMap[oracleProviderKey]) {
    throw Error(`Unknown oracle provider ${oracleProviderKey}`);
  }
  return oracleProviderMap[oracleProviderKey];
}

export async function getOracleProviderKey(oracleProviderAddress: string) {
  const oracleProviderMap = await getOracleProviderMap();
  for (const [key, address] of Object.entries(oracleProviderMap)) {
    if (address === oracleProviderAddress) {
      return key;
    }
  }
}

let _oracleProviderMap: Record<string, string>;
async function getOracleProviderMap() {
  if (!_oracleProviderMap) {
    const chainlinkPriceFeedProvider = await hre.ethers.getContract("ChainlinkPriceFeedProvider");
    const chainlinkDataStreamProvider = await hre.ethers.getContract("ChainlinkDataStreamProvider");
    const gmOracleProvider = await hre.ethers.getContract("GmOracleProvider");
    _oracleProviderMap = {
      chainlinkPriceFeed: chainlinkPriceFeedProvider.address,
      chainlinkDataStream: chainlinkDataStreamProvider.address,
      gmOracle: gmOracleProvider.address,
    };
  }

  return _oracleProviderMap;
}

export function encodeDataStreamData(data) {
  const { feedId, validFromTimestamp, observationsTimestamp, nativeFee, linkFee, expiresAt, price, bid, ask } = data;

  return ethers.utils.defaultAbiCoder.encode(
    ["bytes32", "uint32", "uint32", "uint192", "uint192", "uint32", "int192", "int192", "int192"],
    [feedId, validFromTimestamp, observationsTimestamp, nativeFee, linkFee, expiresAt, price, bid, ask]
  );
}
