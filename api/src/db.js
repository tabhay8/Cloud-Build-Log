"use strict";

const sql = require("mssql");

function buildPoolConfig(sqlConfig) {
  const base = {
    server: sqlConfig.server,
    database: sqlConfig.database,
    port: sqlConfig.port,
    pool: {
      max: sqlConfig.poolMax,
      min: sqlConfig.poolMin,
      idleTimeoutMillis: 30000
    },
    options: {
      encrypt: sqlConfig.encrypt,
      trustServerCertificate: sqlConfig.trustServerCertificate,
      enableArithAbort: true
    },
    connectionTimeout: sqlConfig.connectTimeoutMs,
    requestTimeout: sqlConfig.requestTimeoutMs
  };

  if (sqlConfig.useManagedIdentity) {
    base.authentication = { type: "azure-active-directory-default" };
  } else {
    base.user = sqlConfig.user;
    base.password = sqlConfig.password;
  }

  return base;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function createDatabase(sqlConfig, logger) {
  let poolPromise = null;

  async function connectWithRetry() {
    const attempts = sqlConfig.retryAttempts;
    let lastError;

    for (let attempt = 1; attempt <= attempts; attempt += 1) {
      try {
        const pool = new sql.ConnectionPool(buildPoolConfig(sqlConfig));
        pool.on("error", (error) => {
          logger.error("SQL pool error", { error: error.message });
        });
        await pool.connect();
        logger.info("SQL pool connected", { attempt });
        return pool;
      } catch (error) {
        lastError = error;
        const waitMs = sqlConfig.retryBaseDelayMs * 2 ** (attempt - 1);
        logger.warn("SQL connect failed; retrying", {
          attempt,
          attempts,
          waitMs,
          error: error.message
        });
        if (attempt < attempts) await delay(waitMs);
      }
    }

    throw lastError;
  }

  async function getPool() {
    if (!poolPromise) {
      poolPromise = connectWithRetry().catch((error) => {
        poolPromise = null;
        throw error;
      });
    }
    return poolPromise;
  }

  async function query(text, binder) {
    const pool = await getPool();
    const request = pool.request();
    if (typeof binder === "function") binder(request);
    return request.query(text);
  }

  async function ping() {
    const result = await query("SELECT 1 AS ok");
    return result.recordset[0].ok === 1;
  }

  async function close() {
    if (!poolPromise) return;
    try {
      const pool = await poolPromise;
      await pool.close();
      logger.info("SQL pool closed");
    } catch (error) {
      logger.warn("Error while closing SQL pool", { error: error.message });
    } finally {
      poolPromise = null;
    }
  }

  return { getPool, query, ping, close, sql };
}

module.exports = { createDatabase, buildPoolConfig };
