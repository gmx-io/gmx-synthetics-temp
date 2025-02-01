import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { grantRole } from "../../utils/role";
import { validateStoreUtils } from "../../utils/storeUtils";
import {
  getGlvWithdrawalCount,
  getGlvWithdrawalKeys,
  getAccountGlvWithdrawalCount,
  getAccountGlvWithdrawalKeys,
} from "../../utils/glv/glvWithdrawal";

describe("GlvWithdrawalStoreUtils", () => {
  let fixture;
  let roleStore, glvReader, glvWithdrawalStoreUtils, glvWithdrawalStoreUtilsTest;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ roleStore, glvReader, glvWithdrawalStoreUtils } = fixture.contracts);

    glvWithdrawalStoreUtilsTest = await deployContract("GlvWithdrawalStoreUtilsTest", [], {
      libraries: {
        GlvWithdrawalStoreUtils: glvWithdrawalStoreUtils.address,
      },
    });

    await grantRole(roleStore, glvWithdrawalStoreUtilsTest.address, "CONTROLLER");
  });

  it("get, set, remove", async () => {
    await validateStoreUtils({
      fixture,
      getEmptyItem: glvWithdrawalStoreUtilsTest.getEmptyGlvWithdrawal,
      getItem: async (dataStore, key) => {
        return await glvReader.getGlvWithdrawal(dataStore.address, key);
      },
      setItem: async (dataStore, key, sampleItem) => {
        return await glvWithdrawalStoreUtilsTest.setGlvWithdrawal(dataStore.address, key, sampleItem);
      },
      removeItem: async (dataStore, itemKey, sampleItem) => {
        return await glvWithdrawalStoreUtilsTest.removeGlvWithdrawal(
          dataStore.address,
          itemKey,
          sampleItem.addresses.account
        );
      },
      getItemCount: getGlvWithdrawalCount,
      getItemKeys: getGlvWithdrawalKeys,
      getAccountItemCount: getAccountGlvWithdrawalCount,
      getAccountItemKeys: getAccountGlvWithdrawalKeys,
      expectedPropsLength: 4,
    });
  });
});
