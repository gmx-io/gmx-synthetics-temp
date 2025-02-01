import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { grantRole } from "../../utils/role";
import { validateStoreUtils } from "../../utils/storeUtils";
import { getDepositCount, getDepositKeys, getAccountDepositCount, getAccountDepositKeys } from "../../utils/deposit";

describe("DepositStoreUtils", () => {
  let fixture;
  let roleStore, reader, depositStoreUtils, depositStoreUtilsTest;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ roleStore, reader, depositStoreUtils } = fixture.contracts);

    depositStoreUtilsTest = await deployContract("DepositStoreUtilsTest", [], {
      libraries: {
        DepositStoreUtils: depositStoreUtils.address,
      },
    });

    await grantRole(roleStore, depositStoreUtilsTest.address, "CONTROLLER");
  });

  it("get, set, remove", async () => {
    await validateStoreUtils({
      fixture,
      getEmptyItem: depositStoreUtilsTest.getEmptyDeposit,
      getItem: async (dataStore, key) => {
        return await reader.getDeposit(dataStore.address, key);
      },
      setItem: async (dataStore, key, sampleItem) => {
        return await depositStoreUtilsTest.setDeposit(dataStore.address, key, sampleItem);
      },
      removeItem: async (dataStore, itemKey, sampleItem) => {
        return await depositStoreUtilsTest.removeDeposit(dataStore.address, itemKey, sampleItem.addresses.account);
      },
      getItemCount: getDepositCount,
      getItemKeys: getDepositKeys,
      getAccountItemCount: getAccountDepositCount,
      getAccountItemKeys: getAccountDepositKeys,
      expectedPropsLength: 4,
    });
  });
});
