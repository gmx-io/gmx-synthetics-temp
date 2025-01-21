import { expect } from "chai";

import { contractAt, deployContract } from "../../utils/deploy";
import { deployFixture } from "../../utils/fixture";
import { errorsContract } from "../../utils/error";

describe("GelatoRelayRouterNonEIP2771", () => {
  let fixture;
  let dataStore,
    roleStore,
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
    ({
      dataStore,
      orderVault,
      router,
      roleStore,
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
      "MockGelatoRelayRouterNonEIP2771",
      [
        router.address,
        roleStore.address,
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
    const code = await hre.ethers.provider.getCode(mockContract.address);
    // this verifier was used for signing signatures
    const verifierContract = "0x976C214741b4657bd99DFD38a5c0E3ac5C99D903";
    await hre.ethers.provider.send("hardhat_setCode", [verifierContract, code]);
    mockContract = await contractAt("MockGelatoRelayRouterNonEIP2771", verifierContract);
  });

  it.only("testSimpleSignature", async () => {
    const signature =
      "0x122e3efab9b46c82dc38adf4ea6cd2c753b00f95c217a0e3a0f4dd110839f07a08eb29c1cc414d551349510e23a75219cd70c8b88515ed2b83bbd88216ffdb051c";
    const account = "0xb38302e27bAe8932536A84ab362c3d1013420Cb4";
    const chainId = 42161;
    await mockContract.testSimpleSignature(account, signature, chainId);

    const badSignature =
      "0x122e3efab9b46c82dc38adf4ea6cd2c753b00f95c217a0e3a0f4dd110839f07a08eb29c1cc414d551349510e23a75219cd70c8b88515ed2b83bbd88216ffdb051f";
    await expect(mockContract.testSimpleSignature(account, badSignature, chainId)).to.be.revertedWithCustomError(
      errorsContract,
      "InvalidSignature"
    );
  });

  it.only("testNestedSignature", async () => {
    const signature =
      "0x239455ca6ae3cfda0b7bf6e7e8bb5f343e59cf30292c54c912977381ee9797e139c0d3aa706e42477ef425c19c55e0fa80eb11ec4fb6279ae0297ddf61092bc91c";
    const account = "0xb38302e27bAe8932536A84ab362c3d1013420Cb4";
    const nested = {
      foo: 1,
      bar: true,
    };
    const chainId = 42161;

    await mockContract.testNestedSignature(nested, account, signature, chainId);

    const badSignature =
      "0x239455ca6ae3cfda0b7bf6e7e8bb5f343e59cf30292c54c912977381ee9797e139c0d3aa706e42477ef425c19c55e0fa80eb11ec4fb6279ae0297ddf61092bc91f";
    await expect(
      mockContract.testNestedSignature(nested, account, badSignature, chainId)
    ).to.be.revertedWithCustomError(errorsContract, "InvalidSignature");
  });
});
