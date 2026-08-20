-- Schema only. No CREATE DATABASE, no USE.
--
-- Azure SQL does not support USE for switching databases, and the migration
-- identity has no permission to create one - the database is created by
-- Terraform. The connection decides which database this runs against; this file
-- must never try to.
--
-- Locally the migration job creates the database from master before connecting,
-- which is the only place that bootstrap belongs.
--
-- Seed data lives in migration/sql/seed.sql.

IF OBJECT_ID('dbo.Projects', 'U') IS NULL
BEGIN
  CREATE TABLE dbo.Projects (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    Title       NVARCHAR(200)  NOT NULL,
    Description NVARCHAR(1000) NULL,
    Tags        NVARCHAR(400)  NULL,
    Badge       NVARCHAR(60)   NULL,
    ImageUrl    NVARCHAR(500)  NULL,
    Link        NVARCHAR(500)  NULL,
    CreatedAt   DATETIME2      NOT NULL CONSTRAINT DF_Projects_CreatedAt DEFAULT SYSUTCDATETIME()
  );
  CREATE INDEX IX_Projects_CreatedAt ON dbo.Projects (CreatedAt DESC);
END
GO