import hre from "hardhat";
import { timelockWriteMulticall } from "../utils/timelock";

const expectedTimelockMethods = ["signalSetOracleProviderEnabled", "setOracleProviderEnabledAfterSignal"];

async function main() {
  const timelock = await hre.ethers.getContract("Timelock");

  const providersToAdd = {
    arbitrum: [
      // GmOracleProvider is not included by default as it is meant to be used as
      // a backup only in the event that the other providers are not working
      // "0x83cBb05AA78014305194450c4AADAc887fe5DF7F", // ChainlinkDataStreamProvider_3
      // "0x527FB0bCfF63C47761039bB386cFE181A92a4701", // ChainlinkPriceFeedProvider_3
      "0xF4122dF7Be4Ccd46D7397dAf2387B3A14e53d967", // ChainlinkDataStreamProvider_4
    ],
    avalanche: [
      // GmOracleProvider is not included by default as it is meant to be used as
      // a backup only in the event that the other providers are not working
      // "0x46088fA22988c40CE5aBC0647a7638D27A8bF7d1", // ChainlinkDataStreamProvider_3
      // "0x713c6a2479f6C079055A6AD3690D95dEDCEf9e1e", // ChainlinkPriceFeedProvider_3
      "0x236913dBd610D9d77b9B8B62C99aF0FF4E43ce3a", // ChainlinkDataStreamProvider_4
    ],
  };

  const multicallWriteParams = [];

  const timelockMethod = process.env.TIMELOCK_METHOD;
  if (!expectedTimelockMethods.includes(timelockMethod)) {
    throw new Error(`Unexpected TIMELOCK_METHOD: ${timelockMethod}`);
  }

  for (const provider of providersToAdd[hre.network.name]) {
    multicallWriteParams.push(timelock.interface.encodeFunctionData(timelockMethod, [provider, true]));
  }

  console.log(`updating ${multicallWriteParams.length} providers`);
  await timelockWriteMulticall({ timelock, multicallWriteParams });
}

main().catch((ex) => {
  console.error(ex);
  process.exit(1);
});
