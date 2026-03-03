terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
  backend "local" {
    path = "./terraform.tfstate"
  }
}

resource "random_string" "example" {
  length  = 16
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "local_file" "example_file" {
  filename = "./random_string.txt"
  content  = random_string.example.result
}

output "generated_random_string" {
  value       = random_string.example.result
  description = "This is the randomly generated string displayed on the screen"
}
