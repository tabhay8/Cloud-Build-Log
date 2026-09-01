terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100"
    }
  }
}

# Basic tier, public, admin user off. Public is a decision: private registries
# need Premium, break `az acr build`, and force a self-hosted runner inside the
# VNet. Nothing authenticates with a registry password either way.
resource "azurerm_container_registry" "this" {
  name                          = var.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = var.tags

  lifecycle {
    ignore_changes = [tags["SecurityControl"]]
  }
}

# Two identities, not one. The migration identity holds schema rights and only
# runs during a deployment. The API identity can read and nothing else.
resource "azurerm_user_assigned_identity" "api" {
  name                = var.api_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["SecurityControl"]]
  }
}

resource "azurerm_user_assigned_identity" "migration" {
  name                = var.migration_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  lifecycle {
    ignore_changes = [tags["SecurityControl"]]
  }
}

resource "azurerm_role_assignment" "api_acr_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.api.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "migration_acr_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.migration.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# internal_load_balancer_enabled = false is required, not incidental: the Free
# tier Static Web App calls the API by public URL with CORS. Outbound traffic
# still leaves from snet-aca, which is what the SQL private endpoint and the
# private DNS zone link depend on.
resource "azurerm_container_app_environment" "this" {
  name                           = var.container_app_environment_name
  resource_group_name            = var.resource_group_name
  location                       = var.location
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = false
  zone_redundancy_enabled        = false
  tags                           = var.tags
  # Azure creates this profile automatically on a Consumption-only environment.
  # Declaring it stops every plan from trying to delete it.
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  lifecycle {
    ignore_changes = [tags["SecurityControl"]]
  }
}

resource "azurerm_container_app" "api" {
  name                         = var.api_app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api.id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.api.id
  }

  ingress {
    external_enabled = true
    target_port      = var.api_target_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.api_min_replicas
    max_replicas = var.api_max_replicas

    container {
      name   = "api"
      image  = var.api_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "PORT"
        value = tostring(var.api_target_port)
      }
      env {
        name  = "SQL_SERVER"
        value = var.sql_server_fqdn
      }
      env {
        name  = "SQL_DATABASE"
        value = var.sql_database_name
      }
      env {
        name  = "SQL_USE_MANAGED_IDENTITY"
        value = "true"
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.api.client_id
      }
      env {
        name  = "CORS_ALLOWED_ORIGINS"
        value = join(",", var.cors_allowed_origins)
      }
      dynamic "env" {
        for_each = var.application_insights_connection_string == null ? [] : [1]
        content {
          name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
          value = var.application_insights_connection_string
        }
      }

      # Liveness never touches SQL: a database blip read as a dead container
      # would restart it, which fixes nothing and drops in-flight requests.
      liveness_probe {
        transport               = "HTTP"
        port                    = var.api_target_port
        path                    = var.api_liveness_path
        initial_delay           = 10
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }

      # Readiness does ping SQL. Failing it removes the replica from rotation;
      # it does not restart anything.
      #
      # azurerm's readiness_probe has no initial_delay - only liveness and
      # startup probes take one. The grace period is therefore interval x
      # threshold: 10s x 18 = 180s, which covers a 30s+ serverless resume. A
      # startup probe would be tidier but would have to point at /ready, and a
      # failing startup probe kills the container - the restart loop again.
      readiness_probe {
        transport               = "HTTP"
        port                    = var.api_target_port
        path                    = var.api_readiness_path
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 18
        success_count_threshold = 1
      }
    }
  }

  depends_on = [azurerm_role_assignment.api_acr_pull]

  # SecurityControl: a policy sets this tag; Terraform would strip it.
  # image: CI deploys new revisions on merge to main (.github/workflows/api.yml),
  # so the running tag is owned by the pipeline, not by state. Check the live
  # image with `az containerapp show`, not `terraform plan`.

  lifecycle {
    ignore_changes = [
      tags["SecurityControl"],
      template[0].container[0].image,      
    ]
  }
}

# Manual trigger. This exists because SQL is private: schema, seed and every
# GRANT must run from inside the VNet, and this is the only compute that runs on
# demand and then stops.
resource "azurerm_container_app_job" "migration" {
  name                         = var.migration_job_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = azurerm_container_app_environment.this.id
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  replica_timeout_in_seconds = 900
  replica_retry_limit        = 1

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.migration.id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.migration.id
  }

  template {
    container {
      name   = "migrate"
      image  = var.migration_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "SQL_SERVER"
        value = var.sql_server_fqdn
      }
      env {
        name  = "SQL_DATABASE"
        value = var.sql_database_name
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.migration.client_id
      }
      # The API identity's client id is what the job converts to a SID. Passing
      # it in means the job never looks anything up in Microsoft Graph.
      env {
        name  = "API_IDENTITY_CLIENT_ID"
        value = azurerm_user_assigned_identity.api.client_id
      }
      env {
        name  = "API_IDENTITY_NAME"
        value = azurerm_user_assigned_identity.api.name
      }
    }
  }

  depends_on = [azurerm_role_assignment.migration_acr_pull]

  lifecycle {
    ignore_changes = [tags["SecurityControl"]]
  }
}