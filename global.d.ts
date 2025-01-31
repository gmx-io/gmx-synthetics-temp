declare function extendEnvironment(any): void;
import { ethers as ethersModule } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

declare global {
  let ethers: typeof ethersModule;
  let hre: typeof HardhatRuntimeEnvironment;
}

declare const ethers: any;
