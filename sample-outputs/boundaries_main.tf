# ============================================================================
# Policy Boundaries
# ============================================================================
# Boundaries restrict access based on dt.security_context using startsWith().
# Two namespaces: storage:dt.security_context and settings:dt.security_context.
#
# Lesson #2:  Boundaries decouple "What" from "Where"
# Lesson #8:  Storage vs settings use different condition namespaces
# Lesson #18: All values lowercase for Grail bucket compatibility
# ============================================================================

# --- BU-Level Data Boundaries ---
# Captures all stages, applications, and components within the BU.
resource "dynatrace_iam_policy_boundary" "bu_data" {
  for_each = var.business_units
  name     = "Boundary-${each.key}-Data"
  query    = "storage:dt.security_context startsWith \"${lower(each.key)}-\";"
}

# --- BU-Level Settings Boundaries ---
resource "dynatrace_iam_policy_boundary" "bu_settings" {
  for_each = var.business_units
  name     = "Boundary-${each.key}-Settings"
  query    = "settings:dt.security_context startsWith \"${lower(each.key)}-\";"
}

# --- Application-Level Data Boundaries ---
# Enumerates each active stage for the application.
resource "dynatrace_iam_policy_boundary" "app_data" {
  for_each = var.applications
  name     = "Boundary-${each.key}-Data"
  query = join("\n", [
    for stage in each.value.stages :
    "storage:dt.security_context startsWith \"${lower(each.value.bu)}-${lower(stage)}-${lower(each.key)}\";"
  ])
}

# --- Application-Level Settings Boundaries ---
resource "dynatrace_iam_policy_boundary" "app_settings" {
  for_each = var.applications
  name     = "Boundary-${each.key}-Settings"
  query = join("\n", [
    for stage in each.value.stages :
    "settings:dt.security_context startsWith \"${lower(each.value.bu)}-${lower(stage)}-${lower(each.key)}\";"
  ])
}
