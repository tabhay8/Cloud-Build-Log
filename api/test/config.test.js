"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { load, parseList, parseBool } = require("../src/config");

// These values are non-functional test placeholders, not credentials.
const PLACEHOLDER_SERVER = "<test-sql-server>";
const PLACEHOLDER_USER = "<test-user>";
const PLACEHOLDER_PASSWORD = "<test-password>";

test("parseList splits and trims comma separated values", () => {
  assert.deepStrictEqual(parseList("a, b ,c"), ["a", "b", "c"]);
  assert.deepStrictEqual(parseList(""), []);
});

test("parseBool understands common truthy strings", () => {
  assert.strictEqual(parseBool("true", false), true);
  assert.strictEqual(parseBool("no", true), false);
  assert.strictEqual(parseBool(undefined, true), true);
});

test("load fails fast when required SQL settings are missing", () => {
  assert.throws(() => load({}), /Missing required configuration/);
});

test("load names every missing variable in the error", () => {
  try {
    load({ SQL_SERVER: "localhost" });
    assert.fail("expected load to throw");
  } catch (error) {
    assert.match(error.message, /SQL_DATABASE/);
    assert.match(error.message, /SQL_USER/);
    assert.match(error.message, /SQL_PASSWORD/);
  }
});

test("load succeeds with username and password auth", () => {
  const config = load({
    SQL_SERVER: "localhost",
    SQL_DATABASE: "portfolio",
    SQL_USER: PLACEHOLDER_USER,
    SQL_PASSWORD: PLACEHOLDER_PASSWORD
  });
  assert.strictEqual(config.sql.database, "portfolio");
  assert.strictEqual(config.port, 3000);
  assert.strictEqual(config.sql.useManagedIdentity, false);
});

test("load does not require a password when managed identity is enabled", () => {
  const config = load({
    SQL_SERVER: PLACEHOLDER_SERVER,
    SQL_DATABASE: "portfolio",
    SQL_USE_MANAGED_IDENTITY: "true"
  });
  assert.strictEqual(config.sql.useManagedIdentity, true);
  assert.strictEqual(config.sql.password, undefined);
});

test("allowed origins parse into a list", () => {
  const config = load({
    SQL_SERVER: "localhost",
    SQL_DATABASE: "portfolio",
    SQL_USER: PLACEHOLDER_USER,
    SQL_PASSWORD: PLACEHOLDER_PASSWORD,
    CORS_ALLOWED_ORIGINS: "http://localhost:8080, https://example.net"
  });
test("rejects empty allowlist outside development", () => {
  assert.throws(
    () => load({
      NODE_ENV: "production",
      SQL_SERVER: "s",
      SQL_DATABASE: "d",
      SQL_USE_MANAGED_IDENTITY: "true"
    }),
    /CORS_ALLOWED_ORIGINS/
  );
});

  assert.deepStrictEqual(config.allowedOrigins, [
    "http://localhost:8080",
    "https://example.net"
  ]);
});
