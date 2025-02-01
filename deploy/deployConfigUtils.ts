import { createDeployFunction } from "../utils/deploy";

const func = createDeployFunction({
  contractName: "ConfigUtils",
  libraryNames: ["MarketUtils"],
});

export default func;
