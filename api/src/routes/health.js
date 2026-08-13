"use strict";

const express = require("express");

function createHealthRouter(db, logger, state) {
  const router = express.Router();

  router.get("/health", (req, res) => {
    res.json({
      status: state.shuttingDown ? "draining" : "ok",
      uptimeSeconds: Math.round(process.uptime()),
      version: process.env.APP_VERSION || "2.0.0"
    });
  });

  router.get("/ready", async (req, res) => {
    if (state.shuttingDown) {
      return res.status(503).json({ status: "draining" });
    }

    try {
      await db.ping();
      return res.json({ status: "ready", dependencies: { sql: "up" } });
    } catch (error) {
      logger.warn("readiness check failed", { error: error.message });
      return res
        .status(503)
        .json({ status: "not_ready", dependencies: { sql: "down" } });
    }
  });

  return router;
}

module.exports = { createHealthRouter };
