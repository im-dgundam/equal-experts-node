terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    fastly = {
      source  = "fastly/fastly"
      version = ">= 8.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Fastly API key is read from the FASTLY_API_KEY environment variable by default.
# You may also set it explicitly: api_key = var.fastly_api_key
provider "fastly" {}

