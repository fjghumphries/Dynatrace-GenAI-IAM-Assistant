# ============================================================================
# Policy Bindings - Application-Level Groups
# ============================================================================
# Bindings for application-specific groups with more restrictive access.
# These users only have access to data within their specific application
# across all configured stages.
#
# Security Context Pattern: bu-stage-application (LOWERCASE)
# Application users access all stages enumerated in their application boundary.
# ============================================================================

# ------------------------------------------------------------------------------
# Application Admin Bindings — Resource 1: Data Access
# Read access to application data + system events
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
  # Boundary restricts to specific application+stages; parameter uses BU prefix
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

  # Default data read policies with application boundary — required for bucket-level access.
  # Scoped Grail Data Read (WHERE clause) alone does NOT grant bucket permissions.
  # See LESSONS_LEARNED.md #19.
  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_metrics.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_spans.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_events.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_bizevents.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  # System events (not scoped by security_context — applies globally)
  policy {
    id = data.dynatrace_iam_policy.read_system_events.id
  }
}

# ------------------------------------------------------------------------------
# Application Admin Bindings — Resource 2: Settings Write + SLO Management
# Separate resource required because settings boundaries differ from data boundaries.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "application_admins_settings" {
  for_each = var.applications

  group   = dynatrace_iam_group.application_admins[each.key].id
  account = var.account_id

  # Scoped settings write — can modify settings for entities in their application
  # lower() ensures bucket names are always lowercase
  policy {
    id         = dynatrace_iam_policy.scoped_settings_write.id
    boundaries = [dynatrace_iam_policy_boundary.application_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.value.bu}-")
    }
  }

  # SLO management (adds write on top of Standard User read)
  # BU Admins get SLO write via Admin Features; this is for Application Admins
  policy {
    id = dynatrace_iam_policy.slo_manager.id
  }

  depends_on = [dynatrace_iam_policy_bindings_v2.application_admins_data]
}

# ------------------------------------------------------------------------------
# Application User Bindings — Resource 1: Read-Only Data Access
# Most restrictive access pattern — read-only, application-scoped only.
# Standard User provides: documents, SLO read, automation read, segments, Davis AI.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "application_users_data" {
  for_each = var.applications

  group   = dynatrace_iam_group.application_users[each.key].id
  account = var.account_id

  # Standard User access for basic environment features
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

  # Default data read policies with application boundary — required for bucket-level access.
  # See LESSONS_LEARNED.md #19.
  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_metrics.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_spans.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_events.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_bizevents.id
    boundaries = [dynatrace_iam_policy_boundary.application_boundary[each.key].id]
  }

  # Scoped settings read — additive over Standard User's global read,
  # but retained for explicitness
  policy {
    id         = dynatrace_iam_policy.scoped_settings_read.id
    boundaries = [dynatrace_iam_policy_boundary.application_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.value.bu}-")
    }
  }
}
