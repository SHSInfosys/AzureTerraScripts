provider "azurerm" {
  version = "~> 1.29.0"
}

provider "template" {
  version = "~> 2.1"
}

provider "null" {
  version = "~> 2.1"
}

provider "local" {
  version = "~> 1.2"
}

terraform {
  backend "azurerm" {
    resource_group_name = "wilson-ops"
    storage_account_name = "wilsonops"
    container_name = "terraform"
    key = "terraform.tfstate"
  }
}

variable "region" {
  default = "eastus"
}

locals {
  env = "${terraform.workspace}"
}

variable "name_suffix" {
  type = "map"
  default = {
    "test" = "env"
  }
}

resource "azurerm_resource_group" "wilson" {
  name = "wilson-${local.env}"
  location = "${var.region}"

  tags = {
    wilson_server_version = "${data.azurerm_image.wilson_server_release.name}"
    wilson_server_capacity = "${local.wilson_server_capacity}"

    wilson_coaches_version = "${data.azurerm_image.wilson_coaches_release.name}"
  }
}

data "azurerm_resource_group" "wilson" {
  name = "wilson-${local.env}"
}