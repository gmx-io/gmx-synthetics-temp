import { expect } from "chai";
import { contractAt } from "./deploy";
import { hashData } from "./hash";

export async function getBalanceOf(tokenAddress: string, account: string) {
  const token = await contractAt("MarketToken", tokenAddress);
  return await token.balanceOf(account);
}

export async function getSupplyOf(tokenAddress: string) {
  const token = await contractAt("MarketToken", tokenAddress);
  return await token.totalSupply();
}

export function getSyntheticTokenAddress(chainId: number, tokenSymbol: string) {
  return "0x" + hashData(["uint256", "string"], [chainId, tokenSymbol]).substring(26);
}

export async function expectTokenBalanceIncrease(params) {
  const { token, account, sendTxn, increaseAmount } = params;
  const initialBalance = await token.balanceOf(account.address);
  await sendTxn();
  const nextBalance = await token.balanceOf(account.address);
  expect(initialBalance.add(increaseAmount)).eq(nextBalance);
}
