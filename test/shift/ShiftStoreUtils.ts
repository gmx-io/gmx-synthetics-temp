import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { grantRole } from "../../utils/role";
import { validateStoreUtils } from "../../utils/storeUtils";
import { getShiftCount, getShiftKeys, getAccountShiftCount, getAccountShiftKeys } from "../../utils/shift";

describe("ShiftStoreUtils", () => {
  let fixture;
  let roleStore, reader, shiftStoreUtils, shiftStoreUtilsTest;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ roleStore, reader, shiftStoreUtils } = fixture.contracts);

    shiftStoreUtilsTest = await deployContract("ShiftStoreUtilsTest", [], {
      libraries: {
        ShiftStoreUtils: shiftStoreUtils.address,
      },
    });

    await grantRole(roleStore, shiftStoreUtilsTest.address, "CONTROLLER");
  });

  it("get, set, remove", async () => {
    await validateStoreUtils({
      fixture,
      getEmptyItem: shiftStoreUtilsTest.getEmptyShift,
      getItem: async (dataStore, key) => {
        return await reader.getShift(dataStore.address, key);
      },
      setItem: async (dataStore, key, sampleItem) => {
        return await shiftStoreUtilsTest.setShift(dataStore.address, key, sampleItem);
      },
      removeItem: async (dataStore, itemKey, sampleItem) => {
        return await shiftStoreUtilsTest.removeShift(dataStore.address, itemKey, sampleItem.addresses.account);
      },
      getItemCount: getShiftCount,
      getItemKeys: getShiftKeys,
      getAccountItemCount: getAccountShiftCount,
      getAccountItemKeys: getAccountShiftKeys,
    });
  });
});
