variable "vn_cidr" {
  description = "CIDR for the VN"
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet"
  default = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for private subnet"
  default = "10.0.1.0/24"
}

variable "gateway_subnet_cidr" {
  description = "CIDR for gateway subnet"
  default = "10.0.2.0/24"
}

resource "azurerm_virtual_network" "default" {
  name = "virtual-network-${local.env}"
  address_space = ["${var.vn_cidr}"]
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"
}

resource "azurerm_subnet" "public_subnet" {
  name = "public-subnet-${local.env}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix = "${var.public_subnet_cidr}"
}

resource "azurerm_subnet" "private_subnet" {
  name = "private-subnet-${local.env}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix = "${var.private_subnet_cidr}"
}

resource "azurerm_subnet" "gateway_subnet" {
  name = "gateway-subnet-${local.env}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  virtual_network_name = "${azurerm_virtual_network.default.name}"
  address_prefix = "${var.gateway_subnet_cidr}"
}