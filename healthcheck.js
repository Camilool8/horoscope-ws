#!/usr/bin/env node

/**
 * Health check endpoint and script for Docker and Kubernetes
 */

const express = require("express");
const fs = require("fs").promises;
const path = require("path");

const app = express();
const port = process.env.HEALTH_PORT || 3000;

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
    service: "horoscope-whatsapp-bot",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: require("./package.json").version,
  });
});

app.get("/ready", async (req, res) => {
  try {
    const authPath = "./.wwebjs_auth";

    try {
      await fs.access(authPath);
      const stats = await fs.stat(authPath);

      res.status(200).json({
        status: "ready",
        service: "horoscope-whatsapp-bot",
        sessionExists: stats.isDirectory(),
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      res.status(200).json({
        status: "ready",
        service: "horoscope-whatsapp-bot",
        sessionExists: false,
        message: "Waiting for WhatsApp authentication",
        timestamp: new Date().toISOString(),
      });
    }
  } catch (error) {
    res.status(503).json({
      status: "not ready",
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.get("/status", async (req, res) => {
  try {
    const authPath = "./.wwebjs_auth";
    const logsPath = "./logs";

    let sessionInfo = { exists: false };
    let logsInfo = { exists: false, lastMessage: null };

    try {
      await fs.access(authPath);
      const sessionStats = await fs.stat(authPath);
      sessionInfo = {
        exists: true,
        isDirectory: sessionStats.isDirectory(),
        created: sessionStats.birthtime,
        modified: sessionStats.mtime,
      };
    } catch (error) {}

    try {
      await fs.access(logsPath);
      const logFile = path.join(logsPath, "horoscope-messages.log");

      try {
        const logStats = await fs.stat(logFile);
        logsInfo = {
          exists: true,
          lastModified: logStats.mtime,
          size: logStats.size,
        };
      } catch (error) {
        logsInfo.exists = false;
      }
    } catch (error) {}

    res.status(200).json({
      status: "ok",
      service: "horoscope-whatsapp-bot",
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: require("./package.json").version,
      session: sessionInfo,
      logs: logsInfo,
      environment: {
        nodeEnv: process.env.NODE_ENV,
        timezone: process.env.TZ,
        sendTime: process.env.SEND_TIME,
      },
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

app.get("/metrics", (req, res) => {
  const metrics = {
    uptime_seconds: process.uptime(),
    memory_usage_bytes: process.memoryUsage().heapUsed,
    memory_total_bytes: process.memoryUsage().heapTotal,
    cpu_usage_percent: process.cpuUsage(),
    timestamp: Date.now(),
  };

  res.status(200).json(metrics);
});

if (require.main === module) {
  if (process.argv.includes("--health-check")) {
    const http = require("http");

    const options = {
      hostname: "localhost",
      port: port,
      path: "/health",
      method: "GET",
      timeout: 5000,
    };

    const req = http.request(options, (res) => {
      if (res.statusCode === 200) {
        console.log("✅ Health check passed");
        process.exit(0);
      } else {
        console.log(`❌ Health check failed with status: ${res.statusCode}`);
        process.exit(1);
      }
    });

    req.on("error", (error) => {
      console.log(`❌ Health check failed: ${error.message}`);
      process.exit(1);
    });

    req.on("timeout", () => {
      console.log("❌ Health check timeout");
      req.destroy();
      process.exit(1);
    });

    req.end();
  } else {
    app.listen(port, "0.0.0.0", () => {
      console.log(`🏥 Health check server running on port ${port}`);
      console.log(`📍 Endpoints:`);
      console.log(`   GET /health  - Basic health check`);
      console.log(`   GET /ready   - Readiness check`);
      console.log(`   GET /status  - Detailed status`);
      console.log(`   GET /metrics - Performance metrics`);
    });

    process.on("SIGTERM", () => {
      console.log("🛑 Health check server shutting down...");
      process.exit(0);
    });
  }
}

module.exports = app;
