variable "cluster_name" {}
data "google_client_config" "default" {}

resource "kubectl_manifest" "cert_manager_cluster_issuer" {
  yaml_body = file("../${path.root}/k8s/issuer-lets-encrypt-production.yaml")
}

resource "kubectl_manifest" "nginx_ingress_controller" {
  yaml_body = file("../${path.root}/k8s/djangoapp-ingress.yaml")
}

###################### Static IP ingress setup ######################
# (https://awstip.com/gke-load-balancing-with-custom-ingress-controller-using-nginx-terraform-helm-dd7c604995e)

# # Static IPv4 address for Ingress Load Balancing
# resource "google_compute_global_address" "ingress-ipv4" {
#   name         = "${var.cluster_name}-ingress-ipv4"
#   address_type = "EXTERNAL"
#   ip_version   = "IPV4"
# }

resource "google_compute_firewall" "gke_health_check_rules" {
  project       = data.google_client_config.default.project
  name          = "gke-health-check"
  network       = "default"
  description   = "A firewall rule to allow health check from Google Cloud to GKE"
  priority      = 1000
  direction     = "INGRESS"
  disabled      = false
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["gke-${var.cluster_name}"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "helm_release" "nginx_ingress_controller" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  values     = ["${file("${path.module}/NEG_values.yaml")}"]
}

resource "google_compute_health_check" "backend_service_http_health_check" {
  name                = "gke-${var.cluster_name}-backend-http-health-check"
  description         = "Health check via http"
  project             = data.google_client_config.default.project
  timeout_sec         = 1
  check_interval_sec  = 60
  healthy_threshold   = 4
  unhealthy_threshold = 5

  http_health_check {
    port               = "80"
    port_specification = "USE_FIXED_PORT"
    proxy_header       = "NONE"
    request_path       = "/"
  }
  depends_on = [
    helm_release.nginx_ingress_controller
  ]
}

resource "google_compute_backend_service" "gke_backend_service" {
  affinity_cookie_ttl_sec = "0"
  name                    = "gke-${var.cluster_name}-backend-service"
  port_name               = "http"
  project                 = data.google_client_config.default.project
  protocol                = "HTTP"
  session_affinity        = "NONE"
  timeout_sec             = "30"
  log_config {
    enable      = "true"
    sample_rate = "1"
  }
  load_balancing_scheme           = "EXTERNAL"
  enable_cdn                      = true
  connection_draining_timeout_sec = "300"
  health_checks                   = [google_compute_health_check.backend_service_http_health_check.self_link]
  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    client_ttl                   = "3600"
    default_ttl                  = "3600"
    max_ttl                      = "86400"
    negative_caching             = "true"
    serve_while_stale            = "86400"
    signed_url_cache_max_age_sec = "0"
    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = true
    }
  }

  # backend {
  #   balancing_mode        = "RATE"
  #   capacity_scaler       = "1"
  #   group                 = "gke-${var.cluster_name}-backend-service" # this doesn't work
  #   max_rate_per_endpoint = "1"
  # }
  # check the NEGs here: https://console.cloud.google.com/compute/networkendpointgroups/list?referrer=search&project=phx-datadissemination&supportedpurview=project&rapt=AEjHL4PmEk_3NQoD_wy5ILVksZVixACvFYMDKyJ3zDiwrI7VuPbBPZalyGTX7k8AyNZTQQreXXBityY7PMCIq3V7FbSGxfYAlgi6OyLT8ssKwrqHicr39wY
  # backend {
  #   group           = google_compute_instance_group_manager.default.instance_group
  #   balancing_mode  = "UTILIZATION"
  #   max_utilization = 1.0
  #   capacity_scaler = 1.0
  # }
}

resource "google_compute_url_map" "url_map" {
  name    = "gke-${var.cluster_name}-url-map"
  project = data.google_client_config.default.project

  default_service = google_compute_backend_service.gke_backend_service.self_link
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "gke-${var.cluster_name}-http-proxy"
  project = data.google_client_config.default.project
  url_map = google_compute_url_map.url_map.self_link
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = "gke-${var.cluster_name}-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.self_link
  ip_address            = google_compute_global_address.ingress-ipv4.address
  project               = data.google_client_config.default.project
}


# Self-signed regional SSL certificate for testing
resource "tls_private_key" "default" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "default" {
  private_key_pem = tls_private_key.default.private_key_pem

  # Certificate expires after 12 hours.
  validity_period_hours = 12

  # Generate a new certificate if Terraform is run within three
  # hours of the certificate's expiration time.
  early_renewal_hours = 3

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["example.com"]

  subject {
    common_name  = "example.com"
    organization = "ACME Examples, Inc"
  }
}

###### HTTPS stuff (WIP) ######
resource "google_compute_ssl_certificate" "default" {
  name        = "default-cert"
  private_key = tls_private_key.default.private_key_pem
  certificate = tls_self_signed_cert.default.cert_pem
}

resource "google_compute_target_ssl_proxy" "default" {
  name             = "test-proxy"
  backend_service  = google_compute_backend_service.gke_backend_service.id
  ssl_certificates = [google_compute_ssl_certificate.default.id]
}

# forwarding rule
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "ssl-proxy-xlb-forwarding-rule"
  provider              = google
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_ssl_proxy.default.id
  ip_address            = google_compute_global_address.ingress-ipv4.id
}
