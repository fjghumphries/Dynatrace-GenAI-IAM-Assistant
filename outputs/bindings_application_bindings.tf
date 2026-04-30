# ============================================================================
# Application-Level Bindings
# ============================================================================
# gotcha #21: ONE binding resource per group.
# gotcha #19: Default data read policies REQUIRED for bucket access.
#
# Application boundaries enumerate stages (e.g., bu-platform-prod-app-alpha,
# bu-platform-dev-app-alpha). Default data read policies + boundaries provide
# scoped bucket access.
#
# Scoped Data Read template NOT used at app level — no single prefix covers
# one app across stages in the bu-stage-app format. Boundaries suffice.
#
# Scoped Settings Write uses BU prefix as param; the app settings boundary
# narrows effective scope to just this application's entities.
#
# App Admins: Standard User + SLO Manager + data read (bounded) +
#             settings write (bounded) + system events
# App Users:  Standard User + data read (bounded) + system events
# ============================================================================

resource "dynatrace_iam_policy_bindings_v2" "app_admins" {
  for_each    = var.applications
  group       = dynatrace_iam_group.app_admins[each.key].id
  environment = var.environment_id

  # --- Feature policies (tenant-wide) ---
  policy { id = data.dynatrace_iam_policy.standard_user.id }
  policy { id = dynatrace_iam_policy.slo_manager.id }
  policy { id = data.dynatrace_iam_policy.read_system_events.id }
  policy { id = dynatrace_iam_policy.anomaly_detection_write.id }

  # --- Default data read policies (bucket access + boundary scoping) ---
  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_metrics.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_spans.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_events.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_bizevents.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }

  # --- Scoped settings write (boundary narrows BU prefix to this app) ---
  policy {
    id         = dynatrace_iam_policy.scoped_settings_write.id
    boundaries = [dynatrace_iam_policy_boundary.app_settings[each.key].id]
    parameters = { "security_context_prefix" = "${lower(each.value.bu)}-" }
  }
}

resource "dynatrace_iam_policy_bindings_v2" "app_users" {
  for_each    = var.applications
  group       = dynatrace_iam_group.app_users[each.key].id
  environment = var.environment_id

  # --- Feature policies ---
  policy { id = data.dynatrace_iam_policy.standard_user.id }
  policy { id = data.dynatrace_iam_policy.read_system_events.id }
  policy { id = dynatrace_iam_policy.anomaly_detection_write.id }

  # --- Default data read policies (bucket access + boundary scoping) ---
  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_metrics.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_spans.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_events.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_bizevents.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.app_data[each.key].id]
  }
}
