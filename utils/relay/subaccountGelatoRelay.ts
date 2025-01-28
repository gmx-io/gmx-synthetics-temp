import { BigNumberish, ethers } from "ethers";
import * as keys from "../keys";
import { GELATO_RELAY_ADDRESS } from "./addresses";
import { getDomain, hashSubaccountApproval, hashRelayParams, getRelayParams } from "./helpers";

export async function sendCreateOrder(p: {
  subaccountApprovalSigner: ethers.Signer;
  subaccount: string;
  subaccountApproval: {
    subaccount: string;
    expiresAt: BigNumberish;
    maxAllowedCount: BigNumberish;
    actionType: string;
    deadline: BigNumberish;
    nonce: BigNumberish;
    signature: string | undefined;
  };
  signer: ethers.Signer;
  sender: ethers.Signer;
  oracleParams: {
    tokens: string[];
    providers: string[];
    data: string[];
  };
  tokenPermits: {
    token: string;
    spender: string;
    value: BigNumberish;
    nonce: BigNumberish;
    deadline: BigNumberish;
    chainId: BigNumberish;
  }[];
  feeParams: {
    feeToken: string;
    feeAmount: BigNumberish;
    feeSwapPath: string[];
  };
  collateralDeltaAmount: BigNumberish;
  account: string;
  params: any;
  signature: string | undefined;
  userNonce: BigNumberish;
  deadline: BigNumberish;
  relayRouter: ethers.Contract;
  chainId: BigNumberish;
  relayFeeToken: string;
  relayFeeAmount: BigNumberish;
}) {
  const relayParams = getRelayParams(p.oracleParams, p.tokenPermits, p.feeParams);

  if (!p.subaccountApproval) {
    p.subaccountApproval = getEmptySubaccountApproval();
  }
  if (p.subaccountApproval && !p.subaccountApproval.signature) {
    p.subaccountApproval.signature = await getSubaccountApprovalSignature({
      signer: p.subaccountApprovalSigner,
      chainId: p.chainId,
      verifyingContract: p.relayRouter.address,
      ...p.subaccountApproval,
    });
  }

  if (!p.signature) {
    p.signature = await getCreateOrderSignature({ ...p, relayParams, verifyingContract: p.relayRouter.address });
  }
  const createOrderCalldata = p.relayRouter.interface.encodeFunctionData("createOrder", [
    relayParams,
    p.subaccountApproval,
    p.collateralDeltaAmount,
    p.account,
    p.subaccount,
    p.params,
    p.userNonce,
    p.deadline,
    p.signature,
  ]);
  const calldata = ethers.utils.solidityPack(
    ["bytes", "address", "address", "uint256"],
    [createOrderCalldata, GELATO_RELAY_ADDRESS, p.relayFeeToken, p.relayFeeAmount]
  );
  return p.sender.sendTransaction({
    to: p.relayRouter.address,
    data: calldata,
  });
}

function getEmptySubaccountApproval() {
  return {
    subaccount: ethers.constants.AddressZero,
    expiresAt: 0,
    maxAllowedCount: 0,
    actionType: keys.SUBACCOUNT_ORDER_ACTION,
    deadline: 0,
    nonce: 0,
    signature: "0x",
  };
}

