"use strict";

const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };

function createLogger(level = "info") {
  const threshold = LEVELS[level] ?? LEVELS.info;

  function write(entryLevel, message, fields = {}) {
    if (LEVELS[entryLevel] > threshold) return;
    const line = {
      timestamp: new Date().toISOString(),
      level: entryLevel,
      message,
      ...fields
    };
    const serialized = JSON.stringify(line);
    if (entryLevel === "error") process.stderr.write(serialized + "\n");
    else process.stdout.write(serialized + "\n");
  }

  return {
    error: (message, fields) => write("error", message, fields),
    warn: (message, fields) => write("warn", message, fields),
    info: (message, fields) => write("info", message, fields),
    debug: (message, fields) => write("debug", message, fields)
  };
}

module.exports = { createLogger };
