import { bigNumberify } from "./math";
import { BigNumber } from "ethers";

export async function performMulticall({ multicallReadParams }) {
  const multicall = await hre.ethers.getContract("Multicall3");
  const cleanParams = [];
  for (const item of multicallReadParams) {
    const { target, allowFailure, callData } = item;
    cleanParams.push({
      target,
      allowFailure,
      callData,
    });
  }

  const callResult = await multicall.callStatic.aggregate3(multicallReadParams);
  const bigNumberResults: Record<string, BigNumber> = {};

  for (let i = 0; i < multicallReadParams.length; i++) {
    const item = multicallReadParams[i];
    bigNumberResults[item.label] = bigNumberify(callResult[i].returnData);
  }

  return { callResult, bigNumberResults };
}
