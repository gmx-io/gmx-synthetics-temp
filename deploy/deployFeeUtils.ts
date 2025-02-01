import { createDeployFunction } from "../utils/deploy";

const func = createDeployFunction({
  contractName: "FeeUtils",
  libraryNames: ["MarketUtils", "MarketEventUtils", "MarketStoreUtils"],
});

export default func;
