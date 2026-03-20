# ─────────────────────────────────────────────────────────
# TERRAFORM SETTINGS
# ─────────────────────────────────────────────────────────
terraform {
  required_version = ">= 1.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# ─────────────────────────────────────────────────────────
# GITHUB PROVIDER
# Authenticates Terraform with your GitHub account
# ─────────────────────────────────────────────────────────
provider "github" {
  token = var.github_token
  owner = var.github_owner
}

# ─────────────────────────────────────────────────────────
# GITHUB ACTIONS SECRETS
# Each resource pushes one secret to your repo
# ─────────────────────────────────────────────────────────

# MySQL Root Password
resource "github_actions_secret" "mysql_root_password" {
  repository      = var.github_repo
  secret_name     = "MYSQL_ROOT_PASSWORD"
  plaintext_value = var.mysql_root_password
}

# MySQL App User Password
resource "github_actions_secret" "mysql_app_password" {
  repository      = var.github_repo
  secret_name     = "MYSQL_APP_PASSWORD"
  plaintext_value = var.mysql_app_password
}

# MySQL Replication Password
resource "github_actions_secret" "mysql_repl_password" {
  repository      = var.github_repo
  secret_name     = "MYSQL_REPL_PASSWORD"
  plaintext_value = var.mysql_repl_password
}

# MySQL Monitor Password (used by ProxySQL)
resource "github_actions_secret" "mysql_monitor_password" {
  repository      = var.github_repo
  secret_name     = "MYSQL_MONITOR_PASSWORD"
  plaintext_value = var.mysql_monitor_password
}

# ProxySQL Admin Password
resource "github_actions_secret" "proxysql_admin_password" {
  repository      = var.github_repo
  secret_name     = "PROXYSQL_ADMIN_PASSWORD"
  plaintext_value = var.proxysql_admin_password
}

# ─────────────────────────────────────────────────────────
# OUTPUTS
# Confirms which secrets were created (names only, no values)
# ─────────────────────────────────────────────────────────
output "secrets_created" {
  value = [
    github_actions_secret.mysql_root_password.secret_name,
    github_actions_secret.mysql_app_password.secret_name,
    github_actions_secret.mysql_repl_password.secret_name,
    github_actions_secret.mysql_monitor_password.secret_name,
    github_actions_secret.proxysql_admin_password.secret_name,
  ]
  description = "List of secrets pushed to GitHub Actions"
}