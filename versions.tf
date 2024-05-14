terraform {
  required_version = ">= 1.3.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.16.0, <= 5.27.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.0"
    }
  }
}
