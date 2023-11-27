resource "kubectl_manifest" "cert_manager_cluster_issuer" {
  yaml_body = file("../${path.root}/k8s/issuer-lets-encrypt-production.yaml")
}

# Static IP

resource "kubectl_manifest" "nginx_ingress_controller" {
  yaml_body = file("../${path.root}/k8s/djangoapp-ingress.yaml")
  
}
resource "google_compute_address" "ingress_ip_address" {
  name = "nginx-controller"
}
