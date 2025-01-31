import { expect } from "chai";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { deployFixture } from "../../utils/fixture";

import { grantRole } from "../../utils/role";
import { hashString } from "../../utils/hash";
import { decimalToFloat, expandDecimals, percentageToFloat } from "../../utils/math";
import { errorsContract } from "../../utils/error";
import * as keys from "../../utils/keys";

describe("Timelock", () => {
  let fixture;
  let timelockAdmin, timelockMultisig, user2, user3, signer0, signer9;
  let timelock, dataStore, roleStore, oracleStore, wnt;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({ timelock, dataStore, roleStore, oracleStore, wnt } = fixture.contracts);
    ({ user2, user3, signer0, signer9 } = fixture.accounts);

    timelockAdmin = fixture.accounts.user0;
    timelockMultisig = fixture.accounts.user1;

    await grantRole(roleStore, timelockAdmin.address, "TIMELOCK_ADMIN");
    await grantRole(roleStore, timelockMultisig.address, "TIMELOCK_MULTISIG");
  });

  it("multisig revokeRole", async () => {
    const orderKeeperRole = hashString("ORDER_KEEPER");

    await timelock.connect(timelockAdmin).signalGrantRole(user3.address, orderKeeperRole);
    await time.increase(1 * 24 * 60 * 60 + 10);
    await timelock.connect(timelockAdmin).grantRoleAfterSignal(user3.address, orderKeeperRole);

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(true);

    await expect(timelock.connect(timelockAdmin).revokeRole(user3.address, orderKeeperRole))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(timelockAdmin.address, "TIMELOCK_MULTISIG");

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(true);

    expect(timelock.connect(timelockMultisig).revokeRole(user3.address, orderKeeperRole));

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(false);
  });

  it("increaseTimelockDelay", async () => {
    await expect(timelock.connect(user2).increaseTimelockDelay(2 * 24 * 60 * 60))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(timelock.connect(timelockAdmin).increaseTimelockDelay(1 * 24 * 60 * 60 - 10))
      .to.be.revertedWithCustomError(errorsContract, "InvalidTimelockDelay")
      .withArgs(1 * 24 * 60 * 60 - 10);

    await expect(timelock.connect(timelockAdmin).increaseTimelockDelay(5 * 24 * 60 * 60 + 10))
      .to.be.revertedWithCustomError(errorsContract, "MaxTimelockDelayExceeded")
      .withArgs(5 * 24 * 60 * 60 + 10);

    expect(await timelock.timelockDelay()).eq(1 * 24 * 60 * 60);
    await timelock.connect(timelockAdmin).increaseTimelockDelay(2 * 24 * 60 * 60);
    expect(await timelock.timelockDelay()).eq(2 * 24 * 60 * 60);
  });

  it("addOracleSigner", async () => {
    await expect(timelock.connect(user2).signalAddOracleSigner(user3.address))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await timelock.connect(timelockAdmin).signalAddOracleSigner(user3.address);

    await expect(timelock.connect(user2).addOracleSignerAfterSignal(user3.address))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock.connect(timelockAdmin).addOracleSignerAfterSignal(user3.address)
    ).to.be.revertedWithCustomError(errorsContract, "SignalTimeNotYetPassed");

    await time.increase(1 * 24 * 60 * 60 + 10);

    expect(await oracleStore.getSignerCount()).eq(10);

    await timelock.connect(timelockAdmin).addOracleSignerAfterSignal(user3.address);

    expect(await oracleStore.getSignerCount()).eq(11);
    expect(await oracleStore.getSigner(10)).eq(user3.address);
  });

  it("removeOracleSigner", async () => {
    await expect(timelock.connect(user2).signalRemoveOracleSigner(signer0.address))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await timelock.connect(timelockAdmin).signalRemoveOracleSigner(signer0.address);

    await expect(timelock.connect(user2).removeOracleSignerAfterSignal(signer0.address))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock.connect(timelockAdmin).removeOracleSignerAfterSignal(signer0.address)
    ).to.be.revertedWithCustomError(errorsContract, "SignalTimeNotYetPassed");

    await time.increase(1 * 24 * 60 * 60 + 10);

    expect(await oracleStore.getSignerCount()).eq(10);
    expect(await oracleStore.getSigner(0)).eq(signer0.address);

    await timelock.connect(timelockAdmin).removeOracleSignerAfterSignal(signer0.address);

    expect(await oracleStore.getSignerCount()).eq(9);
    expect(await oracleStore.getSigner(0)).eq(signer9.address);
  });

  it("setFeeReceiver", async () => {
    await expect(timelock.connect(user2).signalSetFeeReceiver(user3.address))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await timelock.connect(timelockAdmin).signalSetFeeReceiver(user3.address);

    await expect(timelock.connect(user2).setFeeReceiverAfterSignal(user3.address))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock.connect(timelockAdmin).setFeeReceiverAfterSignal(user3.address)
    ).to.be.revertedWithCustomError(errorsContract, "SignalTimeNotYetPassed");

    await time.increase(1 * 24 * 60 * 60 + 10);

    expect(await dataStore.getAddress(keys.FEE_RECEIVER)).eq(ethers.constants.AddressZero);

    await timelock.connect(timelockAdmin).setFeeReceiverAfterSignal(user3.address);

    expect(await dataStore.getAddress(keys.FEE_RECEIVER)).eq(user3.address);
  });

  it("grantRole", async () => {
    const orderKeeperRole = hashString("ORDER_KEEPER");

    await expect(timelock.connect(user2).signalGrantRole(user3.address, orderKeeperRole))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await timelock.connect(timelockAdmin).signalGrantRole(user3.address, orderKeeperRole);

    await expect(timelock.connect(user2).grantRoleAfterSignal(user3.address, orderKeeperRole))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock.connect(timelockAdmin).grantRoleAfterSignal(user3.address, orderKeeperRole)
    ).to.be.revertedWithCustomError(errorsContract, "SignalTimeNotYetPassed");

    await time.increase(1 * 24 * 60 * 60 + 10);

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(false);

    await timelock.connect(timelockAdmin).grantRoleAfterSignal(user3.address, orderKeeperRole);

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(true);
  });

  it("revokeRole", async () => {
    const orderKeeperRole = hashString("ORDER_KEEPER");

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(false);

    await timelock.connect(timelockAdmin).signalGrantRole(user3.address, orderKeeperRole);
    await time.increase(1 * 24 * 60 * 60 + 10);
    await timelock.connect(timelockAdmin).grantRoleAfterSignal(user3.address, orderKeeperRole);

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(true);

    await expect(timelock.connect(user2).signalRevokeRole(user3.address, orderKeeperRole))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await timelock.connect(timelockAdmin).signalRevokeRole(user3.address, orderKeeperRole);

    await expect(timelock.connect(user2).revokeRoleAfterSignal(user3.address, orderKeeperRole))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock.connect(timelockAdmin).revokeRoleAfterSignal(user3.address, orderKeeperRole)
    ).to.be.revertedWithCustomError(errorsContract, "SignalTimeNotYetPassed");

    await time.increase(1 * 24 * 60 * 60 + 10);

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(true);

    await timelock.connect(timelockAdmin).revokeRoleAfterSignal(user3.address, orderKeeperRole);

    expect(await roleStore.hasRole(user3.address, orderKeeperRole)).eq(false);
  });

  it("setOracleProviderForToken", async () => {
    await expect(timelock.connect(user2).signalSetOracleProviderForToken(wnt.address, user3.address))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await timelock.connect(timelockAdmin).signalSetOracleProviderForToken(wnt.address, user3.address);

    await expect(timelock.connect(user2).setOracleProviderForTokenAfterSignal(wnt.address, user3.address))
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock.connect(timelockAdmin).setOracleProviderForTokenAfterSignal(wnt.address, user3.address)
    ).to.be.revertedWithCustomError(errorsContract, "SignalTimeNotYetPassed");

    await time.increase(1 * 24 * 60 * 60 + 10);

    expect(await dataStore.getAddress(keys.oracleProviderForTokenKey(wnt.address))).eq(
      fixture.contracts.gmOracleProvider.address
    );

    await timelock.connect(timelockAdmin).setOracleProviderForTokenAfterSignal(wnt.address, user3.address);

    expect(await dataStore.getAddress(keys.oracleProviderForTokenKey(wnt.address))).eq(user3.address);
  });

  it("setPriceFeed", async () => {
    await dataStore.setAddress(keys.priceFeedKey(wnt.address), ethers.constants.AddressZero);
    await dataStore.setUint(keys.priceFeedMultiplierKey(wnt.address), 0);

    await expect(
      timelock.connect(user2).signalSetPriceFeed(wnt.address, user3.address, 1000, 24 * 60 * 60, decimalToFloat(5000))
    )
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await timelock
      .connect(timelockAdmin)
      .signalSetPriceFeed(wnt.address, user3.address, 1000, 24 * 60 * 60, decimalToFloat(5000));

    await expect(
      timelock
        .connect(user2)
        .setPriceFeedAfterSignal(wnt.address, user3.address, 1000, 24 * 60 * 60, decimalToFloat(5000))
    )
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock
        .connect(timelockAdmin)
        .setPriceFeedAfterSignal(wnt.address, user3.address, 1000, 24 * 60 * 60, decimalToFloat(5000))
    ).to.be.revertedWithCustomError(errorsContract, "SignalTimeNotYetPassed");

    await time.increase(1 * 24 * 60 * 60 + 10);

    expect(await dataStore.getAddress(keys.priceFeedKey(wnt.address))).eq(ethers.constants.AddressZero);
    expect(await dataStore.getUint(keys.priceFeedMultiplierKey(wnt.address))).eq(0);
    expect(await dataStore.getUint(keys.stablePriceKey(wnt.address))).eq(0);

    await timelock
      .connect(timelockAdmin)
      .setPriceFeedAfterSignal(wnt.address, user3.address, 1000, 24 * 60 * 60, decimalToFloat(5000));

    expect(await dataStore.getAddress(keys.priceFeedKey(wnt.address))).eq(user3.address);
    expect(await dataStore.getUint(keys.priceFeedMultiplierKey(wnt.address))).eq(1000);
    expect(await dataStore.getUint(keys.priceFeedHeartbeatDurationKey(wnt.address))).eq(24 * 60 * 60);
    expect(await dataStore.getUint(keys.stablePriceKey(wnt.address))).eq(decimalToFloat(5000));
  });

  it("setDataStream", async () => {
    const p99 = percentageToFloat("99%");

    await expect(
      timelock.connect(user2).signalSetDataStream(wnt.address, hashString("WNT"), expandDecimals(1, 34), p99)
    )
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock
        .connect(timelockAdmin)
        .signalSetDataStream(wnt.address, hashString("WNT"), expandDecimals(1, 34), percentageToFloat("101%"))
    ).to.be.revertedWithCustomError(errorsContract, "ConfigValueExceedsAllowedRange");

    await timelock
      .connect(timelockAdmin)
      .signalSetDataStream(wnt.address, hashString("WNT"), expandDecimals(1, 34), p99);

    await expect(
      timelock.connect(user2).setDataStreamAfterSignal(wnt.address, hashString("WNT"), expandDecimals(1, 34), p99)
    )
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock.connect(user2).setDataStreamAfterSignal(wnt.address, hashString("WNT"), expandDecimals(1, 34), p99)
    )
      .to.be.revertedWithCustomError(errorsContract, "Unauthorized")
      .withArgs(user2.address, "TIMELOCK_ADMIN");

    await expect(
      timelock
        .connect(timelockAdmin)
        .setDataStreamAfterSignal(wnt.address, hashString("WNT"), expandDecimals(1, 34), p99)
    ).to.be.revertedWithCustomError(errorsContract, "SignalTimeNotYetPassed");

    await time.increase(1 * 24 * 60 * 60 + 10);

    expect(await dataStore.getBytes32(keys.dataStreamIdKey(wnt.address))).eq(ethers.constants.HashZero);
    expect(await dataStore.getUint(keys.dataStreamMultiplierKey(wnt.address))).eq(0);
    expect(await dataStore.getUint(keys.dataStreamSpreadReductionFactorKey(wnt.address))).eq(0);

    await timelock
      .connect(timelockAdmin)
      .setDataStreamAfterSignal(wnt.address, hashString("WNT"), expandDecimals(1, 34), p99);

    expect(await dataStore.getBytes32(keys.dataStreamIdKey(wnt.address))).eq(hashString("WNT"));
    expect(await dataStore.getUint(keys.dataStreamMultiplierKey(wnt.address))).eq(expandDecimals(1, 34));
    expect(await dataStore.getUint(keys.dataStreamSpreadReductionFactorKey(wnt.address))).eq(p99);
  });
});
