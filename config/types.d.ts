import { TokensConfig } from "./tokens";
import { MarketConfig } from "./markets";
import { OracleConfig } from "./oracle";
import getGeneral from "./general";
import { RolesConfig } from "./roles";
import { RiskOracleConfig } from "./riskOracle";
import { VaultV1Config } from "./vaultV1";

export type OracleProvider = "gmOracle" | "chainlinkDataStream" | "chainlinkPriceFeed";

// extend hardhat config with custom gmx property
declare module "hardhat/types/runtime" {
  interface HardhatRuntimeEnvironment {
    gmx: {
      getTokens: () => Promise<TokensConfig>;
      getMarkets: () => Promise<MarketConfig[]>;
      getOracle: () => Promise<OracleConfig>;
      getGeneral: () => ReturnType<typeof getGeneral>;
      getRoles: () => Promise<RolesConfig>;
      getRiskOracle: () => Promise<RiskOracleConfig>;
      getVaultV1: () => Promise<VaultV1Config>;
    };
  }
}
