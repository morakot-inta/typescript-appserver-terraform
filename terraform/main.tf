locals {
  project = "andromedra"
  location = "Southeastasia"
  subscription_id = "ab67c280-e37d-49b2-9a0d-f575ed98d7be" 
}

resource "random_string" "this" {
  length  = 4
  special = false 
  upper   = false
  numeric = false 
}


resource "azurerm_resource_group" "this" {
  name     = "${local.project}-rg" 
  location = local.location 
}

resource "azurerm_service_plan" "this" {
  name                = "${local.project}-plan"
  resource_group_name = azurerm_resource_group.this.name 
  location            = azurerm_resource_group.this.location 
  os_type             = "Linux"  
  sku_name            = "B2"
}

resource "azurerm_linux_web_app" "this" {
  name                = "${local.project}-${random_string.this.result}-app" 
  resource_group_name = azurerm_resource_group.this.name 
  location            = azurerm_service_plan.this.location
  service_plan_id     = azurerm_service_plan.this.id

  site_config {
    application_stack {
      node_version = "22-lts"
    }
    always_on                = true
    ftps_state               = "Disabled"
    minimum_tls_version      = "1.2"
    app_command_line         = "npm start"  # Ensure this matches your start script
    
    # Add health check to improve reliability
    health_check_path        = "/health"
    health_check_eviction_time_in_min = 10
  }

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"  # We're deploying a pre-built JS app, no need for server-side build
    "WEBSITE_RUN_FROM_PACKAGE"       = "0"      # Extract the zip contents
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "true"
    "WEBSITE_NODE_DEFAULT_VERSION"   = "~22"    # Match your local Node.js version
    "PORT"                           = "8080"   # Match the port in your server.js
    "WEBSITE_WEBDEPLOY_USE_SCM"      = "false"  # Improves deployment reliability
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
    application_logs {
      file_system_level = "Verbose"
    }
    http_logs {
      file_system {
        retention_in_days  = 7
        retention_in_mb    = 35
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags as they will be updated via deployment
      tags
    ]
  }
}

# Build the application with NPM before creating the zip
resource "null_resource" "build_app" {
  triggers = {
    package_json_hash = filemd5("../api/dist/server.js") 
  }
  
  provisioner "local-exec" {
    # command = "cd ../api && npm install --production"
    command = "cd ../api && npm run build" 
    interpreter = ["/bin/zsh", "-c"]
  }
}

# Create zip archive of the api directory excluding node_modules
data "archive_file" "api_zip" {
  type        = "zip"
  source_dir  = "../api" # Path to the built API directory
  output_path = "${path.module}/api.zip"
  excludes    = ["node_modules"] # Exclude node_modules as we're using NPM with SCM_DO_BUILD_DURING_DEPLOYMENT=true
  
  depends_on = [null_resource.build_app]
}

resource "null_resource" "deploy_zip" {
  triggers = {
    api_zip_hash = data.archive_file.api_zip.output_md5
  }

  provisioner "local-exec" {
    command = <<EOT
      az webapp deployment source config-zip \
        --resource-group ${azurerm_resource_group.this.name} \
        --name ${azurerm_linux_web_app.this.name} \
        --src ${data.archive_file.api_zip.output_path} \
        --timeout 600 
    EOT
    interpreter = ["/bin/zsh", "-c"]
  }

  depends_on = [
    azurerm_linux_web_app.this,
    data.archive_file.api_zip
  ]
}

# Output the web app URL
output "webapp_url" {
  value = "https://${azurerm_linux_web_app.this.default_hostname}"
}