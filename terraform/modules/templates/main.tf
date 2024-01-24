# Based on this: https://cj-hewett.medium.com/using-templates-in-terraform-to-generate-kubernetes-yaml-5f60cfa0109
variable "region" {}
variable "project_id" {}
variable "hostname" {}
variable "trigger_name" {}
variable "branch_name" {}
variable "cluster_name" {}

resource "local_file" "app_templates" {
  for_each = toset([
    for template in fileset(path.module, "app/**") : template
  ])

  content = templatefile("${path.module}/${each.key}", {
    region       = var.region
    project_id   = var.project_id
    trigger_name = var.trigger_name
    branch_name  = var.branch_name
    cluster_name = var.cluster_name
  })

  filename = replace("../${path.root}/${each.key}", "app/", "")

  lifecycle {
    prevent_destroy = true
  }
}

resource "local_file" "k8s_templates" {
  for_each = toset([
    for template in fileset(path.module, "k8s/**") : template
  ])

  content = templatefile("${path.module}/${each.key}", {
    region     = var.region
    project_id = var.project_id
    hostname   = var.hostname
  })

  filename = "../${path.root}/${each.key}"

  lifecycle {
    prevent_destroy = true
  }
}
