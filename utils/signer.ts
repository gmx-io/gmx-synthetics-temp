import express from "express";
import cors from "cors";
import bodyParser from "body-parser";
import { hashString } from "./hash";

const unsignedTransactionList = [];
const signedTransactions = {};

let app;

// to sign using an external wallet:
// - run `yarn app`
// - go to http://localhost:5173/signer
// - connect a wallet and click on the "Sign" button

export async function createSigningServer() {
  if (app) {
    return;
  }

  const port = 3030;

  app = express();
  app.use(cors());
  app.use(bodyParser.urlencoded({ extended: false }));
  app.use(bodyParser.json());

  const server = app.listen(port, () => {
    console.info(`server started at port ${port}`);
  });

  app.get("/", (req, res) => {
    res.contentType("text/plain");
    res.send(
      JSON.stringify({
        unsignedTransactionList,
        signedTransactions,
      })
    );
  });

  app.post("/completed", (req, res) => {
    console.info("transaction completed", JSON.stringify(req.body));
    signedTransactions[req.body.transactionKey] = req.body.transactionHash;
    res.send("ok");

    let hasPendingTransaction = false;
    for (const [index, { transactionKey }] of unsignedTransactionList.entries()) {
      if (signedTransactions[transactionKey] === undefined) {
        console.info(`pending transaction at index ${index}`);
        hasPendingTransaction = true;
        break;
      }
    }

    if (!hasPendingTransaction) {
      console.info("no pending transactions left, closing server");
      server.close();
      process.exit(1);
    }
  });
}

export async function signExternally(unsignedTransaction) {
  createSigningServer();

  unsignedTransaction.chainId = hre.network.config.chainId;

  const unsignedTransactionStr = JSON.stringify(unsignedTransaction);
  const transactionKey = hashString(unsignedTransactionStr);
  unsignedTransactionList.push({ transactionKey, unsignedTransaction, timestamp: Date.now() });

  console.info("Transaction to be signed: ", unsignedTransactionStr);
}

export async function getFrameSigner() {
  try {
    const frame = new ethers.providers.JsonRpcProvider("http://127.0.0.1:1248");
    const signer = frame.getSigner();
    if (hre.network.config.chainId !== (await signer.getChainId())) {
      throw new Error("Incorrect frame network");
    }

    return signer;
  } catch (e) {
    throw new Error(`getFrameSigner error: ${e.toString()}`);
  }
}
