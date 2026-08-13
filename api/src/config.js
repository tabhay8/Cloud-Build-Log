"use strict";

function parseList(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseNumber(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseBool(value, fallback) {
  if (value === undefined || value === "") return fallback;
  return ["1", "true", "yes", "on"].includes(String(value).toLowerCase());
}

function load(env = process.env) {
  const useManagedIdentity = parseBool(env.SQL_USE_MANAGED_IDENTITY, false);

  const config = {
    env: env.NODE_ENV || "development",
    port: parseNumber(env.PORT, 3000),
    shutdownTimeoutMs: parseNumber(env.SHUTDOWN_TIMEOUT_MS, 10000),
    allowedOrigins: parseList(env.ALLOWED_ORIGINS),
    logLevel: env.LOG_LEVEL || "info",
    telemetryConnectionString: env.APPLICATIONINSIGHTS_CONNECTION_STRING || "",
    sql: {
      server: env.SQL_SERVER,
      database: env.SQL_DATABASE,
      user: env.SQL_USER,
      password: env.SQL_PASSWORD,
      port: parseNumber(env.SQL_PORT, 1433),
      useManagedIdentity,
      encrypt: parseBool(env.SQL_ENCRYPT, true),
      trustServerCertificate: parseBool(env.SQL_TRUST_SERVER_CERTIFICATE, false),
      poolMax: parseNumber(env.SQL_POOL_MAX, 10),
      poolMin: parseNumber(env.SQL_POOL_MIN, 0),
      connectTimeoutMs: parseNumber(env.SQL_CONNECT_TIMEOUT_MS, 30000),
      requestTimeoutMs: parseNumber(env.SQL_REQUEST_TIMEOUT_MS, 30000),
      retryAttempts: parseNumber(env.SQL_RETRY_ATTEMPTS, 5),
      retryBaseDelayMs: parseNumber(env.SQL_RETRY_BASE_DELAY_MS, 500)
    }
  };

  const missing = [];
  if (!config.sql.server) missing.push("SQL_SERVER");
  if (!config.sql.database) missing.push("SQL_DATABASE");
  if (!useManagedIdentity) {
    if (!config.sql.user) missing.push("SQL_USER");
    if (!config.sql.password) missing.push("SQL_PASSWORD");
  }

  if (missing.length > 0) {
    throw new Error(
      "Missing required configuration: " +
        missing.join(", ") +
        ". Copy .env.example to .env and fill in the values."
    );
  }

  return config;
}

module.exports = { load, parseList, parseBool, parseNumber };
