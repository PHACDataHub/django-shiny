# Django-Shiny: Kubernetes hosting and authentication layer for Shiny apps

This is based on [Django Auth Server for Shiny](https://pawamoy.github.io/posts/django-auth-server-for-shiny/), but modified to use Kubernetes and [Magic Link authentication](https://github.com/pyepye/django-magiclink) (among other changes and improvements, notably cloud build automation).

## Open the web-app (hosted on GCP)

[https://shiny.phac.alpha.canada.ca/](https://shiny.phac.alpha.canada.ca/)

## Adding apps

In your Shiny app repo:
1. Containerize your app similarly to the example Shiny app in `/shinyapp_example/`.
2. Make sure you **expose port 8100**.

In the django-shiny application:
1. You must be made an "app admin" to add apps.
   1. You must login once before being added as an app admin (for a user account to be created).
   2. If you have kubectl access, you can add yourself from the django shell.
   3. If not, Asma, Emma, Liza and Alex all have "app admin" role and can add you.
2. Go to Manage Apps and Add App.
  
## Cloud build automation (CI/CD)

When a new commit is pushed to main in this repo, Cloud Build will:
1. Rebuild the image for this repo and push to the Artifact Registry.
2. Generate and apply the k8s configuration for the Django app.
3. Restart the k8s pod for the Django app.

## To do

Technical debt
- Switch email service to a more reliable one (ask John Bain)
- Better secrets management
  - The secrets.yaml file could be stored in Secret Manager. See https://cloud.google.com/kubernetes-engine/docs/tutorials/workload-identity-secrets (not sure this is the right approach).
- Create bot account for PHACDataHub organization and use that for the Cloud Build connection (update secrets to reflect this when done)
- Improve documentation of how to setup the GCP environment: e.g. detailed kubectl and gcloud commands

App features
- Collapsible top bar
- Homepage
  - Improve branding
  - Better explain what the site is
- French translation of Django app. (Sync with Shiny app language selection? Is this possible?)

## Setting up in GCP

You will need the following resources:
* Cloud Storage
* Artifact Registry
* IAM
* Secret Manager
* Cloud Build
* Google Kubernetes Engine (GKE)

1. Create a bucket in cloud storage for the Django media directory.
2. Create 2 repositories in Artifact Registry: `django-shiny` (for this app) and `shiny-apps` (for the subsidiary Shiny apps).
3. Set up an IAM service account for the kubernetes deployment to use. It must have these roles:
   * Cloud Build connection admin
   * Cloud Build editor
   * Storage object user
   * Secret Manager secret accessor
   Save the account key json file.
4. Create a secret `gcp_service_account_key` with the value of the account key json:
   ```
   gcloud secrets create gcp_service_account_key --data-file=gcp_service_account_key.json --locations=northamerica-northeast1 --replication-policy=user-managed
   ```
5. In Cloud Build, set up a 2nd gen connection to GitHub. Every Shiny app repo needs to grant owner permissions to the provider auth account of this connection, or else setting up cloud build for the shiny apps won't work!
6. In GKE, create a new cluster with the default settings. You will need to access the cluster somehow, so install gcloud CLI and kubectl on your local machine or use cloud shell for that.

For the most part, setting up the GKE cluster is straightforward, using GKE Autopilot. There are a few extra / unusual steps:

* Create a k8s service account, and associate this with the IAM service account. See https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
* Install ingress-nginx on the cluster
* Set up cert-manager on the cluster: `helm install cert-manager jetstack/cert-manager   --namespace cert-manager   --create-namespace   --version v1.13.1   --set installCRDs=true --set global.leaderElection.namespace=cert-manager`

