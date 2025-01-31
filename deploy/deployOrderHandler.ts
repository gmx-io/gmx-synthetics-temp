import { grantRoleIfNotGranted } from "../utils/role";
import { createDeployFunction } from "../utils/deploy";

const constructorContracts = [
  "RoleStore",
  "DataStore",
  "EventEmitter",
  "Oracle",
  "OrderVault",
  "SwapHandler",
  "ReferralStorage",
];

const func = createDeployFunction({
  contractName: "OrderHandler",
  dependencyNames: constructorContracts,
  getDeployArgs: async ({ dependencyContracts }) => {
    return constructorContracts.map((dependencyName) => dependencyContracts[dependencyName].address);
  },
  libraryNames: ["MarketStoreUtils", "OrderUtils", "ExecuteOrderUtils", "OrderStoreUtils", "OrderEventUtils"],
  afterDeploy: async ({ deployedContract, getNamedAccounts, deployments, network }) => {
    const { deployer } = await getNamedAccounts();
    const { execute } = deployments;

    if (!["arbitrum", "avalanche"].includes(network.name)) {
      await execute("ReferralStorage", { from: deployer, log: true }, "setHandler", deployedContract.address, true);
    }

    await grantRoleIfNotGranted(deployedContract.address, "CONTROLLER");
  },
});

func.skip = async () => {
  return process.env.SKIP_HANDLER_DEPLOYMENTS ? true : false;
};

export default func;
