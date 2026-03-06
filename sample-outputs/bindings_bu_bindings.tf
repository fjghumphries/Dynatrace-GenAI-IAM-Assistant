# ============================================================================
# Policy Bindings - BU-Level Groups
# ============================================================================
# Bindings connect groups to policies, optionally with boundaries.
# These bindings are for BU-level groups (access to all data within a BU).
#
# IMPORTANT:
# - Bindings for the same group are split into separate resources when they
#   use different boundary types (storage vs settings cannot share a binding).
# - BU Admins use Standard User + Admin Features (custom), NOT Admin User.
#   This ensures settings:objects:write is ONLY granted via the bounded
#   Scoped Settings Write policy.
#
# See LESSONS_LEARNED.md #16 for why Admin User is not used.
# ============================================================================

# ------------------------------------------------------------------------------
# BU Admin Bindings — Resource 1: Data + Feature Access
# Policies without settings boundary: Standard User, Admin Features, data read
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "bu_admins_data" {
  for_each = var.business_units

  group   = dynatrace_iam_group.bu_admins[each.key].id
  account = var.account_id

  # Standard User provides: documents, Davis AI, segments, SLO read, automation read, etc.
  policy {
    id = data.dynatrace_iam_policy.standard_user.id
  }

  # Admin Features adds: full automation admin, SLO write, extensions write,
  # OpenPipeline, App Engine — WITHOUT settings:objects:write
  policy {
    id = dynatrace_iam_policy.admin_features.id
  }

  # Scoped data read using templated policy with BU prefix parameter
  # lower() ensures bucket names are always lowercase
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.key}-")
    }
  }

  # Entities read with BU boundary
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  # Default data read policies with BU boundary — required for bucket-level access.
  # Scoped Grail Data Read (WHERE clause) alone does NOT grant bucket permissions.
  # These default policies carry the implicit bucket access grants.
  # See LESSONS_LEARNED.md #19.
  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_metrics.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_spans.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_events.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_bizevents.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  # System events (not scoped by security_context — applies globally)
  policy {
    id = data.dynatrace_iam_policy.read_system_events.id
  }
}

# ------------------------------------------------------------------------------
# BU Admin Bindings — Resource 2: Settings Write (uses settings boundary)
# Separate resource required because settings:dt.security_context boundaries
# cannot be mixed with storage:dt.security_context boundaries in one binding.
# This is the ONLY source of settings:objects:write for BU Admins.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "bu_admins_settings" {
  for_each = var.business_units

  group   = dynatrace_iam_group.bu_admins[each.key].id
  account = var.account_id

  # Scoped settings write — bounded to BU entities only
  # lower() ensures bucket names are always lowercase
  policy {
    id         = dynatrace_iam_policy.scoped_settings_write.id
    boundaries = [dynatrace_iam_policy_boundary.bu_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.key}-")
    }
  }

  depends_on = [dynatrace_iam_policy_bindings_v2.bu_admins_data]
}

# ------------------------------------------------------------------------------
# BU User Bindings — Resource 1: Data + Settings Read
# Read-only access to Grail data within their BU.
# Standard User already provides: documents, SLO read, automation read,
# Davis AI, segments. Single resource is sufficient.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_bindings_v2" "bu_users_data" {
  for_each = var.business_units

  group   = dynatrace_iam_group.bu_users[each.key].id
  account = var.account_id

  # Standard User access for basic environment features
  policy {
    id = data.dynatrace_iam_policy.standard_user.id
  }

  # Scoped data read using templated policy with BU prefix parameter
  # lower() ensures bucket names are always lowercase
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.key}-")
    }
  }

  # Entities read with BU boundary
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  # Default data read policies with BU boundary — required for bucket-level access.
  # See LESSONS_LEARNED.md #19.
  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_metrics.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_spans.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_events.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  policy {
    id         = data.dynatrace_iam_policy.read_bizevents.id
    boundaries = [dynatrace_iam_policy_boundary.bu_boundary[each.key].id]
  }

  # Scoped settings read — additive over Standard User's global read,
  # but retained for explicitness
  policy {
    id         = dynatrace_iam_policy.scoped_settings_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_settings_boundary[each.key].id]
    parameters = {
      "security_context_prefix" = lower("${each.key}-")
    }
  }
}
