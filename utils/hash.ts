import { ethers } from "ethers";
const { keccak256, toUtf8Bytes } = ethers.utils;

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
