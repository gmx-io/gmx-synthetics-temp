import { deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";

import { grantRole } from "../../utils/role";
import { validateStoreUtils } from "../../utils/storeUtils";
import {
  OrderType,
  DecreasePositionSwapType,
  getOrderCount,
  getOrderKeys,
  getAccountOrderCount,
  getAccountOrderKeys,
} from "../../utils/order";
import { hashData } from "../../utils/hash";
import * as keys from "../../utils/keys";
import { expect } from "chai";

describe("OrderStoreUtils", () => {
  let fixture;
  let roleStore, reader, orderStoreUtils, orderStoreUtilsTest;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ roleStore, reader, orderStoreUtils } = fixture.contracts);

    orderStoreUtilsTest = await deployContract("OrderStoreUtilsTest", [], {
      libraries: {
        OrderStoreUtils: orderStoreUtils.address,
      },
    });

    await grantRole(roleStore, orderStoreUtilsTest.address, "CONTROLLER");
  });

  it("get, set, remove", async () => {
    await validateStoreUtils({
      fixture,
      getEmptyItem: orderStoreUtilsTest.getEmptyOrder,
      getItem: async (dataStore, key) => {
        return await reader.getOrder(dataStore.address, key);
      },
      setItem: async (dataStore, key, sampleItem) => {
        return await orderStoreUtilsTest.setOrder(dataStore.address, key, sampleItem);
      },
      removeItem: async (dataStore, itemKey, sampleItem) => {
        return await orderStoreUtilsTest.removeOrder(dataStore.address, itemKey, sampleItem.addresses.account);
      },
      getItemCount: getOrderCount,
      getItemKeys: getOrderKeys,
      getAccountItemCount: getAccountOrderCount,
      getAccountItemKeys: getAccountOrderKeys,
      overrideValues: {
        "numbers.orderType": OrderType.LimitDecrease,
        "numbers.decreasePositionSwapType": DecreasePositionSwapType.SwapCollateralTokenToPnlToken,
      },
      expectedPropsLength: 4,
    });
  });
});
