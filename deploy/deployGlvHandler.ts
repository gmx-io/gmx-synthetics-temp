import { grantRoleIfNotGranted } from "../utils/role";
import { createDeployFunction } from "../utils/deploy";

const constructorContracts = ["RoleStore", "DataStore", "EventEmitter", "Oracle", "GlvVault", "ShiftVault"];

const func = createDeployFunction({
  contractName: "GlvHandler",
  dependencyNames: constructorContracts,
  getDeployArgs: async ({ dependencyContracts }) => {
    return constructorContracts.map((dependencyName) => dependencyContracts[dependencyName].address);
  },
  libraryNames: [
    "GlvDepositStoreUtils",
    "GlvDepositUtils",
    "GlvShiftStoreUtils",
    "GlvShiftUtils",
    "GlvUtils",
    "GlvWithdrawalStoreUtils",
    "GlvWithdrawalUtils",
  ],
  afterDeploy: async ({ deployedContract }) => {
    await grantRoleIfNotGranted(deployedContract.address, "CONTROLLER");
  },
});

func.skip = async () => {
  return process.env.SKIP_HANDLER_DEPLOYMENTS ? true : false;
};

export default func;
