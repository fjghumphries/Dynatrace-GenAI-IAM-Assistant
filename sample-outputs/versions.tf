terraform {
  required_version = ">= 1.0"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.91"
    }
  }
}
