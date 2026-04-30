# ============================================================================
# Templated Policies (Parameterised)
# ============================================================================
# Uses ${bindParam:...} so one policy serves many groups with different scopes.
#
# gotcha #3: Templates reduce management overhead at scale
# gotcha #5: settings:objects:read is unconditional via Standard User
#            — no Scoped Settings Read needed
# ============================================================================

# --- Scoped Data Read ---
# WHERE-clause filtering on security_context. Defense-in-depth alongside
# default data read policies + boundaries (which provide bucket access).
resource "dynatrace_iam_policy" "scoped_data_read" {
  name        = "Scoped Grail Data Read"
  description = "Record-level filtering by security_context prefix."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
ALLOW storage:logs:read
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW storage:metrics:read
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW storage:spans:read
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW storage:events:read
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW storage:bizevents:read
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW storage:entities:read
  WHERE storage:dt.security_context startsWith "$${bindParam:security_context_prefix}";
EOT
}

# --- Scoped Settings Write ---
# ONLY source of settings:objects:write in this config.
# Admin User default policy is intentionally NOT used (gotcha #16).
resource "dynatrace_iam_policy" "scoped_settings_write" {
  name        = "Scoped Settings Write"
  description = "Settings write scoped by security_context. For admins only."
  account     = var.account_id
  tags        = var.tags

  statement_query = <<-EOT
ALLOW settings:objects:read, settings:objects:write
  WHERE settings:dt.security_context startsWith "$${bindParam:security_context_prefix}";
ALLOW settings:schemas:read;
EOT
}
