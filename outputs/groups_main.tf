# ============================================================================
# IAM Groups
# ============================================================================
# Two levels (BU, Application) × two roles (Admins, Users) = 4 group types.
# Permissions managed via dynatrace_iam_policy_bindings_v2.
# gotcha #9: Group hierarchy design
# ============================================================================

# --- BU Admins ---
# Full data access + scoped settings write within the BU.
resource "dynatrace_iam_group" "bu_admins" {
  for_each    = var.business_units
  name        = "${each.key}-Admins"
  description = "Admins for ${each.value.description}. Data + scoped settings write."

  lifecycle { ignore_changes = [permissions] }
}

# --- BU Users ---
# Read-only data access within the BU.
resource "dynatrace_iam_group" "bu_users" {
  for_each    = var.business_units
  name        = "${each.key}-Users"
  description = "Users for ${each.value.description}. Read-only data access."

  lifecycle { ignore_changes = [permissions] }
}

# --- Application Admins ---
# Data access + scoped settings write for one application.
resource "dynatrace_iam_group" "app_admins" {
  for_each    = var.applications
  name        = "${each.key}-Admins"
  description = "Admins for ${each.value.description}. Scoped data + settings write."

  lifecycle { ignore_changes = [permissions] }
}

# --- Application Users ---
# Read-only data access for one application.
resource "dynatrace_iam_group" "app_users" {
  for_each    = var.applications
  name        = "${each.key}-Users"
  description = "Users for ${each.value.description}. Read-only data access."

  lifecycle { ignore_changes = [permissions] }
}
