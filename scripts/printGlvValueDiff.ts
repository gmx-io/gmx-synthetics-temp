import hre from "hardhat";

import { bigNumberify, formatAmount } from "../utils/math";
import { parseLogs } from "../utils/event";
import got from "got";

function getValues() {
  if (hre.network.name === "arbitrum") {
    return {
      explorerUrl:
        "https://api.arbiscan.io/api/?module=account&action=txlist&address=0x3f6df0c3a7221ba1375e87e7097885a601b41afc&startblock=1&endblock=484026324&page=1&sort=desc",
    };
  }

  throw new Error("Unsupported network");
}

async function main() {
  const dataStore = await hre.ethers.getContract("DataStore");
  const reader = await hre.ethers.getContract("Reader");
  const glvReader = await hre.ethers.getContract("GlvReader");
  const eventEmitter = await hre.ethers.getContract("EventEmitter");

  const maximize = process.env.MAXIMIZE === "true" ? true : false;
  const markets = await reader.getMarkets(dataStore.address, 0, 100);
  const marketToIndexToken = Object.fromEntries(markets.map((market) => [market.marketToken, market.indexToken]));

  const { explorerUrl } = getValues();
  const response = await got.get(explorerUrl);
  const txs = JSON.parse(response.body).result.filter((tx) => {
    return tx.functionName.includes("executeGlvShift") && tx.txreceipt_status === "1";
  });

  console.log("found %s txs", txs.length);

  const totalDiff = {};

  for (const tx of txs) {
    const txHash = tx.hash;
    // for (const txHash of ["0x2e280c6c83d1c79bc4b604f90527267ddd987960de5ec0d4d05a6a8e9af9d9d0"]) {
    // console.log("processing %s", tx.hash);
    const receipt = await hre.ethers.provider.getTransactionReceipt(txHash);
    const parsedLogs = parseLogs({ contracts: { eventEmitter } }, receipt);
    const prices = {};
    let glvToken: string;
    let cancelled = false;

    for (const log of parsedLogs) {
      if (!log.parsedEventData) {
        continue;
      }
      const eventName = log.parsedEventInfo.eventName;
      const data = log.parsedEventData;
      if (eventName === "GlvValueUpdated") {
        glvToken = data.glv;
      } else if (eventName === "OraclePriceUpdate") {
        prices[data.token] = { min: data.minPrice, max: data.maxPrice };
      } else if (eventName === "GlvShiftCancelled") {
        cancelled = true;
        break;
      }
    }

    if (cancelled) {
      console.log("cancelled at %s", txHash);
      continue;
    }

    const glvInfo = await glvReader.getGlvInfo(dataStore.address, glvToken, { blockTag: receipt.blockNumber });
    const longTokenPrice = prices[glvInfo.glv.longToken];
    const shortTokenPrice = prices[glvInfo.glv.shortToken];
    const indexTokenPrices = glvInfo.markets.map((marketToken) => {
      const indexToken = marketToIndexToken[marketToken];
      if (!indexToken) {
        throw new Error(`index token not found for market token ${marketToken}`);
      }
      if (!prices[indexToken]) {
        throw new Error(`index token price not found for ${indexToken}`);
      }
      return prices[indexToken];
    });

    const [[, glvValueBefore], [, glvValueAfter]] = await Promise.all([
      glvReader.getGlvTokenPrice(
        dataStore.address,
        glvInfo.markets,
        indexTokenPrices,
        longTokenPrice,
        shortTokenPrice,
        glvToken,
        maximize,
        { blockTag: receipt.blockNumber - 1 }
      ),
      glvReader.getGlvTokenPrice(
        dataStore.address,
        glvInfo.markets,
        indexTokenPrices,
        longTokenPrice,
        shortTokenPrice,
        glvToken,
        maximize,
        { blockTag: receipt.blockNumber }
      ),
    ]);
    totalDiff[glvToken] = totalDiff[glvToken] ?? bigNumberify(0);
    totalDiff[glvToken] = totalDiff[glvToken].add(glvValueAfter.sub(glvValueBefore));
    console.log(
      "receipt.blockNumber %s tx %s (%s) glv %s value before %s after %s diff %s cumulative diff %s",
      receipt.blockNumber,
      txHash,
      new Date(tx.timeStamp * 1000).toISOString(),
      glvToken,
      formatAmount(glvValueBefore, 30, 10, true),
      formatAmount(glvValueAfter, 30, 10, true),
      formatAmount(glvValueAfter.sub(glvValueBefore), 30, 10, true),
      formatAmount(totalDiff[glvToken], 30, 10, true)
    );
  }

  for (const [glvToken, diff] of Object.entries(totalDiff) as any) {
    console.log("glv %s total diff %s", glvToken, formatAmount(diff, 30, 10));
  }
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((ex) => {
    console.error(ex);
    process.exit(1);
  });
