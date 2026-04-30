# ============================================================================
# Outputs
# ============================================================================

output "bu_admin_groups" {
  description = "BU Admin group IDs"
  value       = { for k, v in dynatrace_iam_group.bu_admins : k => v.id }
}

output "bu_user_groups" {
  description = "BU User group IDs"
  value       = { for k, v in dynatrace_iam_group.bu_users : k => v.id }
}

output "app_admin_groups" {
  description = "Application Admin group IDs"
  value       = { for k, v in dynatrace_iam_group.app_admins : k => v.id }
}

output "app_user_groups" {
  description = "Application User group IDs"
  value       = { for k, v in dynatrace_iam_group.app_users : k => v.id }
}

output "custom_policy_ids" {
  description = "Custom and templated policy IDs"
  value = {
    admin_features        = dynatrace_iam_policy.admin_features.id
    slo_manager           = dynatrace_iam_policy.slo_manager.id
    scoped_data_read      = dynatrace_iam_policy.scoped_data_read.id
    scoped_settings_write = dynatrace_iam_policy.scoped_settings_write.id
  }
}

output "boundary_ids" {
  description = "Boundary IDs"
  value = {
    bu_data      = { for k, v in dynatrace_iam_policy_boundary.bu_data : k => v.id }
    bu_settings  = { for k, v in dynatrace_iam_policy_boundary.bu_settings : k => v.id }
    app_data     = { for k, v in dynatrace_iam_policy_boundary.app_data : k => v.id }
    app_settings = { for k, v in dynatrace_iam_policy_boundary.app_settings : k => v.id }
  }
}

output "configuration_summary" {
  description = "Summary of the IAM configuration"
  value = {
    business_units   = keys(var.business_units)
    applications     = keys(var.applications)
    stages           = var.stages
    total_groups     = length(var.business_units) * 2 + length(var.applications) * 2
    total_boundaries = length(var.business_units) * 2 + length(var.applications) * 2
    total_bindings   = length(var.business_units) * 2 + length(var.applications) * 2
  }
}
