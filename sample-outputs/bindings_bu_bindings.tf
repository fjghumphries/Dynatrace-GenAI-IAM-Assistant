# ============================================================================
# BU-Level Bindings
# ============================================================================
# Lesson #21: ONE binding resource per group — multiple resources overwrite.
# Lesson #19: Default data read policies REQUIRED for Grail bucket access.
# Lesson #20: Admin Features permissions are tenant-wide (cannot scope).
#
# BU Admins: Standard User + Admin Features + data read (bounded) +
#            settings write (bounded) + system events
# BU Users:  Standard User + data read (bounded) + system events
# ============================================================================

resource "dynatrace_iam_policy_bindings_v2" "bu_admins" {
  for_each    = var.business_units
  group       = dynatrace_iam_group.bu_admins[each.key].id
  environment = var.environment_id

  # --- Feature policies (no boundary — tenant-wide by nature) ---
  policy { id = data.dynatrace_iam_policy.standard_user.id }
  policy { id = dynatrace_iam_policy.admin_features.id }
  policy { id = data.dynatrace_iam_policy.read_system_events.id }
  policy { id = dynatrace_iam_policy.anomaly_detection_write.id }
  policy { id = dynatrace_iam_policy.openpipeline_management.id }

  # --- Scoped data read (WHERE-clause defense-in-depth) ---
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
    parameters = { "security_context_prefix" = "${lower(each.key)}-" }
  }

  # --- Default data read policies (bucket access — Lesson #19) ---
  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_metrics.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_spans.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_events.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_bizevents.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }

  # --- Scoped settings write (only source of settings:objects:write) ---
  policy {
    id         = dynatrace_iam_policy.scoped_settings_write.id
    boundaries = [dynatrace_iam_policy_boundary.bu_settings[each.key].id]
    parameters = { "security_context_prefix" = "${lower(each.key)}-" }
  }
}

resource "dynatrace_iam_policy_bindings_v2" "bu_users" {
  for_each    = var.business_units
  group       = dynatrace_iam_group.bu_users[each.key].id
  environment = var.environment_id

  # --- Feature policies ---
  policy { id = data.dynatrace_iam_policy.standard_user.id }
  policy { id = data.dynatrace_iam_policy.read_system_events.id }
  policy { id = dynatrace_iam_policy.anomaly_detection_write.id }

  # --- Scoped data read (WHERE-clause defense-in-depth) ---
  policy {
    id         = dynatrace_iam_policy.scoped_data_read.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
    parameters = { "security_context_prefix" = "${lower(each.key)}-" }
  }

  # --- Default data read policies (bucket access — Lesson #19) ---
  policy {
    id         = data.dynatrace_iam_policy.read_logs.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_metrics.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_spans.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_events.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_bizevents.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
  policy {
    id         = data.dynatrace_iam_policy.read_entities.id
    boundaries = [dynatrace_iam_policy_boundary.bu_data[each.key].id]
  }
}
