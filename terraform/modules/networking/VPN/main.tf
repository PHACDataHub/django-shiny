# based on this guide: https://cloud.google.com/build/docs/private-pools/accessing-private-gke-clusters-with-cloud-build-private-pools
# plus this article: https://cloud.google.com/network-connectivity/docs/vpn/how-to/automate-vpn-setup-with-terraform
variable "app_name" {}
variable "region" {}
variable "zone" {}
variable "project_id" {}
variable "gke_vpc_id" {}
variable "cloudbuild_vpc_id" {}

resource "google_compute_ha_vpn_gateway" "gke_vpn_gateway" {
  region  = var.region
  name    = "${app_name}-gke-vpn-gateway"
  network = var.gke_vpc_id
}

resource "google_compute_ha_vpn_gateway" "cloudbuild_vpn_gateway" {
  region  = var.region
  name    = "${app_name}-cloudbuild-vpn-gateway"
  network = var.cloudbuild_vpc_id
}

resource "google_compute_router" "gke_router" {
  name    = "${app_name}-gke-router"
  region  = var.region
  network = var.gke_vpc_id
  bgp {
    asn = 65001
  }
}

resource "google_compute_router" "cloudbuild_router" {
  name    = "${app_name}-cloudbuild-router"
  region  = var.region
  network = var.cloudbuild_vpc_id
  bgp {
    asn = 65002
  }
}

# Create two VPN tunnels for each gateway direction (for HA)
resource "google_compute_vpn_tunnel" "gke_tunnel1" {
  name                  = "${app_name}-gke-to-cloudbuild-tunnel1"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.cloudbuild_vpn_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gke_vpn_gateway.id
  shared_secret         = "a secret message"
  router                = google_compute_router.router1.id
  vpn_gateway_interface = 0
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "gke_tunnel2" {
  name                  = "${app_name}-gke-to-cloudbuild-tunnel2"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.cloudbuild_vpn_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.gke_vpn_gateway.id
  shared_secret         = "a secret message"
  router                = google_compute_router.router1.id
  vpn_gateway_interface = 1
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "cloudbuild_tunnel1" {
  name                  = "${app_name}-cloudbuild-to-gke-tunnel1"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gke_vpn_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.cloudbuild_vpn_gateway.id
  shared_secret         = "a secret message"
  router                = google_compute_router.router2.id
  vpn_gateway_interface = 0
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "cloudbuild_tunnel2" {
  name                  = "${app_name}-cloudbuild-to-gke-tunnel2"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.gke_vpn_gateway.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.cloudbuild_vpn_gateway.id
  shared_secret         = "a secret message"
  router                = google_compute_router.router2.id
  vpn_gateway_interface = 1
  ike_version           = 2
}

resource "google_compute_router_interface" "gke_to_cloudbuild_bgp_if_1" {
  name       = "${app_name}-gke-to-cloudbuild-bgp-if-1"
  router     = google_compute_router.gke_router.name
  region     = var.region
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.gke_tunnel1.name
}

resource "google_compute_router_peer" "gke_to_cloudbuild_bgp_peer_1" {
  name                      = "${app_name}-gke-to-cloudbuild-bgp-peer-1"
  router                    = google_compute_router.gke_router.name
  region                    = var.region
  peer_ip_address           = "169.254.0.2"
  peer_asn                  = google_compute_router.gke_router.bgp.asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gke_to_cloudbuild_bgp_if_1.name
}

resource "google_compute_router_interface" "gke_to_cloudbuild_bgp_if_2" {
  name       = "${app_name}-gke-to-cloudbuild-bgp-if-2"
  router     = google_compute_router.gke_router.name
  region     = var.region
  ip_range   = "169.254.1.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.gke_tunnel2.name
}

resource "google_compute_router_peer" "gke_to_cloudbuild_bgp_peer_2" {
  name                      = "${app_name}-gke-to-cloudbuild-bgp-peer-2"
  router                    = google_copute_router.gke_router.name
  region                    = var.region
  peer_ip_address           = "169.254.1.1"
  peer_asn                  = google_compute_router.gke_router.bgp.asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.gke_to_cloudbuild_bgp_if_2.name
}

resource "google_compute_router_interface" "cloudbuild_to_gke_bgp_if_1" {
  name       = "${app_name}-cloudbuild-to-gke-bgp-if-1"
  router     = google_compute_router.cloudbuild_router.name
  region     = var.region
  ip_range   = "169.254.0.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.cloudbuild_tunnel1.name
}

resource "google_compute_router_peer" "cloudbuild_to_gke_bgp_peer_1" {
  name                      = "${app_name}-cloudbuild-to-gke-bgp-peer-1"
  router                    = google_compute_router.cloudbuild_router.name
  region                    = var.region
  peer_ip_address           = "169.254.0.1"
  peer_asn                  = google_compute_router.cloudbuild_router.bgp.asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.cloudbuild_to_gke_bgp_if_1.name
}

resource "google_compute_router_interface" "cloudbuild_to_gke_bgp_if_2" {
  name       = "${app_name}-cloudbuild-to-gke-bgp-if-2"
  router     = google_compute_router.cloudbuild_router.name
  region     = var.region
  ip_range   = "169.254.1.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.cloudbuild_tunnel2.name
}

resource "google_compute_router_peer" "cloudbuild_to_gke_bgp_peer_2" {
  name                      = "${app_name}-cloudbuild-to-gke-bgp-peer-2"
  router                    = google_compute_router.cloudbuild_router.name
  region                    = var.region
  peer_ip_address           = "169.254.1.2"
  peer_asn                  = google_compute_router.cloudbuild_router.bgp.asn
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.cloudbuild_to_gke_bgp_if_2.name
}
