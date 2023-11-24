resource "kubectl_manifest" "cert_manager_cluster_issuer" {
  yaml_body = file("../${path.root}/k8s/issuer-lets-encrypt-production.yaml")
}

module "cert-manager" {
  source = "terraform-iaac/cert-manager/kubernetes"

  cluster_issuer_email                   = "admin@mysite.com"
  cluster_issuer_name                    = "cert-manager-global"
  cluster_issuer_private_key_secret_name = "cert-manager-private-key"
}



resource "helm_release" "nginx_ingress" {
  name = "nginx-ingress-controller"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}
