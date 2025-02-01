import { expect } from "chai";

import * as keys from "../../utils/keys";
import * as multichain from "../../utils/multichain";

import { deployFixture } from "../../utils/fixture";
import { expandDecimals } from "../../utils/math";
import { encodeData } from "../../utils/hash";

describe("LayerZeroProvider", () => {
  let fixture;
  let user0;
  let dataStore, usdc, multichainVault, layerZeroProvider, mockStargatePool;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ user0 } = fixture.accounts);
    ({ dataStore, usdc, multichainVault, layerZeroProvider, mockStargatePool } = fixture.contracts);
  });

  it("lzCompose", async () => {
    const sourceChainId = 1;
    const amountUsdc = expandDecimals(50, 6);

    // mint usdc to users and approve StargatePool to spend it
    await usdc.mint(user0.address, amountUsdc);
    await usdc.connect(user0).approve(mockStargatePool.address, amountUsdc);

    // encoded message must match the decoded message in MultichainProviderUtils.decodeDeposit(message)
    const message0 = encodeData(["address", "address", "uint256"], [user0.address, usdc.address, sourceChainId]);

    // StargatePool would deliver usdc to LayerZeroProvider contract and call LayerZeroProvider.lzCompose
    await mockStargatePool.connect(user0).sendToken(usdc.address, layerZeroProvider.address, amountUsdc, message0);

    const lzUsdcBalance = await usdc.balanceOf(layerZeroProvider.address);
    const multichainVaultBalance = await usdc.balanceOf(multichainVault.address);
    const virtualAccount = multichain.getVirtualAccount(user0.address, sourceChainId);
    const userBalance = await dataStore.getUint(keys.sourceChainBalanceKey(virtualAccount, usdc.address));

    // usdc has been transterred from LayerZeroProvider to MultichainVault and recorded under the user's virtual account
    expect(lzUsdcBalance).eq(0);
    expect(multichainVaultBalance).eq(amountUsdc);
    expect(userBalance).eq(amountUsdc);
  });
});
