# ─────────────────────────────────────────────────────────
# GITHUB AUTHENTICATION
# ─────────────────────────────────────────────────────────

variable "github_token" {
  description = "GitHub Personal Access Token with repo scope"
  type        = string
  sensitive   = true   # prevents value from appearing in logs
}

variable "github_owner" {
  description = "GitHub username or organization that owns the repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without owner prefix)"
  type        = string
}

# ─────────────────────────────────────────────────────────
# MYSQL SECRETS
# ─────────────────────────────────────────────────────────

variable "mysql_root_password" {
  description = "MySQL root user password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_root_password) >= 12
    error_message = "MySQL root password must be at least 12 characters long."
  }
}

variable "mysql_app_password" {
  description = "MySQL application user (appuser) password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_app_password) >= 12
    error_message = "MySQL app password must be at least 12 characters long."
  }
}

variable "mysql_repl_password" {
  description = "MySQL replication user password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_repl_password) >= 12
    error_message = "MySQL replication password must be at least 12 characters long."
  }
}

variable "mysql_monitor_password" {
  description = "MySQL monitor user password (used by ProxySQL health checks)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_monitor_password) >= 12
    error_message = "MySQL monitor password must be at least 12 characters long."
  }
}

# ─────────────────────────────────────────────────────────
# PROXYSQL SECRETS
# ─────────────────────────────────────────────────────────

variable "proxysql_admin_password" {
  description = "ProxySQL admin interface password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.proxysql_admin_password) >= 12
    error_message = "ProxySQL admin password must be at least 12 characters long."
  }
}