import { ethers } from "ethers";
const { getAddress, keccak256, toUtf8Bytes } = ethers.utils;

export function encodeData(dataTypes, dataValues) {
  const bytes = ethers.utils.defaultAbiCoder.encode(dataTypes, dataValues);
  return ethers.utils.hexlify(bytes);
}

export function decodeData(dataTypes, data) {
  return ethers.utils.defaultAbiCoder.decode(dataTypes, data);
}

export function hashData(dataTypes, dataValues) {
  const bytes = ethers.utils.defaultAbiCoder.encode(dataTypes, dataValues);
  const hash = ethers.utils.keccak256(ethers.utils.arrayify(bytes));

  return hash;
}

export function hashString(string) {
  return hashData(["string"], [string]);
}

export function keccakString(string) {
  return keccak256(toUtf8Bytes(string));
}

export function getAddressFromHash(hash: string) {
  // Extract the last 20 bytes of the hash to construct the address
  return getAddress("0x" + hash.slice(-40));
}
