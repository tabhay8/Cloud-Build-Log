// One-off database migration. Runs as a Container Apps job inside snet-aca,
// which is the only place that can reach the private SQL endpoint.
//
// Three things happen, in order, and each is safe to run again:
//   1. schema   - db/init.sql, the same file the local SQL container uses
//   2. seed     - the three projects, inserted only if the title is absent
//   3. grant    - the API identity gets a database user and read access
//
// The grant deliberately does NOT use CREATE USER FROM EXTERNAL PROVIDER.
// That statement makes SQL look the identity up in Microsoft Graph, which
// requires the server to carry an identity holding User.Read.All,
// GroupMember.Read.All and Application.Read.All. Those are grantable on this
// tenant, but depending on them ties every deployment to a directory
// permission that can be revoked and would not exist in another tenant.
//
// CREATE USER ... WITH SID = <binary>, TYPE = E creates the same user with no
// directory lookup at all. The trade-off is that SQL does not verify the object
// id: a wrong value produces a user that exists and silently never
// authenticates. The SID is derived here from the client id Terraform passes
// in, so there is no place for a typo to enter.

const fs = require('fs');
const path = require('path');
const sql = require('mssql');
const { DefaultAzureCredential } = require('@azure/identity');

const SERVER = required('SQL_SERVER');
const DATABASE = required('SQL_DATABASE');
const CLIENT_ID = process.env.AZURE_CLIENT_ID;

// Mirrors the API's own flag. false means the local Compose database: username
// and password, and no Entra identity to grant anything to. Schema and seed are
// identical either way, which is the point - the part that runs unattended in
// Azure is the part that was exercised locally.
const USE_MANAGED_IDENTITY = process.env.SQL_USE_MANAGED_IDENTITY !== 'false';

// Inside the image both files sit in ./sql. Running from a checkout, init.sql is
// still in db/ where it belongs, so the path is overridable rather than copied.
const SCHEMA_FILE = process.env.SCHEMA_FILE || path.join(__dirname, 'sql', 'init.sql');
const SEED_FILE = process.env.SEED_FILE || path.join(__dirname, 'sql', 'seed.sql');

const API_CLIENT_ID = USE_MANAGED_IDENTITY ? required('API_IDENTITY_CLIENT_ID') : null;
const API_USER_NAME = USE_MANAGED_IDENTITY ? required('API_IDENTITY_NAME') : null;

function required(name) {
  const v = process.env[name];
  if (!v) {
    console.error(`Missing required environment variable ${name}`);
    process.exit(1);
  }
  return v;
}

// A managed identity's SID in SQL is its client id as a little-endian binary
// GUID: the first three components byte-reversed, the last two as written.
function clientIdToSid(clientId) {
  const hex = clientId.replace(/-/g, '');
  if (hex.length !== 32) throw new Error(`Not a GUID: ${clientId}`);
  const b = Buffer.from(hex, 'hex');
  const out = Buffer.from([
    b[3], b[2], b[1], b[0],
    b[5], b[4],
    b[7], b[6],
    ...b.subarray(8),
  ]);
  return '0x' + out.toString('hex').toUpperCase();
}

async function connect() {
  if (!USE_MANAGED_IDENTITY) {
    return sql.connect({
      server: SERVER,
      port: Number(process.env.SQL_PORT || 1433),
      database: DATABASE,
      user: required('SQL_ADMIN_USER'),
      password: required('MSSQL_SA_PASSWORD'),
      // Self-signed certificate inside the SQL container. Local only - the
      // Azure path below never relaxes this.
      options: { encrypt: true, trustServerCertificate: true },
      connectionTimeout: 30000,
      requestTimeout: 120000,
    });
  }

  const credential = new DefaultAzureCredential(
    CLIENT_ID ? { managedIdentityClientId: CLIENT_ID } : {}
  );
  const token = await credential.getToken('https://database.windows.net/.default');

  return sql.connect({
    server: SERVER,
    database: DATABASE,
    options: { encrypt: true, trustServerCertificate: false },
    authentication: {
      type: 'azure-active-directory-access-token',
      options: { token: token.token },
    },
    connectionTimeout: 60000,
    requestTimeout: 120000,
  });
}

// Only transient failures are worth retrying: a paused serverless database
// refusing connections while it resumes. A rejected login is a permanent
// answer - retrying it just delays the error and makes it look intermittent.
const TRANSIENT = new Set(['ETIMEOUT', 'ESOCKET', 'ECONNRESET', 'ECONNREFUSED', 'EHOSTUNREACH']);


