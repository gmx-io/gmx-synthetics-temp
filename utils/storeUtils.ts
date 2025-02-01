import _ from "lodash";
import { expect } from "chai";
import { hashString, hashData } from "./hash";
import { logGasUsage } from "./gas";

function setSampleItemAddresses({ emptyStoreItem, accountList, user0, overrideValues, sampleItem }) {
  if (emptyStoreItem.addresses === undefined) {
    return;
  }

  Object.keys(emptyStoreItem.addresses).forEach((key, index) => {
    if (isNaN(parseInt(key))) {
      let value;

      if (Array.isArray(emptyStoreItem.addresses[key])) {
        value = [accountList[index].address];
      } else if (key === "account") {
        value = user0.address;
      } else {
        value = accountList[index].address;
      }

      if (overrideValues[`addresses.${key}`]) {
        value = overrideValues[`addresses.${key}`];
      }

      sampleItem.addresses[key] = value;
    }
  });
}

function setSampleItemBytes32Array({ emptyStoreItem, sampleItem, arrayLength }) {
  if (emptyStoreItem._dataList === undefined) {
    return;
  }

  for (let i = 0; i < arrayLength; i++) {
    // Convert `i + 1` to a bytes32 value
    const bytes32Value = ethers.utils.formatBytes32String(`${i + 1}`);
    sampleItem._dataList.push(bytes32Value);
  }
}

function setSampleItemNumbers({ emptyStoreItem, overrideValues, sampleItem }) {
  Object.keys(emptyStoreItem.numbers).forEach((key, index) => {
    if (isNaN(parseInt(key))) {
      let value = index + 1;

      if (overrideValues[`numbers.${key}`]) {
        value = overrideValues[`numbers.${key}`];
      }

      sampleItem.numbers[key] = value;
    }
  });
}

function setSampleItemFlags({ emptyStoreItem, sampleItem, index }) {
  if (emptyStoreItem.flags === undefined) {
    return;
  }
  Object.keys(emptyStoreItem.flags).forEach((key, flagIndex) => {
    if (isNaN(parseInt(key))) {
      const adjustedIndex = flagIndex - Object.keys(emptyStoreItem.flags).length / 2;
      // only set one flag to true at a time
      sampleItem.flags[key] = adjustedIndex === index;
    }
  });
}

async function validateFetchedItemAfterSet({ emptyStoreItem, getItem, dataStore, itemKey, sampleItem }) {
  const fetchedItem = await getItem(dataStore, itemKey);

  Object.keys(emptyStoreItem.addresses).forEach((key) => {
    if (isNaN(parseInt(key))) {
      expect(fetchedItem.addresses[key], key).deep.eq(sampleItem.addresses[key]);
    }
  });

  Object.keys(emptyStoreItem.numbers).forEach((key) => {
    if (isNaN(parseInt(key))) {
      expect(fetchedItem.numbers[key], key).eq(sampleItem.numbers[key]);
    }
  });

  if (emptyStoreItem.flags !== undefined) {
    Object.keys(emptyStoreItem.flags).forEach((key) => {
      if (isNaN(parseInt(key))) {
        expect(fetchedItem.flags[key], key).eq(sampleItem.flags[key]);
      }
    });
  }

  if (emptyStoreItem._dataList !== undefined) {
    fetchedItem._dataList.forEach((data, index) => {
      expect(data).eq(sampleItem._dataList[index]);
    });
  }
}

async function validateFetchedItemAfterRemove({ dataStore, itemKey, emptyStoreItem }) {
  for (const key in emptyStoreItem.addresses) {
    if (isNaN(parseInt(key))) {
      const storeKey = _.snakeCase(key).toUpperCase();
      const hash = hashData(["bytes32", "bytes32"], [itemKey, hashString(storeKey)]);

      if (Array.isArray(emptyStoreItem.addresses[key])) {
        const value = await dataStore.getAddressArray(hash);
        expect(value, key).deep.eq([]);
      } else {
        const value = await dataStore.getAddress(hash);
        expect(value, key).eq(ethers.constants.AddressZero);
      }
    }
  }

  for (const key in emptyStoreItem.numbers) {
    if (isNaN(parseInt(key))) {
      const storeKey = _.snakeCase(key).toUpperCase();
      const hash = hashData(["bytes32", "bytes32"], [itemKey, hashString(storeKey)]);

      if (Array.isArray(emptyStoreItem.numbers[key])) {
        const value = await dataStore.getUintArray(hash);
        expect(value, key).deep.eq([]);
      } else {
        const value = await dataStore.getUint(hash);
        expect(value, key).eq(0);
      }
    }
  }

  if (emptyStoreItem.flags !== undefined) {
    for (const key in emptyStoreItem.flags) {
      if (isNaN(parseInt(key))) {
        const storeKey = _.snakeCase(key).toUpperCase();
        const hash = hashData(["bytes32", "bytes32"], [itemKey, hashString(storeKey)]);

        if (Array.isArray(emptyStoreItem.flags[key])) {
          const value = await dataStore.getBoolArray(hash);
          expect(value, key).deep.eq([]);
        } else {
          const value = await dataStore.getBool(hash);
          expect(value, key).eq(false);
        }
      }
    }
  }
}

