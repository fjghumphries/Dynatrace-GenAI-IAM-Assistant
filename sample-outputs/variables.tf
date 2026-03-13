# ============================================================================
# Variables Configuration
# ============================================================================
# Security context format: bu-stage-application-component (LOWERCASE)
# All values defined lowercase to match Grail bucket naming requirements.
# Lesson #18: All IAM values must be lowercase.
# ============================================================================

variable "account_id" {
  description = "The Dynatrace Account UUID (without urn:dtaccount: prefix)"
  type        = string
}

variable "environment_id" {
  description = "The Dynatrace Environment ID (e.g., abc12345)"
  type        = string
}

variable "business_units" {
  description = "Map of Business Units"
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
     "bu3" = {
      name         = "bu3"
      description  = "Business Unit 3"
      applications = ["petclinic03"]
    }
  }
}

variable "applications" {
  description = "Map of Applications. Each belongs to exactly one BU."
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
    "petclinic03" = {
      name        = "petclinic03"
      description = "PetClinic 03 - belongs to bu3"
      bu          = "bu3"
      stages      = ["prod", "dev"]
    }
  }
}

variable "stages" {
  description = "List of deployment stages"
  type        = list(string)
  default     = ["prod", "dev"]
}

variable "tags" {
  description = "Tags to apply to all IAM resources"
  type        = set(string)
  default     = ["managed-by-terraform", "iam-config"]
}
