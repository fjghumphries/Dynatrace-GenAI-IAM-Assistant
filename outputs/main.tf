# ============================================================================
# Main Configuration - Module Composition
# ============================================================================
# This file brings together all the IAM components.
#
# Configuration is split across:
# - boundaries_main.tf          : Policy boundary definitions
# - policies_default_policies.tf: References to Dynatrace default policies
# - policies_templated_policies.tf: Parameterized custom policies
# - policies_custom_policies.tf : Specialized access policies
# - groups_main.tf              : Group definitions
# - bindings_bu_bindings.tf     : BU-level policy bindings
# - bindings_application_bindings.tf: Application-level policy bindings
# ============================================================================
