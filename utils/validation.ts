import { expect } from "chai";
import { bigNumberify } from "./math";

import { getErrorString } from "./error";
import { BigNumberish } from "ethers";
import { getBalanceOf } from "./token";

export function expectWithinRange(actualValue, expectedValue, allowedRange) {
  if (actualValue === undefined) {
    throw new Error("actualValue is undefined");
  }
  if (expectedValue === undefined) {
    throw new Error("expectedValue is undefined");
  }

  const lowerBound = bigNumberify(expectedValue).sub(allowedRange);
  const upperBound = bigNumberify(expectedValue).add(allowedRange);

  const label = `expectedValue: ${expectedValue.toString()}`;
  expect(actualValue, label).gt(lowerBound);
  expect(actualValue, label).lt(upperBound);
}

export async function expectBalances(
  expected: Record<string, Record<string, BigNumberish | [BigNumberish, BigNumberish]>>
) {
  for (const [i, [account, tokenAndExpectedBalances]] of Object.entries(expected).entries()) {
    for (const [j, [token, expectedBalance]] of Object.entries(tokenAndExpectedBalances).entries()) {
      const label = `balance ${i}-${j} account ${account} token ${token}`;
      await expectBalance(token, account, expectedBalance, label);
    }
  }
}

export async function expectBalance(
  token: string,
  account: string,
  expectedBalance: BigNumberish | [BigNumberish, BigNumberish],
  label?: string
) {
  if (!label) {
    label = `balance account ${account} token ${token}`;
  }
  const balance = await getBalanceOf(token, account);
  if (Array.isArray(expectedBalance)) {
    expect(balance, label).to.be.closeTo(expectedBalance[0], expectedBalance[1]);
  } else {
    expect(balance, label).to.be.eq(expectedBalance);
  }
}

export function expectCancellationReason(cancellationReason: any, expectedCancellationReason: any, label: string) {
  if (cancellationReason) {
    if (expectedCancellationReason) {
      if (typeof expectedCancellationReason === "string") {
        expect(cancellationReason.name).eq(expectedCancellationReason);
      } else {
        expect(expectedCancellationReason.name, "reason name").eq(cancellationReason.name);

        if (expectedCancellationReason.args) {
          expect(expectedCancellationReason.args.length, "reason args length").eq(cancellationReason.args.length);
          expect(expectedCancellationReason.args, "reason args").deep.eq(cancellationReason.args);
        }
      }
    } else {
      throw new Error(`${label} was cancelled: ${getErrorString(cancellationReason)}`);
    }
  } else {
    if (expectedCancellationReason) {
      throw new Error(`${label} was not cancelled, expected cancellation with reason: ${expectedCancellationReason}`);
    }
  }
}
