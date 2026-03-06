# ============================================================================
# Variables Configuration
# ============================================================================
# This file defines all variables used across the IAM configuration.
# Security context format: bu-stage-application-component (LOWERCASE)
# Example: bu1-prod-petclinic01-api
#
# NOTE: All values are lowercase to match Grail bucket naming requirements.
# The lower() function is retained as a safety net in boundaries and bindings.
# All variable keys and values should be defined lowercase at source.
# ============================================================================

# ------------------------------------------------------------------------------
# Account Configuration
# ------------------------------------------------------------------------------
variable "account_id" {
  description = "The Dynatrace Account UUID (without urn:dtaccount: prefix)"
  type        = string
}

variable "environment_id" {
  description = "The Dynatrace Environment ID (e.g., abc12345)"
  type        = string
}

# ------------------------------------------------------------------------------
# Business Units (BUs)
# ------------------------------------------------------------------------------
variable "business_units" {
  description = "Map of Business Units with their configuration"
  type = map(object({
    name         = string
    description  = string
    applications = list(string)
  }))
  default = {
    "bu1" = {
      name         = "bu1"
      description  = "Business Unit 1"
      applications = ["petclinic01"]
    }
    "bu2" = {
      name         = "bu2"
      description  = "Business Unit 2"
      applications = ["petclinic02"]
    }
  }
}

# ------------------------------------------------------------------------------
# Applications
# Each application belongs to a specific BU.
# Security context format: {bu}-{stage}-{name}  e.g. bu1-prod-petclinic01
# ------------------------------------------------------------------------------
variable "applications" {
  description = "Map of Applications with their configuration"
  type = map(object({
    name        = string
    description = string
    bu          = string
    stages      = list(string)
  }))
  default = {
    "petclinic01" = {
      name        = "petclinic01"
      description = "PetClinic 01 - belongs to bu1"
      bu          = "bu1"
      stages      = ["prod", "dev"]
    }
    "petclinic02" = {
      name        = "petclinic02"
      description = "PetClinic 02 - belongs to bu2"
      bu          = "bu2"
      stages      = ["prod", "dev"]
    }
  }
}

# ------------------------------------------------------------------------------
# Stages (environments within each application)
# ------------------------------------------------------------------------------
variable "stages" {
  description = "List of deployment stages"
  type        = list(string)
  default     = ["prod", "dev"]
}

# ------------------------------------------------------------------------------
# Common Tags for Resources
# ------------------------------------------------------------------------------
variable "tags" {
  description = "Tags to apply to all IAM resources"
  type        = set(string)
  default     = ["managed-by-terraform", "iam-config"]
}
