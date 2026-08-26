"use strict";

const crypto = require("node:crypto");
const express = require("express");
const cors = require("cors");

const { load } = require("./src/config");
const { createLogger } = require("./src/logger");
const { startTelemetry } = require("./src/telemetry");
const { createDatabase } = require("./src/db");
const { createProjectsRouter } = require("./src/routes/projects");
const { createHealthRouter } = require("./src/routes/health");

function buildApp(config, db, logger, state) {
  const app = express();
  app.disable("x-powered-by");
  app.set("trust proxy", true);

  app.use((req, res, next) => {
    req.id = req.headers["x-request-id"] || crypto.randomUUID();
    res.setHeader("x-request-id", req.id);
    next();
  });

  const corsOptions = {
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      const candidate = origin.trim().replace(/\/+$/, "").toLowerCase();
      if (config.allowedOrigins.includes(candidate)) return callback(null, true);
      logger.warn("CORS origin rejected", { origin });
      return callback(null, false);
    },
    methods: ["GET", "OPTIONS"],
    maxAge: 600
  };
  app.use(cors(corsOptions));

  app.use(createHealthRouter(db, logger, state));
  app.use("/api", createProjectsRouter(db, logger));

  app.use((req, res) => {
    res.status(404).json({ error: "not_found", path: req.path, requestId: req.id });
  });

  app.use((error, req, res, next) => {
    logger.error("unhandled request error", {
      requestId: req.id,
      error: error.message
    });
    res.status(500).json({ error: "internal_error", requestId: req.id });
  });

  return app;
}

function start() {
  const state = { shuttingDown: false };
  let config;
  const bootLogger = createLogger(process.env.LOG_LEVEL || "info");

  try {
    config = load();
  } catch (error) {
    bootLogger.error("startup configuration invalid", { error: error.message });
    process.exit(1);
  }

  const logger = createLogger(config.logLevel);
  startTelemetry(config.telemetryConnectionString, logger);

  const db = createDatabase(config.sql, logger);
  const app = buildApp(config, db, logger, state);

  const server = app.listen(config.port, () => {
    logger.info("api listening", {
      port: config.port,
      env: config.env,
      allowedOrigins: config.allowedOrigins,
      managedIdentity: config.sql.useManagedIdentity
    });
  });

  async function shutdown(signal) {
    if (state.shuttingDown) return;
    state.shuttingDown = true;
    logger.info("shutdown started", { signal });

    const timer = setTimeout(() => {
      logger.warn("shutdown timed out; forcing exit");
      process.exit(1);
    }, config.shutdownTimeoutMs);
    timer.unref();

    server.close(async () => {
      await db.close();
      logger.info("shutdown complete");
      process.exit(0);
    });
  }

  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("unhandledRejection", (reason) => {
    logger.error("unhandled promise rejection", { error: String(reason) });
  });

  return { server, db };
}

if (require.main === module) {
  start();
}

module.exports = { buildApp, start };
