import { expect } from "chai";

import { deployContract } from "../../../utils/deploy";
import { deployFixture } from "../../../utils/fixture";
import { errorsContract } from "../../../utils/error";

const BAD_SIGNATURE =
  "0x122e3efab9b46c82dc38adf4ea6cd2c753b00f95c217a0e3a0f4dd110839f07a08eb29c1cc414d551349510e23a75219cd70c8b88515ed2b83bbd88216ffdb051f";
const chainId = 42161;

describe("Relay signatures", () => {
  let fixture;
  let user0;
  let domain;
  let dataStore,
    eventEmitter,
    oracle,
    orderHandler,
    orderVault,
    router,
    marketStoreUtils,
    orderStoreUtils,
    swapUtils,
    mockContract;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0 } = fixture.accounts);
    ({
      dataStore,
      orderVault,
      router,
      eventEmitter,
      oracle,
      orderHandler,
      marketStoreUtils,
      orderStoreUtils,
      swapUtils,
    } = fixture.contracts);
  });

  beforeEach(async () => {
    mockContract = await deployContract(
      "MockGelatoRelayRouter",
      [
        router.address,
        dataStore.address,
        eventEmitter.address,
        oracle.address,
        orderHandler.address,
        orderVault.address,
      ],
      {
        libraries: {
          MarketStoreUtils: marketStoreUtils.address,
          OrderStoreUtils: orderStoreUtils.address,
          SwapUtils: swapUtils.address,
        },
      }
    );
    domain = {
      name: "GmxBaseGelatoRelayRouter",
      version: "1",
      chainId,
      verifyingContract: mockContract.address,
    };
  });

  it("testSimpleSignature", async () => {
    const types = {
      PrimaryStruct: [{ name: "account", type: "address" }],
    };

    const account = user0.address;
    const value = {
      account: account,
    };

    const signature = await user0._signTypedData(domain, types, value);
    await mockContract.testSimpleSignature(account, signature, chainId);

    await expect(mockContract.testSimpleSignature(account, BAD_SIGNATURE, chainId)).to.be.revertedWithCustomError(
      errorsContract,
      "InvalidSignature"
    );
  });

  it("testNestedSignature", async () => {
    const types = {
      PrimaryStruct: [
        { name: "account", type: "address" },
        { name: "nested", type: "Nested" },
      ],
      Nested: [
        { name: "foo", type: "uint256" },
        { name: "bar", type: "bool" },
      ],
    };
    const nested = {
      foo: 1,
      bar: true,
    };
    const account = user0.address;
    const value = {
      account: account,
      nested: nested,
    };
    const signature = await user0._signTypedData(domain, types, value);
    await mockContract.testNestedSignature(nested, account, signature, chainId);

    await expect(
      mockContract.testNestedSignature(nested, account, BAD_SIGNATURE, chainId)
    ).to.be.revertedWithCustomError(errorsContract, "InvalidSignature");
  });

  it("testArraySignature", async () => {
    const types = {
      PrimaryStruct: [
        { name: "account", type: "address" },
        { name: "array", type: "address[]" },
      ],
    };

    const account = user0.address;
    const value = {
      account: account,
      array: [account, account],
    };
    const signature = await user0._signTypedData(domain, types, value);
    await mockContract.testArraySignature([account, account], account, signature, chainId);

    await expect(
      mockContract.testArraySignature([account, account], account, BAD_SIGNATURE, chainId)
    ).to.be.revertedWithCustomError(errorsContract, "InvalidSignature");
  });
});
