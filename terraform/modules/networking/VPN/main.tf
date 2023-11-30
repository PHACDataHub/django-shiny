# based on this guide: https://cloud.google.com/build/docs/private-pools/accessing-private-gke-clusters-with-cloud-build-private-pools
# plus this article: https://cloud.google.com/network-connectivity/docs/vpn/how-to/automate-vpn-setup-with-terraform
variable "app_name" {}
variable "gke_vpc_name" {}
variable "cloudbuild_vpc_name" {}
variable "gke_clusters_subnetwork_id" {}
data "google_client_config" "default" {}

resource "random_password" "vpn_shared_secret" {
  length  = 16
  special = true
}

resource "google_compute_ha_vpn_gateway" "gke_vpn_gateway" {
  region  = data.google_client_config.default.region
  name    = "${var.app_name}-gke-vpn-gateway"
  network = var.gke_vpc_name
}

resource "google_compute_ha_vpn_gateway" "cloudbuild_vpn_gateway" {
  region  = data.google_client_config.default.region
  name    = "${var.app_name}-cloudbuild-vpn-gateway"
  network = var.cloudbuild_vpc_name
}

resource "google_compute_router" "gke_router" {
  name    = "${var.app_name}-gke-router"
  region  = data.google_client_config.default.region
  network = var.gke_vpc_name
  bgp {
    asn = 65001
  }
}

resource "google_compute_router" "cloudbuild_router" {
  name    = "${var.app_name}-cloudbuild-router"
  region  = data.google_client_config.default.region
  network = var.cloudbuild_vpc_name
  bgp {
    asn = 65002
  }
}

resource "google_compute_router_nat" "nat" {
  name   = "gke-nat-config"
  router = google_compute_router.gke_router.name
  region = data.google_client_config.default.region

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "MANUAL_ONLY" # for whitelisting

  subnetwork {
    name                    = var.gke_clusters_subnetwork_id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  nat_ips = [google_compute_address.nat.self_link]
}

resource "google_compute_address" "nat" {
  name         = "gke-nat"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

# Create two VPN tunnels for each gateway direction (for HA)
resource "google_compute_vpn_tunnel" "gke_tunnel1" {
  name                  = "${var.app_name}-gke-to-cloudbuild-tunnel1"
  region                = data.google_client_config.default.region
  vpn_gateway           = google_compute_ha_vpn_gateway.cloudbuild_vpn_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gke_vpn_gateway.id
  shared_secret         = random_password.vpn_shared_secret.result
  router                = google_compute_router.gke_router.id
  vpn_gateway_interface = 0
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "gke_tunnel2" {
  name                  = "${var.app_name}-gke-to-cloudbuild-tunnel2"
  region                = data.google_client_config.default.region
  vpn_gateway           = google_compute_ha_vpn_gateway.cloudbuild_vpn_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gke_vpn_gateway.id
  shared_secret         = random_password.vpn_shared_secret.result
  router                = google_compute_router.gke_router.id
  vpn_gateway_interface = 1
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "cloudbuild_tunnel1" {
  name                  = "${var.app_name}-cloudbuild-to-gke-tunnel1"
  region                = data.google_client_config.default.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gke_vpn_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.cloudbuild_vpn_gateway.id
  shared_secret         = random_password.vpn_shared_secret.result
  router                = google_compute_router.cloudbuild_router.id
  vpn_gateway_interface = 0
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "cloudbuild_tunnel2" {
  name                  = "${var.app_name}-cloudbuild-to-gke-tunnel2"
  region                = data.google_client_config.default.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gke_vpn_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.cloudbuild_vpn_gateway.id
  shared_secret         = random_password.vpn_shared_secret.result
  router                = google_compute_router.cloudbuild_router.id
  vpn_gateway_interface = 1
  ike_version           = 2
}

resource "google_compute_router_interface" "gke_to_cloudbuild_bgp_if_1" {
  name       = "${var.app_name}-gke-to-cloudbuild-bgp-if-1"
  router     = google_compute_router.gke_router.name
  region     = data.google_client_config.default.region
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.gke_tunnel1.name
}

resource "google_compute_router_peer" "gke_to_cloudbuild_bgp_peer_1" {
  name                      = "${var.app_name}-gke-to-cloudbuild-bgp-peer-1"
  router                    = google_compute_router.gke_router.name
  region                    = data.google_client_config.default.region
  peer_ip_address           = "169.254.0.2"
  peer_asn                  = google_compute_router.gke_router.bgp[0].asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gke_to_cloudbuild_bgp_if_1.name
}

resource "google_compute_router_interface" "gke_to_cloudbuild_bgp_if_2" {
  name       = "${var.app_name}-gke-to-cloudbuild-bgp-if-2"
  router     = google_compute_router.gke_router.name
  region     = data.google_client_config.default.region
  ip_range   = "169.254.1.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.gke_tunnel2.name
}

resource "google_compute_router_peer" "gke_to_cloudbuild_bgp_peer_2" {
  name                      = "${var.app_name}-gke-to-cloudbuild-bgp-peer-2"
  router                    = google_compute_router.gke_router.name
  region                    = data.google_client_config.default.region
  peer_ip_address           = "169.254.1.1"
  peer_asn                  = google_compute_router.gke_router.bgp[0].asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gke_to_cloudbuild_bgp_if_2.name
}

resource "google_compute_router_interface" "cloudbuild_to_gke_bgp_if_1" {
  name       = "${var.app_name}-cloudbuild-to-gke-bgp-if-1"
  router     = google_compute_router.cloudbuild_router.name
  region     = data.google_client_config.default.region
  ip_range   = "169.254.0.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.cloudbuild_tunnel1.name
}

resource "google_compute_router_peer" "cloudbuild_to_gke_bgp_peer_1" {
  name                      = "${var.app_name}-cloudbuild-to-gke-bgp-peer-1"
  router                    = google_compute_router.cloudbuild_router.name
  region                    = data.google_client_config.default.region
  peer_ip_address           = "169.254.0.1"
  peer_asn                  = google_compute_router.cloudbuild_router.bgp[0].asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.cloudbuild_to_gke_bgp_if_1.name
}

resource "google_compute_router_interface" "cloudbuild_to_gke_bgp_if_2" {
  name       = "${var.app_name}-cloudbuild-to-gke-bgp-if-2"
  router     = google_compute_router.cloudbuild_router.name
  region     = data.google_client_config.default.region
  ip_range   = "169.254.1.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.cloudbuild_tunnel2.name
}

resource "google_compute_router_peer" "cloudbuild_to_gke_bgp_peer_2" {
  name                      = "${var.app_name}-cloudbuild-to-gke-bgp-peer-2"
  router                    = google_compute_router.cloudbuild_router.name
  region                    = data.google_client_config.default.region
  peer_ip_address           = "169.254.1.2"
  peer_asn                  = google_compute_router.cloudbuild_router.bgp[0].asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.cloudbuild_to_gke_bgp_if_2.name
}
