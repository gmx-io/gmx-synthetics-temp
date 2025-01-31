import { grantRoleIfNotGranted } from "../utils/role";
import { createDeployFunction } from "../utils/deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const constructorContracts = ["RoleStore", "Oracle", "DataStore", "EventEmitter"];

const func = createDeployFunction({
  contractName: "FeeHandler",
  dependencyNames: constructorContracts,
  getDeployArgs: async ({ dependencyContracts, gmx, network, get }) => {
    const vaultV1Config = await gmx.getVaultV1();
    let vaultV1Address = vaultV1Config.vaultV1;
    let gmxAddress = vaultV1Config.gmx;
    if (network.name === "hardhat") {
      const vaultV1 = await get("MockVaultV1");
      const tokens = await hre.gmx.getTokens();
      vaultV1Address = vaultV1.address;
      gmxAddress = tokens.GMX.address;
    }
    if (!vaultV1Address) {
      throw new Error("vaultV1Address is not defined");
    }
    return constructorContracts
      .map((dependencyName) => dependencyContracts[dependencyName].address)
      .concat(vaultV1Address)
      .concat(gmxAddress);
  },
  libraryNames: ["MarketUtils"],
  afterDeploy: async ({ deployedContract }) => {
    await grantRoleIfNotGranted(deployedContract.address, "CONTROLLER");
  },
  // FeeHandler should not be re-deployed as the new FeeHandler would not have
  // the funds from the existing FeeHandler which could lead to errors in
  // buybacks and withdrawal of fees as the amounts in the DataStore would
  // not match the contract balance
  // The migration of funds must be explicitly handled if a re-deploy is required
  id: "FeeHandler_1",
});

func.dependencies = func.dependencies.concat(["MockVaultV1"]);
func.skip = async (hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name === "avalancheFuji") {
    return true;
  }

  return process.env.SKIP_HANDLER_DEPLOYMENTS ? true : false;
};

export default func;
