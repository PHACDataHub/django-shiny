# Based on this: https://cj-hewett.medium.com/using-templates-in-terraform-to-generate-kubernetes-yaml-5f60cfa0109
variable "region" {}
variable "project_id" {}
variable "hostname" {}

resource "local_file" "app_templates" {
  for_each = toset([
    for template in fileset(path.module, "templates/app/**") : template
  ])

  content = templatefile("${path.module}/${each.key}", {
    region     = var.region
    project_id = var.project_id
  })

  filename = replace("../${path.root}/${each.key}", "templates/app/", "")

  lifecycle {
    prevent_destroy = true
  }
}

resource "local_file" "k8s_templates" {
  for_each = toset([
    for template in fileset(path.module, "templates/k8s/**") : template
  ])

  content = templatefile("${path.module}/${each.key}", {
    region     = var.region
    project_id = var.project_id
    hostname   = var.hostname
  })

  filename = replace("../${path.root}/${each.key}", "templates/k8s/", "k8s/")

  lifecycle {
    prevent_destroy = true
  }
}
