IF DB_ID('portfolio') IS NULL
BEGIN
  CREATE DATABASE portfolio;
END
GO

USE portfolio;
GO

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

IF NOT EXISTS (SELECT 1 FROM dbo.Projects)
BEGIN
  INSERT INTO dbo.Projects (Title, Description, Tags, Badge, ImageUrl, CreatedAt) VALUES
    (N'AKS with Terraform',
    N'Provisioning Azure Kubernetes Service clusters via Terraform and Azure DevOps pipelines - practicing container orchestration, Helm deployments, and secure ingress.',
    N'AKS,Terraform,Azure DevOps,Helm',
    N'In progress - 2026',
    N'images/aks.png',
    '2026-07-22T17:08:12'),
    (N'Movie Booking Website',
    N'Full-stack movie booking site built with the .NET Framework and C#, with an integrated database for movie data and images. Deployed on Azure for high availability and scalability, end to end.',
    N'.NET,C#,Azure,SQL',
    N'Capstone - 2023',
    N'images/movie.png',
    '2023-06-01T00:00:00');
    (N'Cloud Build Log',
    N'This site. Static frontend on Azure Static Web Apps, containerised API on Container Apps, private Azure SQL, all defined in Terraform with remote state and private endpoints.',
    N'Terraform,Container Apps,Azure SQL,CI/CD',
    N'Live - 2026',
    N'images/cloudbuildlog.jpg',
    SYSUTCDATETIME()),
END
GO
