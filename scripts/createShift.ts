import hre from "hardhat";
import { ExchangeRouter, ShiftVault } from "../typechain-types";
import { BigNumber, constants } from "ethers";
import { expandDecimals } from "../utils/math";

const { ethers } = hre;

const amountToSend = process.env.AMOUNT ? BigNumber.from(process.env.AMOUNT) : BigNumber.from(10000); // 0.00000000000001
const minMarketTokens = process.env.MIN_MARKET_TOKENS
  ? BigNumber.from(process.env.MIN_MARKET_TOKENS)
  : BigNumber.from(1);

function getArgs() {
  switch (hre.network.name) {
    case "avalancheFuji": {
      return {
        fromMarket: "0xbf338a6C595f06B7Cfff2FA8c958d49201466374", // ETH/USD [ETH-USDC]
        toMarket: "0xEDF9Be35bE84cD1e39Bda59Bd7ae8A704C12e06f", // SOL/USD [ETH-USDC]
      };
    }

    default:
      throw new Error("unsupported network");
  }
}

async function main() {
  const [wallet] = await ethers.getSigners();
  const { fromMarket, toMarket } = getArgs();
  const executionFee = expandDecimals(1, 17); // 0.1 WNT

  const exchangeRouter: ExchangeRouter = await ethers.getContract("ExchangeRouter");
  const shiftVault: ShiftVault = await ethers.getContract("ShiftVault");

  const multicallArgs = [
    exchangeRouter.interface.encodeFunctionData("sendTokens", [fromMarket, shiftVault.address, amountToSend]),
    exchangeRouter.interface.encodeFunctionData("sendWnt", [shiftVault.address, executionFee]),
    exchangeRouter.interface.encodeFunctionData("createShift", [
      {
        receiver: wallet.address,
        callbackContract: constants.AddressZero,
        uiFeeReceiver: constants.AddressZero,
        fromMarket,
        toMarket,
        minMarketTokens,
        executionFee,
        callbackGasLimit: BigNumber.from(0),
        dataList: [],
      },
    ]),
  ];
  console.log("multicall args", multicallArgs);

  const tx = await exchangeRouter.multicall(multicallArgs, {
    value: executionFee,
    gasLimit: 2500000,
  });

  console.log("transaction sent", tx.hash);
  await tx.wait();
  console.log("receipt received");
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((ex) => {
    console.error(ex);
    process.exit(1);
  });