async function getCreateOrderSignature({
  signer,
  relayParams,
  subaccountApproval,
  collateralDeltaAmount,
  account,
  verifyingContract,
  params,
  deadline,
  userNonce,
  chainId,
}) {
  const types = {
    CreateOrder: [
      { name: "collateralDeltaAmount", type: "uint256" },
      { name: "account", type: "address" },
      { name: "addresses", type: "CreateOrderAddresses" },
      { name: "numbers", type: "CreateOrderNumbers" },
      { name: "orderType", type: "uint256" },
      { name: "isLong", type: "bool" },
      { name: "shouldUnwrapNativeToken", type: "bool" },
      { name: "autoCancel", type: "bool" },
      { name: "referralCode", type: "bytes32" },
      { name: "userNonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
      { name: "relayParams", type: "bytes32" },
      { name: "subaccountApproval", type: "bytes32" },
    ],
    CreateOrderAddresses: [
      { name: "receiver", type: "address" },
      { name: "cancellationReceiver", type: "address" },
      { name: "callbackContract", type: "address" },
      { name: "uiFeeReceiver", type: "address" },
      { name: "market", type: "address" },
      { name: "initialCollateralToken", type: "address" },
      { name: "swapPath", type: "address[]" },
    ],
    CreateOrderNumbers: [
      { name: "sizeDeltaUsd", type: "uint256" },
      { name: "initialCollateralDeltaAmount", type: "uint256" },
      { name: "triggerPrice", type: "uint256" },
      { name: "acceptablePrice", type: "uint256" },
      { name: "executionFee", type: "uint256" },
      { name: "callbackGasLimit", type: "uint256" },
      { name: "minOutputAmount", type: "uint256" },
      { name: "validFromTime", type: "uint256" },
    ],
  };

  const domain = getDomain(chainId, verifyingContract);
  const typedData = {
    collateralDeltaAmount,
    account,
    addresses: params.addresses,
    numbers: params.numbers,
    orderType: params.orderType,
    isLong: params.isLong,
    shouldUnwrapNativeToken: params.shouldUnwrapNativeToken,
    autoCancel: false,
    referralCode: params.referralCode,
    userNonce,
    deadline,
    relayParams: hashRelayParams(relayParams),
    subaccountApproval: hashSubaccountApproval(subaccountApproval),
  };

  return signer._signTypedData(domain, types, typedData);
}

export async function sendUpdateOrder(p: {
  sender: ethers.Signer;
  signer: ethers.Signer;
  oracleParams?: {
    tokens: string[];
    providers: string[];
    data: string[];
  };
  tokenPermits?: {
    token: string;
    spender: string;
    value: BigNumberish;
    nonce: BigNumberish;
    deadline: BigNumberish;
    chainId: BigNumberish;
  }[];
  feeParams: {
    feeToken: string;
    feeAmount: BigNumberish;
    feeSwapPath: string[];
  };
  subaccount: string;
  key: string;
  subaccountApproval: any;
  subaccountApprovalSigner: ethers.Signer;
  chainId: BigNumberish;
  account: string;
  params: {
    sizeDeltaUsd: BigNumberish;
    acceptablePrice: BigNumberish;
    triggerPrice: BigNumberish;
    minOutputAmount: BigNumberish;
    validFromTime: BigNumberish;
    autoCancel: boolean;
  };
  deadline: BigNumberish;
  userNonce: BigNumberish;
  relayRouter: ethers.Contract;
  signature?: string;
  relayFeeToken: string;
  relayFeeAmount: BigNumberish;
}) {
  const relayParams = getRelayParams(p.oracleParams, p.tokenPermits, p.feeParams);

  if (!p.subaccountApproval) {
    p.subaccountApproval = getEmptySubaccountApproval();
  }
  if (!p.subaccountApproval.signature) {
    p.subaccountApproval.signature = await getSubaccountApprovalSignature({
      signer: p.subaccountApprovalSigner,
      chainId: p.chainId,
      verifyingContract: p.relayRouter.address,
      ...p.subaccountApproval,
    });
  }

  if (!p.signature) {
    p.signature = await getUpdateOrderSignature({ ...p, relayParams, verifyingContract: p.relayRouter.address });
  }
  const updateOrderCalldata = p.relayRouter.interface.encodeFunctionData("updateOrder", [
    relayParams,
    p.subaccountApproval,
    p.account,
    p.subaccount,
    p.key,
    p.params,
    p.userNonce,
    p.deadline,
    p.signature,
  ]);
  const calldata = ethers.utils.solidityPack(
    ["bytes", "address", "address", "uint256"],
    [updateOrderCalldata, GELATO_RELAY_ADDRESS, p.relayFeeToken, p.relayFeeAmount]
  );
  return p.sender.sendTransaction({
    to: p.relayRouter.address,
    data: calldata,
  });
}

async function getUpdateOrderSignature({
  signer,
  relayParams,
  subaccountApproval,
  account,
  verifyingContract,
  params,
  key,
  deadline,
  userNonce,
  chainId,
}) {
  const types = {
    UpdateOrder: [
      { name: "account", type: "address" },
      { name: "key", type: "bytes32" },
      { name: "params", type: "UpdateOrderParams" },
      { name: "userNonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
      { name: "relayParams", type: "bytes32" },
      { name: "subaccountApproval", type: "bytes32" },
    ],
    UpdateOrderParams: [
      { name: "sizeDeltaUsd", type: "uint256" },
      { name: "acceptablePrice", type: "uint256" },
      { name: "triggerPrice", type: "uint256" },
      { name: "minOutputAmount", type: "uint256" },
      { name: "validFromTime", type: "uint256" },
      { name: "autoCancel", type: "bool" },
    ],
  };

  const domain = getDomain(chainId, verifyingContract);
  const typedData = {
    account,
    key,
    params,
    userNonce,
    deadline,
    relayParams: hashRelayParams(relayParams),
    subaccountApproval: hashSubaccountApproval(subaccountApproval),
  };

  return signer._signTypedData(domain, types, typedData);
}

export async function sendCancelOrder(p: {
  sender: ethers.Signer;
  signer: ethers.Signer;
  oracleParams?: {
    tokens: string[];
    providers: string[];
    data: string[];
  };
  tokenPermits?: {
    token: string;
    spender: string;
    value: BigNumberish;
    nonce: BigNumberish;
    deadline: BigNumberish;
    chainId: BigNumberish;
  }[];
  feeParams: {
    feeToken: string;
    feeAmount: BigNumberish;
    feeSwapPath: string[];
  };
  subaccount: string;
  key: string;
  subaccountApproval: any;
  subaccountApprovalSigner: ethers.Signer;
  chainId: BigNumberish;
  account: string;
  deadline: BigNumberish;
  userNonce: BigNumberish;
  relayRouter: ethers.Contract;
  signature?: string;
  relayFeeToken: string;
  relayFeeAmount: BigNumberish;
}) {
  const relayParams = getRelayParams(p.oracleParams, p.tokenPermits, p.feeParams);

  if (!p.subaccountApproval) {
    p.subaccountApproval = getEmptySubaccountApproval();
  }
  if (!p.subaccountApproval.signature) {
    p.subaccountApproval.signature = await getSubaccountApprovalSignature({
      signer: p.subaccountApprovalSigner,
      chainId: p.chainId,
      verifyingContract: p.relayRouter.address,
      ...p.subaccountApproval,
    });
  }

  if (!p.signature) {
    p.signature = await getCancelOrderSignature({ ...p, relayParams, verifyingContract: p.relayRouter.address });
  }
  const updateOrderCalldata = p.relayRouter.interface.encodeFunctionData("cancelOrder", [
    relayParams,
    p.subaccountApproval,
    p.account,
    p.subaccount,
    p.key,
    p.userNonce,
    p.deadline,
    p.signature,
  ]);
  const calldata = ethers.utils.solidityPack(
    ["bytes", "address", "address", "uint256"],
    [updateOrderCalldata, GELATO_RELAY_ADDRESS, p.relayFeeToken, p.relayFeeAmount]
  );
  return p.sender.sendTransaction({
    to: p.relayRouter.address,
    data: calldata,
  });
}

async function getCancelOrderSignature({
  signer,
  relayParams,
  subaccountApproval,
  account,
  verifyingContract,
  key,
  deadline,
  userNonce,
  chainId,
}) {
  const types = {
    CancelOrder: [
      { name: "account", type: "address" },
      { name: "key", type: "bytes32" },
      { name: "userNonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
      { name: "relayParams", type: "bytes32" },
      { name: "subaccountApproval", type: "bytes32" },
    ],
  };

  const domain = getDomain(chainId, verifyingContract);
  const typedData = {
    account,
    key,
    userNonce,
    deadline,
    relayParams: hashRelayParams(relayParams),
    subaccountApproval: hashSubaccountApproval(subaccountApproval),
  };

  return signer._signTypedData(domain, types, typedData);
}

async function getSubaccountApprovalSignature(p: {
  signer: any;
  chainId: BigNumberish;
  verifyingContract: string;
  subaccount: string;
  expiresAt: BigNumberish;
  maxAllowedCount: BigNumberish;
  actionType: string;
  deadline: BigNumberish;
  nonce: BigNumberish;
}) {
  const domain = {
    name: "GmxBaseGelatoRelayRouter",
    version: "1",
    chainId: p.chainId,
    verifyingContract: p.verifyingContract,
  };

  const types = {
    SubaccountApproval: [
      { name: "subaccount", type: "address" },
      { name: "expiresAt", type: "uint256" },
      { name: "maxAllowedCount", type: "uint256" },
      { name: "actionType", type: "bytes32" },
      { name: "nonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  };

  const typedData = {
    subaccount: p.subaccount,
    expiresAt: p.expiresAt,
    maxAllowedCount: p.maxAllowedCount,
    actionType: p.actionType,
    deadline: p.deadline,
    nonce: p.nonce,
  };

  return p.signer._signTypedData(domain, types, typedData);
}
