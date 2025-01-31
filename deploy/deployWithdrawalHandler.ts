import { grantRoleIfNotGranted } from "../utils/role";
import { createDeployFunction } from "../utils/deploy";

const constructorContracts = ["RoleStore", "DataStore", "EventEmitter", "Oracle", "WithdrawalVault"];

const func = createDeployFunction({
  contractName: "WithdrawalHandler",
  dependencyNames: constructorContracts,
  getDeployArgs: async ({ dependencyContracts }) => {
    return constructorContracts.map((dependencyName) => dependencyContracts[dependencyName].address);
  },
  libraryNames: ["WithdrawalUtils", "ExecuteWithdrawalUtils", "WithdrawalStoreUtils", "GasUtils"],
  afterDeploy: async ({ deployedContract }) => {
    await grantRoleIfNotGranted(deployedContract.address, "CONTROLLER");
  },
});

func.skip = async () => {
  return process.env.SKIP_HANDLER_DEPLOYMENTS ? true : false;
};

export default func;