export async function validateStoreUtils({
  fixture,
  expectedPropsLength = 3,
  getEmptyItem,
  getItem,
  setItem,
  removeItem,
  getItemCount,
  getItemKeys,
  getAccountItemCount = null,
  getAccountItemKeys = null,
  overrideValues = {},
}) {
  const { dataStore } = fixture.contracts;
  const { user0, user1 } = fixture.accounts;
  const { accountList } = fixture;
  const emptyStoreItem = await getEmptyItem();
  const itemKey = hashString("key");

  expect(Object.keys(emptyStoreItem).length).eq(expectedPropsLength * 2);

  const loopCount = emptyStoreItem.flags === undefined ? 1 : Object.keys(emptyStoreItem.flags).length / 2;

  for (let i = 0; i < loopCount; i++) {
    const sampleItem = {
      addresses: {},
      numbers: {},
      flags: {},
      _dataList: [],
    };

    setSampleItemAddresses({
      emptyStoreItem,
      accountList,
      user0,
      overrideValues,
      sampleItem,
    });

    setSampleItemNumbers({ emptyStoreItem, overrideValues, sampleItem });

    setSampleItemFlags({ emptyStoreItem, sampleItem, index: i });

    setSampleItemBytes32Array({ emptyStoreItem, sampleItem, arrayLength: i });

    const initialItemCount = await getItemCount(dataStore);
    const initialItemKeys = await getItemKeys(dataStore, 0, 10);

    if (getAccountItemCount) {
      expect(await getAccountItemCount(dataStore, user0.address)).eq(0);
      expect(await getAccountItemKeys(dataStore, user0.address, 0, 10)).deep.equal([]);

      expect(await getAccountItemCount(dataStore, user1.address)).eq(0);
      expect(await getAccountItemKeys(dataStore, user1.address, 0, 10)).deep.equal([]);
    }

    await logGasUsage({
      tx: setItem(dataStore, itemKey, sampleItem),
      label: "setItem",
    });

    await validateFetchedItemAfterSet({ emptyStoreItem, getItem, dataStore, itemKey, sampleItem });

    expect(await getItemCount(dataStore)).eq(initialItemCount.add(1));
    expect(await getItemKeys(dataStore, 0, 10)).deep.equal(initialItemKeys.concat(itemKey));

    if (getAccountItemCount) {
      expect(await getAccountItemCount(dataStore, user0.address)).eq(1);
      expect(await getAccountItemKeys(dataStore, user0.address, 0, 10)).deep.equal([itemKey]);

      expect(await getAccountItemCount(dataStore, user1.address)).eq(0);
      expect(await getAccountItemKeys(dataStore, user1.address, 0, 10)).deep.equal([]);
    }

    await removeItem(dataStore, itemKey, sampleItem);

    expect(await getItemCount(dataStore)).eq(initialItemCount);
    expect(await getItemKeys(dataStore, 0, 10)).deep.equal(initialItemKeys);

    if (getAccountItemCount) {
      expect(await getAccountItemCount(dataStore, user0.address)).eq(0);
      expect(await getAccountItemKeys(dataStore, user0.address, 0, 10)).deep.equal([]);

      expect(await getAccountItemCount(dataStore, user1.address)).eq(0);
      expect(await getAccountItemKeys(dataStore, user1.address, 0, 10)).deep.equal([]);
    }

    await validateFetchedItemAfterRemove({ dataStore, itemKey, emptyStoreItem });
  }
}
