import hre from "hardhat";
const { ethers } = hre;

if (!process.env.ORDER_KEY) {
  throw new Error("missing ORDER_KEY");
}

async function main() {
  const exchangeRouter = await ethers.getContract("ExchangeRouter");

  const tx = await exchangeRouter.cancelOrder(process.env.ORDER_KEY, { gasLimit: 15000000 });
  console.log("tx %s", tx.hash);
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((ex) => {
    console.error(ex);
    process.exit(1);
  });
