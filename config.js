// Runtime configuration. Override per environment without rebuilding.
// Empty string = same-origin (/api/projects). Set to the Container App URL for cross-origin testing.
window.APP_CONFIG = {
    API_BASE: "https://ca-cbl-dev-cus-api.salmonmushroom-8fc4f495.centralus.azurecontainerapps.io",
  REQUEST_TIMEOUT_MS: 15000,
  RETRY_ATTEMPTS: 3
};
