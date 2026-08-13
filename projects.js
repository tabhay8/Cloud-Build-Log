// Cloud Build Log — project data (fallback only)
// The site fetches /api/projects first; this array renders only if that fails.
// Field names match the API contract exactly, so both paths render identically.
window.FALLBACK_PROJECTS = [
  {
    id: "3",
    title: "Cloud Build Log",
    description:
      "This site. Static frontend on Azure Static Web Apps, containerised API on Container Apps, private Azure SQL, all defined in Terraform with remote state and private endpoints.",
    tags: "Terraform,Container Apps,Azure SQL,CI/CD",
    badge: "Live · 2026",
    createdAt: "2026-08-13",
    imageUrl: "images/cloudbuildlog.jpg"
  },
  {
    id: "1",
    title: "AKS with Terraform",
    description:
      "Provisioning Azure Kubernetes Service clusters via Terraform and Azure DevOps pipelines — practicing container orchestration, Helm deployments, and secure ingress.",
    tags: "AKS,Terraform,Azure DevOps,Helm",
    badge: "In progress · 2026",
    createdAt: "2026-07-22",
    imageUrl: "images/aks.png"
  },
  {
    id: "2",
    title: "Movie Booking Website",
    description:
      "Full-stack movie booking site built with the .NET Framework and C#, with an integrated database for movie data and images. Deployed on Azure for high availability and scalability, end to end.",
    tags: ".NET,C#,Azure,SQL",
    badge: "Capstone · 2023",
    createdAt: "2023-06-01",
    imageUrl: "images/movie.png"
  }
];