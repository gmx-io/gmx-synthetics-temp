import fs from "fs";
import { BigNumber } from "ethers";

import { globSync } from "glob";
import prompts from "prompts";
import hre, { ethers } from "hardhat";
import { range } from "lodash";
import { bigNumberify, formatAmount } from "../../utils/math";
import path from "path";
import BatchSenderAbi from "./abi/BatchSender";
import { getChainId, getDistributionTypeName } from "./helpers";
import { setTimeout } from "timers/promises";

/*
Example of usage:

FILENAME=distribution_2023-10-18.json npx hardhat --network arbitrum run batchSend.ts
*/

let write = process.env.WRITE === "true";

function getArbValues() {
  return {
    batchSenderAddress: "0x5384E6cAd96B2877B5B3337A277577053BD1941D",
  };
}

function getAvaxValues() {
  return {
    batchSenderAddress: "0x0BEa5D3081921A08d73f150126f99cda0eb29C0e",
  };
}

function getValues() {
  if (hre.network.name === "arbitrum") {
    return getArbValues();
  } else if (hre.network.name === "avalanche") {
    return getAvaxValues();
  }

  throw new Error(`unsupported network ${hre.network.name}`);
}

async function main() {
  const { data, distributionTypeName } = await readDistributionFile();

  const migrations = readMigrations();
  if (migrations[data.id] && !process.env.SKIP_MIGRATION_VALIDATION) {
    throw new Error(
      `Distribution ${data.id} was already sent. Run with SKIP_MIGRATION_VALIDATION=1 if this is expected`
    );
  }

  if (!process.env.BATCH_SENDER_KEY) {
    throw new Error("BATCH_SENDER_KEY is required");
  }

  const wallet = new ethers.Wallet(process.env.BATCH_SENDER_KEY);
  const signer = wallet.connect(ethers.provider);

  if (write) {
    console.warn("WARN: sending real transaction...");
    await setTimeout(5000);
  }

  const { batchSenderAddress } = getValues();

  const amounts: BigNumber[] = [];
  const recipients: string[] = [];
  let totalAmount = bigNumberify(0);

  for (const [recipient, amount] of Object.entries(data.amounts)) {
    amounts.push(bigNumberify(amount));
    recipients.push(recipient);
    totalAmount = totalAmount.add(amount);
  }

  console.log("token %s", data.token);
  console.log("total amount %s (%s)", formatAmount(totalAmount, 18, 2, true), totalAmount.toString());
  console.log("recipients %s", recipients.length);
  console.log("distribution type %s %s", data.distributionTypeId, distributionTypeName);

  const signerAddress = await signer.getAddress();
  console.log("signer address: %s", signerAddress);

  const batchSender = await ethers.getContractAt(BatchSenderAbi, batchSenderAddress, signer);
  const tokenContract = await ethers.getContractAt("MintableToken", data.token, signer);
  const batchSize = 150;

  const balance = await tokenContract.balanceOf(signerAddress);
  if (balance.lt(totalAmount)) {
    throw new Error(
      `Current balance ${formatAmount(balance, 18, 2, true)} is lower than required ${formatAmount(
        totalAmount,
        18,
        2,
        true
      )}`
    );
  }
  console.log("balance is %s", formatAmount(balance, 18, 2, true));

  const allowance = await tokenContract.allowance(signerAddress, batchSenderAddress);
  console.log("total amount to send: %s", formatAmount(totalAmount, 18, 2, true));
  console.log("current allowance is %s", formatAmount(allowance, 18, 2, true));
  if (allowance.lt(totalAmount)) {
    console.log(
      "approving token %s amount %s spender %s",
      data.token,
      formatAmount(totalAmount, 18, 2),
      batchSenderAddress
    );
    const tx = await tokenContract.approve(batchSenderAddress, totalAmount);
    console.log("sent approve txn %s, waiting...", tx.hash);
    await tx.wait();
    console.log("done");
  }

  const seenRecipients = new Set();
  for (const recipient of recipients) {
    if (seenRecipients.has(recipient)) {
      throw new Error(`Duplicated recipient ${recipient}`);
    }
    seenRecipients.add(recipient);
  }

  const txHashes = [];
  const batchesInProgress = readBatchesInProgress(data.id);
  const batchesCount = Math.ceil(amounts.length / batchSize);
  const lastSentBatchIndex = batchesInProgress[data.id].lastSentBatchIndex;

  const firstRecipientIndex = (lastSentBatchIndex + 1) * batchSize;
  if (lastSentBatchIndex >= 0) {
    const firstRecipientIndex = (lastSentBatchIndex + 1) * batchSize;
    const firstRecipient = recipients[firstRecipientIndex];
    console.warn(
      "WARN: lastSentBatchIndex is %s, starting from index %s, first recipient: %s (%s)",
      lastSentBatchIndex,
      lastSentBatchIndex + 1,
      firstRecipientIndex,
      firstRecipient
    );
    await setTimeout(5000);
  }

  const batches = [];
  for (const batchIndex of range(lastSentBatchIndex + 1, batchesCount)) {
    const from = batchIndex * batchSize;
    const to = Math.min(from + batchSize, amounts.length);
    const batchAmounts = amounts.slice(from, to);
    const batchRecipients = recipients.slice(from, to);
    batches.push({
      from,
      to,
      batchAmounts,
      batchRecipients,
      batchIndex,
    });
  }

  console.log("running simulation");
  for (const [i, { batchIndex, from, to, batchAmounts, batchRecipients }] of batches.entries()) {
    console.log("simulating sending batch %s-%s token %s typeId %s", from, to, data.token, data.distributionTypeId);

    for (const [j, recipient] of batchRecipients.entries()) {
      console.log(
        "%s recipient %s amount %s (%s)",
        firstRecipientIndex + i * batchSize + j,
        recipient,
        formatAmount(batchAmounts[j], 18, 2, true),
        batchAmounts[j]
      );
    }

    const result = await batchSender.callStatic.sendAndEmit(
      data.token,
      batchRecipients,
      batchAmounts,
      data.distributionTypeId
    );
    console.log("simulation batch %s done, result %s", batchIndex, result);
  }

  if (!write) {
    ({ write } = await prompts({
      type: "confirm",
      name: "write",
      message: "Do you want to execute the transactions?",
    }));
  }

  if (write) {
    for (const [i, { batchIndex, from, to, batchAmounts, batchRecipients }] of batches.entries()) {
      console.log("sending batch %s-%s token %s typeId %s", from, to, data.token, data.distributionTypeId);

      for (const [j, recipient] of batchRecipients.entries()) {
        console.log(
          "%s recipient %s amount %s (%s)",
          firstRecipientIndex + i * batchSize + j,
          recipient,
          formatAmount(batchAmounts[j], 18, 2, true),
          batchAmounts[j]
        );
      }

      const gasLimit = await batchSender.estimateGas.sendAndEmit(
        data.token,
        batchRecipients,
        batchAmounts,
        data.distributionTypeId
      );

      const tx = await batchSender.sendAndEmit(data.token, batchRecipients, batchAmounts, data.distributionTypeId, {
        gasLimit: gasLimit.add(1_000_000),
      });
      console.log("sent batch txn %s, waiting...", tx.hash);
      txHashes.push(tx.hash);
      await tx.wait();
      console.log("batch %s done", batchIndex);

      batchesInProgress[data.id].lastSentBatchIndex = batchIndex;
      saveBatchesInProgress(batchesInProgress);
    }

    if (txHashes.length) {
      console.log("sent %s transactions:", txHashes.length);
      for (const txHash of txHashes) {
        console.log(txHash);
      }
    }

    migrations[data.id] = Math.floor(Date.now() / 1000);
    saveMigrations(migrations);
    delete batchesInProgress[data.id];
    saveBatchesInProgress(batchesInProgress);
  } else {
    console.warn("WARN: read-only mode. skip sending transaction");
  }
}

