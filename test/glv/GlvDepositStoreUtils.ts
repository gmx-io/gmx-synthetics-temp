import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { grantRole } from "../../utils/role";
import { validateStoreUtils } from "../../utils/storeUtils";
import {
  getGlvDepositCount,
  getGlvDepositKeys,
  getAccountGlvDepositCount,
  getAccountGlvDepositKeys,
} from "../../utils/glv/glvDeposit";

describe("GlvDepositStoreUtils", () => {
  let fixture;
  let roleStore, glvReader, glvDepositStoreUtils, glvDepositStoreUtilsTest;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ roleStore, glvReader, glvDepositStoreUtils } = fixture.contracts);

    glvDepositStoreUtilsTest = await deployContract("GlvDepositStoreUtilsTest", [], {
      libraries: {
        GlvDepositStoreUtils: glvDepositStoreUtils.address,
      },
    });

    await grantRole(roleStore, glvDepositStoreUtilsTest.address, "CONTROLLER");
  });

  it("get, set, remove", async () => {
    await validateStoreUtils({
      fixture,
      getEmptyItem: glvDepositStoreUtilsTest.getEmptyGlvDeposit,
      getItem: async (dataStore, key) => {
        return await glvReader.getGlvDeposit(dataStore.address, key);
      },
      setItem: async (dataStore, key, sampleItem) => {
        return await glvDepositStoreUtilsTest.setGlvDeposit(dataStore.address, key, sampleItem);
      },
      removeItem: async (dataStore, itemKey, sampleItem) => {
        return await glvDepositStoreUtilsTest.removeGlvDeposit(
          dataStore.address,
          itemKey,
          sampleItem.addresses.account
        );
      },
      getItemCount: getGlvDepositCount,
      getItemKeys: getGlvDepositKeys,
      getAccountItemCount: getAccountGlvDepositCount,
      getAccountItemKeys: getAccountGlvDepositKeys,
      expectedPropsLength: 4,
    });
  });
});
