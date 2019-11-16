resource "azurerm_public_ip" "wilson_gateway" {
  name = "wilson-gateway-${local.env}"
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  allocation_method = "Dynamic"
  domain_name_label = "wilson-gateway-${local.env}"
}

data "azurerm_key_vault" "ssl_certs" {
  name = "wilson-ssl-certs"
  resource_group_name = "wilson-ops"
}

data "azurerm_key_vault_secret" "ssl_cert" {
  name = "ssl-${local.env}-pfx"
  key_vault_id = "${data.azurerm_key_vault.ssl_certs.id}"
}

data "azurerm_key_vault_secret" "apex_ssl_cert" {
  name = "ssl-apex-pfx"
  key_vault_id = "${data.azurerm_key_vault.ssl_certs.id}"
}

resource "azurerm_application_gateway" "wilson" {
  name = "wilson-gateway-${local.env}"
  resource_group_name = "${azurerm_resource_group.wilson.name}"
  location = "${var.region}"

  ssl_policy {
    disabled_protocols = ["TLSv1_0"]
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  }

  sku {
    name = "Standard_Medium"
    tier = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name = "default"
    subnet_id = "${azurerm_virtual_network.default.id}/subnets/${azurerm_subnet.gateway_subnet.name}"
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_port {
    name = "https"
    port = 443
  }

  frontend_ip_configuration {
    name = "default"
    public_ip_address_id = "${azurerm_public_ip.wilson_gateway.id}"
  }

  ssl_certificate {
    name = "wilson-gateway-${local.env}"
    data = "${data.azurerm_key_vault_secret.ssl_cert.value}"
    password = ""
  }

  ssl_certificate {
    name = "wilson-gateway-${local.env}-apex"
    data = "${data.azurerm_key_vault_secret.apex_ssl_cert.value}"
    password = ""
  }

  # wilson-server
  http_listener {
    name = "wilson-server-http"
    frontend_port_name = "http"
    frontend_ip_configuration_name = "default"
    protocol = "Http"
    host_name = "${local.wilson_server_hostname}"
  }

  http_listener {
    name = "wilson-server-https"
    frontend_port_name = "https"
    frontend_ip_configuration_name = "default"
    protocol = "Https"
    ssl_certificate_name = "wilson-gateway-${local.env}"
    host_name = "${local.wilson_server_hostname}"
    require_sni = true
  }

  http_listener {
    name = "wilson-server-apex-http"
    frontend_port_name = "http"
    frontend_ip_configuration_name = "default"
    protocol = "Http"
    host_name = "${local.wilson_server_apex_hostname}"
  }

  http_listener {
    name = "wilson-server-apex-https"
    frontend_port_name = "https"
    frontend_ip_configuration_name = "default"
    protocol = "Https"
    ssl_certificate_name = "wilson-gateway-${local.env}-apex"
    host_name = "${local.wilson_server_apex_hostname}"
    require_sni = true
  }

  probe {
    name = "health"
    protocol = "Http"
    path = "/health"
    host = "${azurerm_lb.wilson_server.private_ip_address}"
    interval = 5
    timeout = 30
    unhealthy_threshold = 1
  }

  backend_http_settings {
    name = "wilson-server-lb"
    cookie_based_affinity = "Enabled"
    port = 80
    protocol = "Http"
    probe_name = "health"
    request_timeout = 30
  }

  backend_address_pool {
    name = "wilson-server-lb-${local.env}"
    ip_addresses = [
      "${azurerm_lb.wilson_server.private_ip_address}"
    ]
  }

  request_routing_rule {
    name = "wilson-server-https"
    rule_type = "Basic"
    http_listener_name = "wilson-server-https"
    backend_http_settings_name = "wilson-server-lb"
    backend_address_pool_name = "wilson-server-lb-${local.env}"
  }

  redirect_configuration {
    name = "wilson-server-http-redirect"
    redirect_type = "Permanent"
    target_listener_name = "wilson-server-https"
    include_path = true
    include_query_string = true
  }

  request_routing_rule {
    name = "wilson-server-http-redirect"
    http_listener_name = "wilson-server-http"
    rule_type = "Basic"
    redirect_configuration_name = "wilson-server-http-redirect"
  }

  request_routing_rule {
    name = "wilson-server-apex-https"
    rule_type = "Basic"
    http_listener_name = "wilson-server-apex-https"
    backend_http_settings_name = "wilson-server-lb"
    backend_address_pool_name = "wilson-server-lb-${local.env}"
  }

  redirect_configuration {
    name = "wilson-server-apex-http-redirect"
    redirect_type = "Permanent"
    target_listener_name = "wilson-server-apex-https"
    include_path = true
    include_query_string = true
  }

  request_routing_rule {
    name = "wilson-server-apex-http-redirect"
    http_listener_name = "wilson-server-apex-http"
    rule_type = "Basic"
    redirect_configuration_name = "wilson-server-apex-http-redirect"
  }

  # wilson-coaches
  http_listener {
    name = "wilson-coaches-http"
    frontend_port_name = "http"
    frontend_ip_configuration_name = "default"
    protocol = "Http"
    host_name = "${local.wilson_coaches_hostname}"
  }

  http_listener {
    name = "wilson-coaches-https"
    frontend_port_name = "https"
    frontend_ip_configuration_name = "default"
    protocol = "Https"
    ssl_certificate_name = "wilson-gateway-${local.env}"
    host_name = "${local.wilson_coaches_hostname}"
    require_sni = true
  }

  http_listener {
    name = "wilson-coaches-apex-http"
    frontend_port_name = "http"
    frontend_ip_configuration_name = "default"
    protocol = "Http"
    host_name = "${local.wilson_coaches_apex_hostname}"
  }

  http_listener {
    name = "wilson-coaches-apex-https"
    frontend_port_name = "https"
    frontend_ip_configuration_name = "default"
    protocol = "Https"
    ssl_certificate_name = "wilson-gateway-${local.env}-apex"
    host_name = "${local.wilson_coaches_apex_hostname}"
    require_sni = true
  }

  backend_http_settings {
    name = "wilson-coaches-http"
    cookie_based_affinity = "Enabled"
    port = 80
    protocol = "Http"
    request_timeout = 30
  }

  backend_address_pool {
    name = "wilson-coaches-pool-${local.env}"
  }

  request_routing_rule {
    name = "wilson-coaches-https"
    rule_type = "Basic"
    http_listener_name = "wilson-coaches-https"
    backend_http_settings_name = "wilson-coaches-http"
    backend_address_pool_name = "wilson-coaches-pool-${local.env}"
  }

  redirect_configuration {
    name = "wilson-coaches-http-redirect"
    redirect_type = "Permanent"
    target_listener_name = "wilson-coaches-https"
    include_path = true
    include_query_string = true
  }

  request_routing_rule {
    name = "wilson-coaches-http-redirect"
    http_listener_name = "wilson-coaches-http"
    rule_type = "Basic"
    redirect_configuration_name = "wilson-coaches-http-redirect"
  }

  request_routing_rule {
    name = "wilson-coaches-apex-https"
    rule_type = "Basic"
    http_listener_name = "wilson-coaches-apex-https"
    backend_http_settings_name = "wilson-coaches-http"
    backend_address_pool_name = "wilson-coaches-pool-${local.env}"
  }

  redirect_configuration {
    name = "wilson-coaches-apex-http-redirect"
    redirect_type = "Permanent"
    target_listener_name = "wilson-coaches-apex-https"
    include_path = true
    include_query_string = true
  }

  request_routing_rule {
    name = "wilson-coaches-apex-http-redirect"
    http_listener_name = "wilson-coaches-apex-http"
    rule_type = "Basic"
    redirect_configuration_name = "wilson-coaches-apex-http-redirect"
  }

  # app-host
  http_listener {
    name = "wilson-app-host-http"
    frontend_port_name = "http"
    frontend_ip_configuration_name = "default"
    protocol = "Http"
    host_name = "${local.wilson_app_hostname}"
  }

  http_listener {
    name = "wilson-app-host-https"
    frontend_port_name = "https"
    frontend_ip_configuration_name = "default"
    protocol = "Https"
    ssl_certificate_name = "wilson-gateway-${local.env}"
    host_name = "${local.wilson_app_hostname}"
    require_sni = true
  }

  http_listener {
    name = "wilson-app-host-apex-http"
    frontend_port_name = "http"
    frontend_ip_configuration_name = "default"
    protocol = "Http"
    host_name = "${local.wilson_app_apex_hostname}"
  }

  http_listener {
    name = "wilson-app-host-apex-https"
    frontend_port_name = "https"
    frontend_ip_configuration_name = "default"
    protocol = "Https"
    ssl_certificate_name = "wilson-gateway-${local.env}-apex"
    host_name = "${local.wilson_app_apex_hostname}"
    require_sni = true
  }

  backend_http_settings {
    name = "wilson-app-host-http"
    cookie_based_affinity = "Enabled"
    port = 80
    protocol = "Http"
    probe_name = "health"
    request_timeout = 30
  }

  backend_address_pool {
    name = "wilson-app-host-pool-${local.env}"
    ip_addresses = [
      "${azurerm_network_interface.app_host.private_ip_address}"
    ]
  }

  request_routing_rule {
    name = "wilson-app-host-https"
    rule_type = "Basic"
    http_listener_name = "wilson-app-host-https"
    backend_http_settings_name = "wilson-app-host-http"
    backend_address_pool_name = "wilson-app-host-pool-${local.env}"
  }

  redirect_configuration {
    name = "wilson-app-host-http-redirect"
    redirect_type = "Permanent"
    target_listener_name = "wilson-app-host-https"
    include_path = true
    include_query_string = true
  }

  request_routing_rule {
    name = "wilson-app-host-http-redirect"
    http_listener_name = "wilson-app-host-http"
    rule_type = "Basic"
    redirect_configuration_name = "wilson-app-host-http-redirect"
  }

  request_routing_rule {
    name = "wilson-app-host-apex-https"
    rule_type = "Basic"
    http_listener_name = "wilson-app-host-apex-https"
    backend_http_settings_name = "wilson-app-host-http"
    backend_address_pool_name = "wilson-app-host-pool-${local.env}"
  }

  redirect_configuration {
    name = "wilson-app-host-apex-http-redirect"
    redirect_type = "Permanent"
    target_listener_name = "wilson-app-host-apex-https"
    include_path = true
    include_query_string = true
  }

  request_routing_rule {
    name = "wilson-app-host-apex-http-redirect"
    http_listener_name = "wilson-app-host-apex-http"
    rule_type = "Basic"
    redirect_configuration_name = "wilson-app-host-apex-http-redirect"
  }
}

locals {
  backend_address_pool_ids = {
    load_balancer = "${azurerm_application_gateway.wilson.backend_address_pool.0.id}"
    wilson_coaches = "${azurerm_application_gateway.wilson.backend_address_pool.1.id}"
    app_host = "${azurerm_application_gateway.wilson.backend_address_pool.2.id}"
  }
}

locals {
  gateway_hostname = "${azurerm_application_gateway.wilson.name}.${var.region}.cloudapp.azure.com"
}