// Cloud Build Log — project data (v1: hardcoded)
// Replaced by fetch() to /api/projects later. Field names already match
// the future API contract, so the swap is a one-line change.
window.FALLBACK_PROJECTS = [
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