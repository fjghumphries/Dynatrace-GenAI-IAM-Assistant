# ============================================================================
# Policy Bindings - Application-Level Groups
# ============================================================================
# Bindings for application-specific groups with more restrictive access.
# These users only have access to data within their specific application.
#
# Security Context Pattern: bu-stage-application-component (LOWERCASE)
# Application users access: bu-*-application-* (all stages within application)
# ============================================================================

# ------------------------------------------------------------------------------
# Application Admin Bindings
# Can change settings scoped to their application
# Read access to all application data across stages
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "application_admins_data" {
  for_each = var.applications

  group   = dynatrace_iam_group.application_admins[each.key].id
  account = var.account_id

  # Standard User access for basic environment features
  policy {
    id = data.dynatrace_iam_policy.standard_user.id
  }

  # Scoped data read using templated policy
  # Parameter uses BU- prefix but boundary restricts to specific application
  # lower() ensures bucket names are always lowercase
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
    parameters = {
      # Using BU prefix in parameter, boundary further restricts to application
      "security_context_prefix" = lower("${each.value.bu}-")
    }
  }

  # Entities read scoped to application
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  # System events (not scoped by security_context typically)
  policy {
    id = data.dynatrace_iam_policy.read_system_events.id
  }
}

# Settings bindings for application admins - separate resource
resource "dynatrace_iam_policy_bindings_v2" "application_admins_settings" {
  for_each = var.applications

  group   = dynatrace_iam_group.application_admins[each.key].id
  account = var.account_id

  # Scoped settings write - can modify settings for entities in their application
  # lower() ensures bucket names are always lowercase
  policy {
    id         = dynatrace_iam_policy.scoped_settings_write.id
    boundaries = [dynatrace_iam_policy_boundary.application_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.value.bu}-")
    }
  }

  # SLO management (adds write on top of Standard User read)
  policy {
    id = dynatrace_iam_policy.slo_manager.id
  }

  depends_on = [dynatrace_iam_policy_bindings_v2.application_admins_data]
}

# ------------------------------------------------------------------------------
# Application User Bindings
# Read-only access to data within their specific application
# Most restrictive access pattern
# Standard User provides: documents, SLO read, automation read, segments, Davis AI
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "application_users_data" {
  for_each = var.applications

  group   = dynatrace_iam_group.application_users[each.key].id
  account = var.account_id

  # Standard User access for basic environment features
  # Includes: documents, SLOs read, automation read, segments, Davis AI
  policy {
    id = data.dynatrace_iam_policy.standard_user.id
  }

  # Scoped data read using templated policy with application boundary
  # lower() ensures bucket names are always lowercase
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.value.bu}-")
    }
  }

  # Entities read scoped to application
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  # Read-only settings access
  policy {
    id         = dynatrace_iam_policy.scoped_settings_read.id
    boundaries = [dynatrace_iam_policy_boundary.application_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.value.bu}-")
    }
  }
}
