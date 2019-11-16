resource "azurerm_lb" "wilson_server" {
  name = "wilson-load-balancer-${local.env}"
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"

  frontend_ip_configuration {
    name = "internal"
    subnet_id = "${azurerm_subnet.private_subnet.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "wilson_server" {
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  loadbalancer_id = "${azurerm_lb.wilson_server.id}"
  name = "wilson-backend-address-pool"
}

resource "azurerm_lb_probe" "wilson_server" {
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  loadbalancer_id = "${azurerm_lb.wilson_server.id}"
  name = "health"
  request_path = "/health"
  protocol = "Http"
  port = 80
}

resource "azurerm_lb_rule" "wilson" {
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  loadbalancer_id = "${azurerm_lb.wilson_server.id}"
  name = "wilson-server"
  protocol = "Tcp"
  frontend_port = 80
  backend_port = 80
  probe_id = "${azurerm_lb_probe.wilson_server.id}"
  frontend_ip_configuration_name = "internal"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.wilson_server.id}"
}

variable "wilson_server_live" {
  type = "map"
  description = "Configuration. Keys: version, capacity"
  default = {}
}

locals {
  # Pegged Vars
  wilson_server_version_current = "${lookup(data.azurerm_resource_group.wilson.tags, "wilson_server_version", "wilson-server-\\d+$")}"
  wilson_server_capacity_current = "${lookup(data.azurerm_resource_group.wilson.tags, "wilson_server_capacity", 2)}"
  wilson_server_live_version = "${lookup(data.azurerm_resource_group.wilson.tags, "wilson_server_version", "")}"
  wilson_server_image_id = "${data.azurerm_image.wilson_server_release.id}"
  wilson_server_capacity = "${lookup(var.wilson_server_live, "capacity", local.wilson_server_capacity_current)}"
  wilson_server_version = "${lookup(var.wilson_server_live, "version", local.wilson_server_version_current)}"
}

variable "wilson_server_version_regex" {
  default = "wilson-server-\\d+$"
}

data "azurerm_image" "wilson_server_latest_image" {
  resource_group_name = "wilson-ops"
  name_regex = "${var.wilson_server_version_regex}"
  sort_descending = true
}

locals {
  wilson_server_release_name_regex = "${
    local.wilson_server_version == "latest"
    ? var.wilson_server_version_regex
    : local.wilson_server_version
  }"
}

data "azurerm_image" "wilson_server_release" {
  resource_group_name = "wilson-ops"
  name_regex = "${local.wilson_server_release_name_regex}"
  sort_descending = true
}

resource "azurerm_virtual_machine_scale_set" "wilson_server" {
  name = "wilson-server-${local.env}"
  depends_on = ["null_resource.provision_db"]
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"

  upgrade_policy_mode  = "Rolling"

  rolling_upgrade_policy {
    max_batch_instance_percent = 50
    max_unhealthy_instance_percent = 50
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches = "PT0S"
  }

  health_probe_id = "${azurerm_lb_probe.wilson_server.id}"

  sku {
    tier = "Standard"
    name = "Standard_DS2_v2"
    capacity = "${local.wilson_server_capacity}"
  }

  os_profile {
    computer_name_prefix = "wilson-server-${local.env}"
    admin_username = "azureuser"
    admin_password = "azureuser"
    custom_data = "${data.template_file.wilson_server_init.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path = "/home/azureuser/.ssh/authorized_keys"
      key_data = "${file("keys/azureuser.pub")}"
    }
  }

  storage_profile_image_reference {
    id = "${local.wilson_server_image_id}"
  }

  storage_profile_os_disk {
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  network_profile {
    name = "wilson-server-network-profile"
    primary = true

    ip_configuration {
      name = "wilson-server-ip-config"
      primary = true
      subnet_id = "${azurerm_subnet.public_subnet.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.wilson_server.id}"]
    }
  }
}

data "template_file" "wilson_server_init" {
  template = "${file("wilson_server/wilson_server.yaml.tpl")}"

  vars = {
    env = "${local.env}"
    url_host = "${local.wilson_server_hostname}"
    content_host = "${local.wilson_content_hostname}"
    instrumentation_key = "${azurerm_application_insights.wilson_server_insights.instrumentation_key}"
    wilson_admin_username = "${data.azurerm_key_vault_secret.admin_username.value}"
    wilson_admin_password = "${data.azurerm_key_vault_secret.admin_password.value}"
    db_server_name = "${azurerm_postgresql_server.wilson_psql.name}"
    db_host = "${local.db_host}"
    db_name = "${azurerm_postgresql_database.wilson_opdb.name}"
    db_password = "${data.azurerm_key_vault_secret.opdb_password.value}"
    identity_db_host = "${local.db_host}"
    identity_db_name = "${azurerm_postgresql_database.wilson_identitydb.name}"
    identity_db_password = "${data.azurerm_key_vault_secret.idb_password.value}"
    semiprivate_db_host = "${local.db_host}"
    semiprivate_db_name = "${azurerm_postgresql_database.wilson_semiprivatedb.name}"
    semiprivate_db_password = "${data.azurerm_key_vault_secret.sdb_password.value}"
    azure_storage_account = "${azurerm_storage_account.wilson_storage.name}"
    azure_storage_key = "${azurerm_storage_account.wilson_storage.primary_access_key}"
    azure_queue_endpoint = "${azurerm_storage_account.wilson_storage.primary_queue_endpoint}"
    azure_blob_endpoint = "${azurerm_storage_account.wilson_storage.primary_blob_endpoint}"
  }
}

resource "azurerm_application_insights" "wilson_server_insights" {
  name = "wilson-server-${local.env}"
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  application_type = "Other"
}

output "wilson_server_health" {
  value = "https://${local.wilson_server_hostname}/health"
}

output "wilson_server_live_version" {
  value = "${local.wilson_server_live_version}"
}

output "wilson_server_latest_version" {
  value = "${data.azurerm_image.wilson_server_latest_image.name}"
}

output "wilson_server_instrumentation_key" {
  value = "${azurerm_application_insights.wilson_server_insights.instrumentation_key}"
}