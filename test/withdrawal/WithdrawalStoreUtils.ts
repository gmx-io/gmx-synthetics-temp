import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { grantRole } from "../../utils/role";
import { validateStoreUtils } from "../../utils/storeUtils";
import {
  getWithdrawalCount,
  getWithdrawalKeys,
  getAccountWithdrawalCount,
  getAccountWithdrawalKeys,
} from "../../utils/withdrawal";

describe("WithdrawalStoreUtils", () => {
  let fixture;
  let roleStore, reader, withdrawalStoreUtils, withdrawalStoreUtilsTest;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ roleStore, reader, withdrawalStoreUtils } = fixture.contracts);

    withdrawalStoreUtilsTest = await deployContract("WithdrawalStoreUtilsTest", [], {
      libraries: {
        WithdrawalStoreUtils: withdrawalStoreUtils.address,
      },
    });

    await grantRole(roleStore, withdrawalStoreUtilsTest.address, "CONTROLLER");
  });

  it("get, set, remove", async () => {
    await validateStoreUtils({
      fixture,
      getEmptyItem: withdrawalStoreUtilsTest.getEmptyWithdrawal,
      getItem: async (dataStore, key) => {
        return await reader.getWithdrawal(dataStore.address, key);
      },
      setItem: async (dataStore, key, sampleItem) => {
        return await withdrawalStoreUtilsTest.setWithdrawal(dataStore.address, key, sampleItem);
      },
      removeItem: async (dataStore, itemKey, sampleItem) => {
        return await withdrawalStoreUtilsTest.removeWithdrawal(
          dataStore.address,
          itemKey,
          sampleItem.addresses.account
        );
      },
      getItemCount: getWithdrawalCount,
      getItemKeys: getWithdrawalKeys,
      getAccountItemCount: getAccountWithdrawalCount,
      getAccountItemKeys: getAccountWithdrawalKeys,
      expectedPropsLength: 4,
    });
  });
});
