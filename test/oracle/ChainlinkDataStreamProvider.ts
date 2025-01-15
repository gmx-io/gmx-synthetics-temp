import { expect } from "chai";
import { deployFixture } from "../../utils/fixture";

import { decodeData, encodeData } from "../../utils/hash";
import { expandDecimals, percentageToFloat } from "../../utils/math";
import * as keys from "../../utils/keys";
import { ethers } from "hardhat";
import { BigNumberish } from "ethers";
import { parseError } from "../../utils/error";

function decodeValidatedPrice(data: string) {
  try {
    const decoded = decodeData(["address", "uint256", "uint256", "uint256", "address"], data);
    return {
      token: decoded[0],
      min: decoded[1],
      max: decoded[2],
      timestamp: decoded[3],
      provider: decoded[4],
    };
  } catch (ex) {
    const error = parseError(data);
    throw error;
  }
}

function encodeReport(feedId: string, bid: BigNumberish, ask: BigNumberish) {
  return encodeData(
    ["bytes32", "uint32", "uint32", "uint192", "uint192", "uint32", "int192", "int192", "int192"],
    [feedId, 1, 1732209862, 1732209872, 4, 5, 6, bid, ask]
  );
}

describe("ChainlinkDataStreamProvider", () => {
  let fixture;
  let dataStore, chainlinkDataStreamProvider, wnt, oracle;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ dataStore, chainlinkDataStreamProvider, wnt, oracle } = fixture.contracts);
  });

  it("data stream spread", async () => {
    const feedId = "0x0000000000000000000000000000000000000000000000000000000000000001";
    await dataStore.setBytes32(keys.dataStreamIdKey(wnt.address), feedId);
    await dataStore.setUint(keys.dataStreamMultiplierKey(wnt.address), expandDecimals(1, 30));

    async function getOraclePrice() {
      const callData = chainlinkDataStreamProvider.interface.encodeFunctionData("getOraclePrice", [
        wnt.address,
        encodeReport(feedId, 99999990, 100000010),
      ]);

      const result = await ethers.provider.call({
        to: chainlinkDataStreamProvider.address,
        data: callData,
        from: oracle.address,
      });

      return decodeValidatedPrice(result);
    }

    await dataStore.setUint(keys.dataStreamSpreadReductionFactorKey(wnt.address), 0);
    const oraclePriceA = await getOraclePrice();
    expect(oraclePriceA.min).eq(99999990);
    expect(oraclePriceA.max).eq(100000010);

    await dataStore.setUint(keys.dataStreamSpreadReductionFactorKey(wnt.address), percentageToFloat("90%"));
    const oraclePriceB = await getOraclePrice();

    expect(oraclePriceB.min).eq(99999999);
    expect(oraclePriceB.max).eq(100000001);

    await dataStore.setUint(keys.dataStreamSpreadReductionFactorKey(wnt.address), percentageToFloat("100%"));
    const oraclePriceC = await getOraclePrice();

    expect(oraclePriceC.min).eq(100000000);
    expect(oraclePriceC.max).eq(100000000);

    await dataStore.setUint(keys.dataStreamSpreadReductionFactorKey(wnt.address), percentageToFloat("300%"));
    await expect(getOraclePrice()).to.be.rejected;
  });
});
