# ============================================================================
# Custom Policies
# ============================================================================
# Lesson #16: Admin Features replaces Admin User — no unconditional settings write
# Lesson #17: hub:catalog-items:install and activegate:* are NOT valid identifiers
# Lesson #20: Feature permissions (automation, slo, extensions, app-engine) are
#             tenant-wide — cannot be scoped by security_context
# Lesson #22: OpenPipeline is now managed via Settings 2.0 (builtin:openpipeline.*)
#             The old openpipeline:configurations:* permissions are removed.
# ============================================================================

# --- Admin Features (No Settings Write) ---
# For BU Admins. Admin capabilities WITHOUT settings:objects:write.
# Settings write comes from the bounded Scoped Settings Write policy.
resource "dynatrace_iam_policy" "admin_features" {
  name        = "Admin Features (No Settings Write)"
  description = "Admin feature access without settings write. Use with Scoped Settings Write for bounded settings."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
ALLOW automation:workflows:read, automation:workflows:write, automation:workflows:run, automation:workflows:admin;
ALLOW automation:calendars:read, automation:calendars:write;
ALLOW automation:rules:read, automation:rules:write;
ALLOW slo:slos:read, slo:slos:write;
ALLOW slo:objective-templates:read;
ALLOW extensions:definitions:read, extensions:definitions:write;
ALLOW extensions:configurations:read, extensions:configurations:write;
ALLOW app-engine:apps:install, app-engine:apps:delete, app-engine:apps:run;
EOT
}

# --- Anomaly Detection Write ---
# For ALL groups (Admins and Users at both BU and Application level).
# Grants settings write scoped to anomaly-detection schemas only.
# Unbounded — schemaGroup condition limits scope to anomaly detection.
resource "dynatrace_iam_policy" "anomaly_detection_write" {
  name        = "Anomaly Detection Write"
  description = "Settings write for anomaly detection schemas. For all users."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
ALLOW settings:objects:write
  WHERE settings:schemaGroup = "group:anomaly-detection";
EOT
}

# --- OpenPipeline Management ---
# For BU Admins only. Grants settings write for pipeline definitions per signal.
# Intentionally excludes .routing and .pipeline-groups schemas (Lesson #22).
# Read access is not needed — Standard User already grants unconditional settings:objects:read.
resource "dynatrace_iam_policy" "openpipeline_management" {
  name        = "OpenPipeline Management"
  description = "Settings write for OpenPipeline pipeline configurations. Routing and pipeline-group write intentionally excluded."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.bizevents.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.davis.events.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.davis.problems.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.events.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.events.sdlc.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.events.security.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.logs.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.metrics.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.security.events.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.spans.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.system.events.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.user.events.pipelines";
ALLOW settings:objects:write WHERE settings:schemaId = "builtin:openpipeline.usersessions.pipelines";
EOT
}

# --- SLO Manager ---
# For Application Admins — SLO write without full admin features.
# BU Admins get SLO write via Admin Features; this is only for app-level.
resource "dynatrace_iam_policy" "slo_manager" {
  name        = "SLO Manager"
  description = "SLO read/write for application admins."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
ALLOW slo:slos:read, slo:slos:write;
ALLOW slo:objective-templates:read;
EOT
}
