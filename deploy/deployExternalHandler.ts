import { createDeployFunction } from "../utils/deploy";

const func = createDeployFunction({
  contractName: "ExternalHandler",
  id: "ExternalHandler_1",
});

func.skip = async () => {
  return process.env.SKIP_HANDLER_DEPLOYMENTS ? true : false;
};

export default func;
