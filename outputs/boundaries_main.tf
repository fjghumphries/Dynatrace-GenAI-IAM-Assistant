# ============================================================================
# Policy Boundaries
# ============================================================================
# Boundaries decouple the "What" (permissions) from the "Where" (conditions).
# They restrict access based on dt.security_context field using startsWith()
# for hierarchical scoping as per the governance rules.
#
# Security Context Format: bu-stage-application-component (LOWERCASE)
# Example: bu1-prod-petclinic01-api
#
# NOTE: Grail bucket names must be lowercase. Since dt.security_context maps
# to bucket names, lower() is used throughout to ensure all values are lowercase.
#
# IMPORTANT:
# - Boundaries don't support AND operator — each line is a separate condition
# - Conditions are applied only to permissions that support them
# - storage:dt.security_context applies to Grail storage permissions
# - settings:dt.security_context applies to settings on entities with security context
# ============================================================================

# ------------------------------------------------------------------------------
# BU-Level Data Boundaries
# These boundaries restrict access to ALL data within a specific Business Unit
# Uses startsWith to match the hierarchical security context pattern.
# Captures all stages, applications, and components within the BU — including
# any new applications added in the future.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_boundary" "bu_boundary" {
  for_each = var.business_units

  name = "Boundary-${each.key}"

  # lower() ensures bucket names are always lowercase
  query = "storage:dt.security_context startsWith \"${lower(each.key)}-\";"
}

# ------------------------------------------------------------------------------
# BU Settings Boundaries
# For BU admins who need to change settings across the entire BU
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_boundary" "bu_settings_boundary" {
  for_each = var.business_units

  name = "Boundary-${each.key}-Settings"

  # Settings namespace uses settings:dt.security_context (not storage:)
  # lower() ensures bucket names are always lowercase
  query = "settings:dt.security_context startsWith \"${lower(each.key)}-\";"
}

# ------------------------------------------------------------------------------
# Application-Level Data Boundaries
# These boundaries restrict access to data within a specific Application.
# More restrictive than BU boundaries — used for application-specific teams.
# The boundary enumerates each active stage to match the security_context format:
#   bu-stage-application
# Dynamic generation ensures only configured stages are included.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_boundary" "application_boundary" {
  for_each = var.applications

  name = "Boundary-${each.key}"

  # Dynamically generate one condition per configured stage.
  # Format: bu-stage-application matches all components within that application/stage.
  # lower() ensures bucket names are always lowercase.
  query = join("\n", [
    for stage in each.value.stages :
    "storage:dt.security_context startsWith \"${lower(each.value.bu)}-${lower(stage)}-${lower(each.key)}\";"
  ])
}

# ------------------------------------------------------------------------------
# Application Settings Boundaries
# For application admins who need to change settings on their application's entities.
# Uses settings:dt.security_context for settings on entities.
# ------------------------------------------------------------------------------

resource "dynatrace_iam_policy_boundary" "application_settings_boundary" {
  for_each = var.applications

  name = "Boundary-${each.key}-Settings"

  # Dynamically generate one condition per configured stage.
  # Settings namespace uses settings:dt.security_context (not storage:)
  # lower() ensures bucket names are always lowercase.
  query = join("\n", [
    for stage in each.value.stages :
    "settings:dt.security_context startsWith \"${lower(each.value.bu)}-${lower(stage)}-${lower(each.key)}\";"
  ])
}
