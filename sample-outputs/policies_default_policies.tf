# ============================================================================
# Default Policies (Data Sources)
# ============================================================================
# Dynatrace-maintained policies referenced by name. Always up-to-date.
#
# Lesson #4:  Check defaults before creating custom policies
# Lesson #16: Admin User NOT used — unconditional settings:objects:write
# Lesson #19: Default data read policies REQUIRED for Grail bucket access
# ============================================================================

# --- Feature Access ---
data "dynatrace_iam_policy" "standard_user" {
  name = "Standard User"
}
# NOTE: Admin User intentionally excluded — see Lesson #16.

# --- Grail Data Read (use with boundaries) ---
data "dynatrace_iam_policy" "read_logs" {
  name = "Read Logs"
}

data "dynatrace_iam_policy" "read_metrics" {
  name = "Read Metrics"
}

data "dynatrace_iam_policy" "read_spans" {
  name = "Read Spans"
}

data "dynatrace_iam_policy" "read_events" {
  name = "Read Events"
}

data "dynatrace_iam_policy" "read_bizevents" {
  name = "Read BizEvents"
}

data "dynatrace_iam_policy" "read_entities" {
  name = "Read Entities"
}

# --- System Events (no security_context scoping) ---
data "dynatrace_iam_policy" "read_system_events" {
  name = "Read System Events"
}