// Local only. The Compose volume starts empty, so the target database does not
// exist on a fresh `docker compose up`. Connecting straight to it gives SQL
// error 4060 followed by 18456, and tedious reports only the second - so a
// missing database is indistinguishable from a wrong password. Create it from
// master first and the ambiguity disappears.
//
// Azure never takes this path: Terraform creates the database, and the
// migration identity has no permission to create one anyway.
async function ensureLocalDatabase() {
  const pool = await sql.connect({
    server: SERVER,
    port: Number(process.env.SQL_PORT || 1433),
    database: 'master',
    user: required('SQL_ADMIN_USER'),
    password: required('MSSQL_SA_PASSWORD'),
    options: { encrypt: true, trustServerCertificate: true },
    connectionTimeout: 30000,
  });
  try {
    const name = DATABASE.replace(/]/g, ']]');
    await pool.request().batch(
      `IF DB_ID(N'${DATABASE.replace(/'/g, "''")}') IS NULL CREATE DATABASE [${name}];`
    );
    console.log(`local: database ${DATABASE} present`);
  } finally {
    await pool.close();
  }
}

// Azure SQL serverless auto-pauses after 60 minutes. The first connection after
// a pause is refused while the database resumes, which takes up to a minute or
// so. Retrying is not optional here - a fresh deployment hits a paused database
// almost every time.
async function connectWithRetry(attempts = 8) {
  for (let i = 1; i <= attempts; i++) {
    try {
      return await connect();
    } catch (err) {
      const code = err.code || err.originalError?.code;
      if (!TRANSIENT.has(code)) throw err;
      if (i === attempts) throw err;
      const wait = Math.min(30000, 2000 * 2 ** (i - 1));
      console.log(`Connection attempt ${i} failed (${code}); retrying in ${wait / 1000}s`);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
}

// GO is a client directive, not T-SQL. mssql will not accept it.
function batches(script) {
  return script
    .split(/^\s*GO\s*$/gim)
    .map((s) => s.trim())
    .filter(Boolean);
}

async function runFile(pool, file, label) {
  const script = fs.readFileSync(file, 'utf8');
  const parts = batches(script);
  console.log(`${label}: ${path.basename(file)}, ${parts.length} batch(es)`);
  for (const [i, batch] of parts.entries()) {
    try {
      await pool.request().batch(batch);
    } catch (err) {
      // SQL reports line numbers relative to the batch, so the file line is
      // meaningless without knowing which batch ran. Print it.
      const lines = batch.split('\n');
      const at = err.lineNumber ? lines[err.lineNumber - 1] : null;
      console.error(`${label}: batch ${i + 1} of ${parts.length} failed`);
      if (at) console.error(`  line ${err.lineNumber}: ${at.trim()}`);
      if (process.env.DEBUG_BATCH === 'true') {
        console.error('--- failing batch ---');
        lines.forEach((l, n) => console.error(String(n + 1).padStart(3), l));
        console.error('--- end ---');
      }
      throw err;
    }
  }
  console.log(`${label}: done`);
}

async function grantApiIdentity(pool) {
  const sid = clientIdToSid(API_CLIENT_ID);
  console.log(`grant: ${API_USER_NAME} (client id ${API_CLIENT_ID}) -> SID ${sid}`);

  // The user name is an identifier, so it cannot be parameterised. It comes
  // from a Terraform output, never from user input, and is bracket-quoted with
  // any embedded bracket doubled.
  const user = API_USER_NAME.replace(/]/g, ']]');

  await pool.request().batch(`
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'${API_USER_NAME.replace(/'/g, "''")}')
BEGIN
    CREATE USER [${user}] WITH SID = ${sid}, TYPE = E;
END
`);

  // Read only. No writer, no owner. The API never writes; the job does, and the
  // job is not the API.
  await pool.request().batch(`ALTER ROLE db_datareader ADD MEMBER [${user}];`);
  console.log('grant: db_datareader granted');
}

async function verify(pool) {
  const rows = await pool.request().query(`SELECT COUNT(*) AS ProjectCount FROM dbo.Projects;`);
  console.log(`verify: Projects rows = ${rows.recordset[0].ProjectCount}`);

  if (USE_MANAGED_IDENTITY) {
    const principals = await pool.request().query(`
SELECT dp.name, dp.type_desc, r.name AS role_name
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON drm.member_principal_id = dp.principal_id
LEFT JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
WHERE dp.type IN ('E','X');
`);
    console.table(principals.recordset);
  }
}

(async () => {
  console.log(`Migrating ${DATABASE} on ${SERVER} (${USE_MANAGED_IDENTITY ? 'managed identity' : 'local sql auth'})`);
  let pool;
  try {
    if (!USE_MANAGED_IDENTITY) await ensureLocalDatabase();
    pool = await connectWithRetry();
    console.log('connected');
    await runFile(pool, SCHEMA_FILE, 'schema');
    await runFile(pool, SEED_FILE, 'seed');

    if (USE_MANAGED_IDENTITY) {
      await grantApiIdentity(pool);
    } else {
      // No Entra identity to grant to locally. Prove the conversion anyway, so
      // a bad SID is caught here rather than as a login failure in Azure that
      // looks like a networking fault.
      const sample = process.env.API_IDENTITY_CLIENT_ID;
      if (sample) console.log(`grant: skipped (local). SID would be ${clientIdToSid(sample)}`);
      else console.log('grant: skipped (local)');
    }

    await verify(pool);
    console.log('Migration complete');
    process.exit(0);
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    if (pool) await pool.close().catch(() => {});
  }
})();