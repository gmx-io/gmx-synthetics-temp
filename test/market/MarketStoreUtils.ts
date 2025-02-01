import { expect } from "chai";
import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { grantRole } from "../../utils/role";
import { getMarketCount, getMarketKeys, DEFAULT_MARKET_TYPE } from "../../utils/market";
import { logGasUsage } from "../../utils/gas";

describe("MarketStoreUtils", () => {
  let fixture;
  let accountList;
  let dataStore, roleStore, reader, marketStoreUtils, marketStoreUtilsTest;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ accountList } = fixture);
    ({ dataStore, roleStore, reader, marketStoreUtils } = fixture.contracts);

    marketStoreUtilsTest = await deployContract("MarketStoreUtilsTest", [], {
      libraries: {
        MarketStoreUtils: marketStoreUtils.address,
      },
    });

    await grantRole(roleStore, marketStoreUtilsTest.address, "CONTROLLER");
  });

  it("get, set, remove", async () => {
    const sampleItem = {};
    const itemKey = accountList[accountList.length - 1].address;
    const marketType = DEFAULT_MARKET_TYPE;

    const getEmptyItem = marketStoreUtilsTest.getEmptyMarket;
    const getItem = async (dataStore, key) => {
      return await reader.getMarket(dataStore.address, key);
    };
    const getItemCount = getMarketCount;
    const getItemKeys = getMarketKeys;
    const setItem = async (dataStore, key, sampleItem) => {
      return await marketStoreUtilsTest.setMarket(dataStore.address, key, marketType, sampleItem);
    };
    const removeItem = async (dataStore, itemKey) => {
      return await marketStoreUtilsTest.removeMarket(dataStore.address, itemKey, marketType);
    };

    const emptyStoreItem = await getEmptyItem();

    const expectedPropsLength = 4;
    expect(Object.keys(emptyStoreItem).length).eq(expectedPropsLength * 2);

    Object.keys(emptyStoreItem).forEach((key, index) => {
      if (isNaN(key)) {
        sampleItem[key] = accountList[index].address;
      }
    });

    const initialItemCount = await getItemCount(dataStore);
    const initialItemKeys = await getItemKeys(dataStore, 0, 10);

    await logGasUsage({
      tx: setItem(dataStore, itemKey, sampleItem),
      label: "setItem",
    });

    let fetchedItem = await getItem(dataStore, itemKey);

    Object.keys(emptyStoreItem).forEach((key) => {
      if (isNaN(key)) {
        expect(fetchedItem[key]).deep.eq(sampleItem[key]);
      }
    });

    expect(await getItemCount(dataStore)).eq(initialItemCount.add(1));
    expect(await getItemKeys(dataStore, 0, 10)).deep.equal(initialItemKeys.concat(itemKey));

    await removeItem(dataStore, itemKey, sampleItem);

    fetchedItem = await getItem(dataStore, itemKey);

    Object.keys(emptyStoreItem).forEach((key) => {
      if (isNaN(key)) {
        expect(fetchedItem[key]).deep.eq(ethers.constants.AddressZero);
      }
    });

    expect(await getItemCount(dataStore)).eq(initialItemCount);
    expect(await getItemKeys(dataStore, 0, 10)).deep.equal(initialItemKeys);
  });
});
