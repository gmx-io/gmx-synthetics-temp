import { hashData, getAddressFromHash } from "./hash";

export const GMX_MULTICHAIN = "GMX Multichain";

export function getVirtualAccount(account: string, sourceChainId: number): string {
  const hash = hashData(["string", "address", "uint256"], [GMX_MULTICHAIN, account, sourceChainId]);
  return getAddressFromHash(hash);
}