type Migrations = Record<string, number>;

function getMigrationsFilepath() {
  return path.join(__dirname, ".migrations.json");
}

function saveMigrations(migrations: Migrations) {
  const filepath = getMigrationsFilepath();
  console.log("writing migrations %j to file %s", migrations, filepath);
  fs.writeFileSync(filepath, JSON.stringify(migrations, null, 4));
}

function readMigrations(): Migrations {
  const filepath = getMigrationsFilepath();
  if (!fs.existsSync(filepath)) {
    return {};
  }
  const content = fs.readFileSync(filepath);
  return JSON.parse(content.toString());
}

type BatchesInProgress = Record<string, { lastSentBatchIndex: number }>;

function getBatchesInProgressFilepath(): string {
  return path.join(__dirname, ".batchesInProgress.json");
}

function saveBatchesInProgress(batches: BatchesInProgress) {
  const filepath = getBatchesInProgressFilepath();
  console.log("writing batches in progress %j to file %s", batches, filepath);
  fs.writeFileSync(filepath, JSON.stringify(batches, null, 4));
}

function readBatchesInProgress(dataId: string): BatchesInProgress {
  const filepath = getBatchesInProgressFilepath();
  let ret: BatchesInProgress = {};
  if (fs.existsSync(filepath)) {
    const content = fs.readFileSync(filepath);
    ret = JSON.parse(content.toString());
  }
  if (dataId in ret) {
    if (!("lastSentBatchIndex" in ret[dataId])) {
      throw new Error("`lastSentBatchIndex` is missing");
    }
    if (ret[dataId].lastSentBatchIndex < 0) {
      throw new Error("`lastSentBatchIndex` should be greater or equal to zero");
    }
  } else {
    ret[dataId] = {
      lastSentBatchIndex: -1, // -1 means no batches were sent before
    };
  }
  return ret;
}

