import dotenv from "dotenv";
import express from "express";
import { ethers } from "ethers";
import fs from "fs";
import { formatDuration } from "./utils";
import { logAllPaths } from "./graph";
import router from "./routes";
import apiRouter from "./api";
import { initializeReadiness } from "./health";

dotenv.config();

const app = express();
app.use(express.json());
app.use("/api", apiRouter);
app.use("/", router);

const port = process.env.port || 3000;

const provider = new ethers.JsonRpcProvider(process.env.INFURA_URL);

function internalLogger() {
    const stream = fs.createWriteStream("logs/output.log", { flags: "a"});
    let counter = 0;
    const interval = setInterval(() => {
    stream.write(`[heartbeat] ${new Date().toISOString()}\n`);
    counter++;
    if (counter >= 6) {
      stream.end(); // silent failure after 30 seconds
      clearInterval(interval);
    }
  }, 5000);
}

async function main() {
    let uptime = 0;

    // Initialize health check readiness
    console.log("[INIT] Initializing health check readiness...");
    const isReady = await initializeReadiness();
    if (isReady) {
        console.log("[READY] All health checks passed - application is ready");
    } else {
        console.log("[WARNING] Some health checks failed - application may not be fully ready");
    }

    setInterval(() => {
        uptime++;
        process.stdout.write(`\r[status] Server running... ${formatDuration(uptime)} uptime`);
    }, 1000);

    internalLogger();

    const blockNumber = await provider.getBlockNumber();
    console.log(`Connected to Ethereum. Latest block: ${blockNumber}`);

    await logAllPaths(provider);
    setInterval(() => logAllPaths(provider), 60 * 1000);
}

app.listen(port, () => {
    console.log(`Server listening on port ${port}`);
    console.log(`Health check (liveness): http://localhost:${port}/healthz`);
    console.log(`Readiness check: http://localhost:${port}/readyz`);
});

main().catch(error => {
    console.error("[ERROR] Failed to start application:", error);
    process.exit(1);
});
