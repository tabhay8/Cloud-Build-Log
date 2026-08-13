"use strict";

function startTelemetry(connectionString, logger) {
  if (!connectionString) {
    logger.info("Telemetry disabled: no Application Insights connection string set");
    return false;
  }

  try {
    const { useAzureMonitor } = require("@azure/monitor-opentelemetry");
    useAzureMonitor();
    logger.info("Telemetry enabled: Azure Monitor OpenTelemetry started");
    return true;
  } catch (error) {
    logger.warn("Telemetry could not start; continuing without it", {
      error: error.message
    });
    return false;
  }
}

module.exports = { startTelemetry };