async function readDistributionFile() {
  let filepath: string;
  if (process.env.FILENAME) {
    const filename = process.env.FILENAME;
    filepath = filename.startsWith("/") ? filename : path.join(process.cwd(), filename);
  } else {
    const files = globSync(`${__dirname}/distributions/*/*.json`).filter((file) => {
      return file.includes(hre.network.name);
    });
    ({ filepath } = await prompts({
      type: "select",
      name: "filepath",
      message: "Select distribution file",
      choices: files.map((file) => ({ title: file.split("/distributions/")[1], value: file })),
    }));
  }

  console.log("reading file %s", filepath);
  const data: {
    token: string;
    amounts: Record<string, string>;
    chainId: number;
    distributionTypeId: number;
    id: string;
  } = JSON.parse(fs.readFileSync(filepath).toString());

  if (!data.token) {
    throw new Error("Invalid file format. It should contain `token` string");
  }
  if (!data.amounts || typeof data.amounts !== "object") {
    throw new Error("Invalid file format. It should contain `amounts` object");
  }
  if (!data.distributionTypeId) {
    throw new Error("Invalid file format. It should contain `distributionTypeId` number");
  }
  const distributionTypeName = getDistributionTypeName(data.distributionTypeId);
  if (!distributionTypeName) {
    throw new Error(`Unknown distribution type id ${data.distributionTypeId}`);
  }
  if (!data.id) {
    throw new Error("Invalid file format. It should contain `id` string");
  }
  if (data.chainId !== getChainId()) {
    throw new Error(`Invalid current chain id: ${getChainId()}, distribution chain id: ${data.chainId}`);
  }

  return {
    data,
    distributionTypeName,
  };
}

if (require.main === module) {
  main()
    .then(() => {
      console.log("done");
      process.exit(0);
    })
    .catch((ex) => {
      console.error(ex);
      process.exit(1);
    });
}
