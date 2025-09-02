import { ethers } from "ethers";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

dotenv.config();

// Application start time for uptime calculation
const appStartTime = Date.now();

// Track readiness state
let isReady = false;
let readinessDetails: {
  ethereum?: boolean;
  environment?: boolean;
  filesystem?: boolean;
  errorMessage?: string;
} = {};

/**
 * Initialize readiness checks
 */
export async function initializeReadiness() {
  try {
    // Check environment variables
    readinessDetails.environment = !!process.env.INFURA_URL;
    
    // Check filesystem (logs directory)
    const logsDir = path.join(__dirname, "../logs");
    readinessDetails.filesystem = fs.existsSync(logsDir);
    
    // Check Ethereum connection
    if (process.env.TEST_MODE === 'true') {
      // In test mode, skip Ethereum connection check
      readinessDetails.ethereum = true;
      readinessDetails.errorMessage = "Test mode - Ethereum connection skipped";
    } else if (process.env.INFURA_URL) {
      const provider = new ethers.JsonRpcProvider(process.env.INFURA_URL);
      try {
        const blockNumber = await provider.getBlockNumber();
        readinessDetails.ethereum = blockNumber > 0;
      } catch (error) {
        readinessDetails.ethereum = false;
        readinessDetails.errorMessage = `Ethereum connection failed: ${error}`;
      }
    } else {
      readinessDetails.ethereum = false;
      readinessDetails.errorMessage = "INFURA_URL not configured";
    }
    
    // Set overall readiness - in test mode, only require environment and filesystem
    if (process.env.TEST_MODE === 'true') {
      isReady = readinessDetails.environment && readinessDetails.filesystem;
    } else {
      isReady = readinessDetails.environment && 
                readinessDetails.filesystem && 
                readinessDetails.ethereum;
    }
    
    return isReady;
  } catch (error) {
    readinessDetails.errorMessage = `Readiness check failed: ${error}`;
    isReady = false;
    return false;
  }
}

/**
 * Liveness probe handler - confirms the process is running
 * Should always return success if the process is alive
 */
export function livenessProbe() {
  const uptime = Math.floor((Date.now() - appStartTime) / 1000);
  const memoryUsage = process.memoryUsage();
  
  return {
    success: true,
    status: "healthy",
    timestamp: new Date().toISOString(),
    uptime_seconds: uptime,
    uptime_formatted: formatUptime(uptime),
    pid: process.pid,
    memory: {
      rss_mb: Math.round(memoryUsage.rss / 1024 / 1024),
      heap_used_mb: Math.round(memoryUsage.heapUsed / 1024 / 1024),
      heap_total_mb: Math.round(memoryUsage.heapTotal / 1024 / 1024)
    },
    node_version: process.version
  };
}

/**
 * Readiness probe handler - confirms dependencies are ready
 * Returns false until all dependencies are available
 */
export async function readinessProbe() {
  // Re-check readiness if not ready
  if (!isReady) {
    await initializeReadiness();
  }
  
  const uptime = Math.floor((Date.now() - appStartTime) / 1000);
  
  const response: any = {
    success: isReady,
    status: isReady ? "ready" : "not_ready",
    timestamp: new Date().toISOString(),
    uptime_seconds: uptime,
    uptime_formatted: formatUptime(uptime),
    checks: {
      environment: {
        status: readinessDetails.environment ? "pass" : "fail",
        message: readinessDetails.environment ? "Environment variables configured" : "Missing required environment variables"
      },
      filesystem: {
        status: readinessDetails.filesystem ? "pass" : "fail",
        message: readinessDetails.filesystem ? "Logs directory accessible" : "Logs directory not accessible"
      },
      ethereum: {
        status: readinessDetails.ethereum ? "pass" : "fail",
        message: readinessDetails.ethereum ? "Ethereum provider connected" : (readinessDetails.errorMessage || "Ethereum provider not connected")
      }
    }
  };
  
  // Check latest heartbeat if filesystem is available
  if (readinessDetails.filesystem) {
    try {
      const logFile = path.join(__dirname, "../logs/output.log");
      if (fs.existsSync(logFile)) {
        const logContent = fs.readFileSync(logFile, "utf-8");
        const lines = logContent.trim().split("\n");
        const lastHeartbeat = lines.reverse().find(line => line.includes("[heartbeat]"));
        
        if (lastHeartbeat) {
          const match = lastHeartbeat.match(/\[heartbeat\] (.+)/);
          if (match) {
            const heartbeatTime = new Date(match[1]);
            const secondsSinceHeartbeat = Math.floor((Date.now() - heartbeatTime.getTime()) / 1000);
            
            response.checks.heartbeat = {
              status: secondsSinceHeartbeat < 10 ? "pass" : "warn",
              message: `Last heartbeat ${secondsSinceHeartbeat}s ago`,
              last_heartbeat: heartbeatTime.toISOString()
            };
          }
        }
      }
    } catch (error) {
      // Heartbeat check is optional, don't fail readiness
      response.checks.heartbeat = {
        status: "unknown",
        message: "Could not check heartbeat"
      };
    }
  }
  
  return response;
}

/**
 * Format uptime in human-readable format
 */
function formatUptime(seconds: number): string {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  
  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  if (minutes > 0) parts.push(`${minutes}m`);
  parts.push(`${secs}s`);
  
  return parts.join(" ");
}

/**
 * Set readiness state (for testing or manual control)
 */
export function setReadiness(ready: boolean) {
  isReady = ready;
}

export default {
  livenessProbe,
  readinessProbe,
  initializeReadiness,
  setReadiness
};
