import { createDeployFunction } from "../utils/deploy";

const func = createDeployFunction({
  contractName: "GlvDepositCalc",
  libraryNames: ["MarketUtils", "MarketStoreUtils"],
});

export default func;
