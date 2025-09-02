import { Router } from "express";
import path from "path";
import fs from "fs";
import { livenessProbe, readinessProbe } from "./health";

const router = Router();

router.get("/health", (req, res) => {
    res.json({ status: "ok", timestamp: new Date() });
});

/**
 * Liveness probe endpoint - confirms the process is running
 * Returns 200 OK if the application process is alive
 * Used by orchestrators (Kubernetes, Docker) to determine if the container should be restarted
 */
router.get("/healthz", (req, res) => {
  try {
    const health = livenessProbe();
    
    // Liveness probe should always return 200 if the process is running
    res.status(200).json(health);
  } catch (err: any) {
    // If we can't even execute the liveness probe, the app is in a bad state
    res.status(503).json({
      success: false,
      status: "unhealthy",
      error: err.message
    });
  }
});

/**
 * Readiness probe endpoint - confirms dependencies are ready
 * Returns 200 OK only when all dependencies (DB, APIs, configs) are available
 * Used by orchestrators to determine if the container can receive traffic
 */
router.get("/readyz", async (req, res) => {
  try {
    const readiness = await readinessProbe();
    
    // Return 200 if ready, 503 if not ready
    const statusCode = readiness.success ? 200 : 503;
    res.status(statusCode).json(readiness);
  } catch (err: any) {
    // Error checking readiness
    res.status(503).json({
      success: false,
      status: "not_ready",
      error: err.message
    });
  }
});

router.get("/metrics", (req, res) => {
  const logFile = path.join(__dirname, "../logs/output.log");

  let heartbeatCount = 0;
  let lastTimestamp = null;

  try {
    const lines = fs.readFileSync(logFile, "utf-8")
      .trim()
      .split("\n")
      .filter(line => line.includes("[heartbeat]"));

    heartbeatCount = lines.length;

    if (heartbeatCount > 0) {
      const lastLine = lines[heartbeatCount - 1];
      const match = lastLine.match(/\[heartbeat\] (.+)/);
      if (match) {
        lastTimestamp = new Date(match[1]);
      }
    }

    const now = new Date();
    const secondsSinceLast = lastTimestamp ? Math.floor((now.getTime() - lastTimestamp.getTime()) / 1000) : -1;

    // System resource metrics
    const memoryUsage = process.memoryUsage(); // in bytes
    const cpuUsage = process.cpuUsage();       // in microseconds

    res.set("Content-Type", "text/plain");
    res.send(
`# HELP swap_optimizer_heartbeat_count Total number of heartbeats recorded
# TYPE swap_optimizer_heartbeat_count counter
swap_optimizer_heartbeat_count ${heartbeatCount}

# HELP swap_optimizer_last_heartbeat_seconds Seconds since last heartbeat
# TYPE swap_optimizer_last_heartbeat_seconds gauge
swap_optimizer_last_heartbeat_seconds ${secondsSinceLast}

# HELP swap_optimizer_memory_rss_bytes Resident Set Size memory
# TYPE swap_optimizer_memory_rss_bytes gauge
swap_optimizer_memory_rss_bytes ${memoryUsage.rss}

# HELP swap_optimizer_memory_heap_used_bytes Heap memory used
# TYPE swap_optimizer_memory_heap_used_bytes gauge
swap_optimizer_memory_heap_used_bytes ${memoryUsage.heapUsed}

# HELP swap_optimizer_cpu_user_usec User-space CPU time (microseconds)
# TYPE swap_optimizer_cpu_user_usec counter
swap_optimizer_cpu_user_usec ${cpuUsage.user}

# HELP swap_optimizer_cpu_system_usec Kernel-space CPU time (microseconds)
# TYPE swap_optimizer_cpu_system_usec counter
swap_optimizer_cpu_system_usec ${cpuUsage.system}`
    );
  } catch (err: any) {
    res.status(500).send(`# ERROR reading logs: ${err.message}`);
  }
});

export default router;