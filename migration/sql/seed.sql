-- Seed data for dbo.Projects. Moved out of db/init.sql, which now creates the
-- schema and nothing else.
--
-- Guarded per title rather than "if the table is empty". The all-or-nothing
-- form silently skips every new project once a single row exists, which is the
-- wrong behaviour for a job that reruns on every deployment.
--
-- Id is IDENTITY(1,1), so it is never supplied.
-- CreatedAt is fixed, not SYSUTCDATETIME(): the front end orders by it, and a
-- value that changes per run makes ordering depend on when a deployment ran.

SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Projects WHERE Title = N'Hire Me, Hosted on Azure')
INSERT INTO dbo.Projects (Title, Description, Tags, Badge, ImageUrl, CreatedAt, Link)
VALUES (
    N'Hire Me, Hosted on Azure',
    N'A responsive resume-style portfolio built with plain HTML, CSS, and JavaScript, hosted on Azure Static Web Apps with a custom domain and HTTPS. Features a dark/light theme, scroll animations, and a projects gallery that loads from an API with an offline fallback mode.',
    N'HTML,CSS,JavaScript,Azure Static Web Apps,GitHub Actions',
    N'Live - 2026',
    N'images/port.png',
    '2026-07-01T00:00:00',
    N'https://portfolio.domaincheck.store/'
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Projects WHERE Title = N'Cloud Build Log')
INSERT INTO dbo.Projects (Title, Description, Tags, Badge, ImageUrl, CreatedAt, Link)
VALUES (
    N'Cloud Build Log',
    N'This site. Static frontend on Azure Static Web Apps, containerised API on Container Apps, private Azure SQL, all defined in Terraform with remote state and private endpoints.',
    N'Terraform,Container Apps,Azure SQL,CI/CD',
    N'Live - 2026',
    N'images/cloudbuildlog.jpg',
    '2026-08-01T00:00:00',
     N'https://github.com/tabhay8/Cloud-Build-Log'
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Projects WHERE Title = N'AKS with Terraform')
INSERT INTO dbo.Projects (Title, Description, Tags, Badge, ImageUrl, CreatedAt, Link)
VALUES (
    N'AKS with Terraform',
    N'Provisioning Azure Kubernetes Service clusters via Terraform and Azure DevOps pipelines - practicing container orchestration, Helm deployments, and secure ingress.',
    N'AKS,Terraform,Azure DevOps,Helm',
    N'In progress - 2026',
    N'images/aks.png',
    '2026-07-22T17:08:12',
    N'https://github.com/tabhay8/azure-aks-kubernetes-masterclass'
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Projects WHERE Title = N'Movie Booking Website')
INSERT INTO dbo.Projects (Title, Description, Tags, Badge, ImageUrl, CreatedAt, Link)
VALUES (
    N'Movie Booking Website',
    N'Full-stack movie booking site built with the .NET Framework and C#, with an integrated database for movie data and images. Deployed on Azure for high availability and scalability, end to end.',
    N'.NET,C#,Azure,SQL',
    N'Capstone - 2023',
    N'images/movie.png',
    '2023-06-01T00:00:00',
    N'https://github.com/tabhay8/capstone'
);
GO

-- -- Links were omitted from the original seed. The inserts above are guarded on
-- -- Title, so they no longer fire - backfilling needs an explicit UPDATE. Guarded
-- -- on Link IS NULL so a row edited by hand later is not overwritten.

-- UPDATE dbo.Projects SET Link =  N'https://github.com/tabhay8/Cloud-Build-Log'
-- WHERE Title = N'Cloud Build Log' AND Link IS NULL;
-- GO

-- UPDATE dbo.Projects SET Link = N'https://github.com/tabhay8/azure-aks-kubernetes-masterclass'
-- WHERE Title = N'AKS with Terraform' AND Link IS NULL;
-- GO

-- UPDATE dbo.Projects SET Link = N'https://github.com/tabhay8/capstone'
-- WHERE Title = N'Movie Booking Website' AND Link IS NULL;
-- GO