# Django-Shiny: Kubernetes hosting and authentication layer for Shiny apps

This is based on [Django Auth Server for Shiny](https://pawamoy.github.io/posts/django-auth-server-for-shiny/), but modified to use Kubernetes and [Magic Link authentication](https://github.com/pyepye/django-magiclink) (among other changes and improvements, notably cloud build automation).

## Open the web-app (hosted on GCP)

[https://shiny.phac.alpha.canada.ca/](https://shiny.phac.alpha.canada.ca/)

## Video Demo

[`<img src="https://github-production-user-asset-6210df.s3.amazonaws.com/367922/276718725-1b6f1333-5e35-4999-9b34-1f33b7531761.png">`](https://www.youtube.com/watch?v=O-p3oKCu4rg)

## Adding Shiny apps

In your Shiny app repo:

1. Containerize your app similarly to the example Shiny app in [`/shinyapp_example/`](https://github.com/PHACDataHub/django-shiny/tree/main/shinyapp_example/wastewater).
2. Take note of what port you are exposing. 8100 is expected, but can be changed in the django-shiny GUI.

For flexdashboard apps using R markdown, the Dockerfile is similar except you will need to install the `flexdashboard` R package and change the command, e.g.:

```
CMD ["R", "-e", "rmarkdown::run('shinyapp/app.Rmd', shiny_args = list(port = 8100, host = '0.0.0.0'))"]
```

In the django-shiny application:

1. You must be made an "app admin" to add apps.
   1. You must login once before being added as an app admin (for a user account to be created).
   2. If you have kubectl access, you can add yourself from the django shell.
   3. If not, Asma, Emma, Liza and Alex all have "app admin" role and can add you.
2. In the header toolbar, click "Manage Apps" then click "Add App".

## Adding Plotly Dash apps

The process is the same as for Shiny apps, with one exception. You have to define the `DASH_REQUESTS_PATHNAME_PREFIX` environment variable to reflect how NGINX has been configured.

Add this to your Dockerfile:

```
ENV DASH_REQUESTS_PATHNAME_PREFIX /shiny/<your-app-slug>/
```

See [`/dashapp_example/`](https://github.com/PHACDataHub/django-shiny/tree/main/dashapp_example/dash-example).

## Cloud build automation (CI/CD)

When a new commit is pushed to main in this repo, Cloud Build will:

1. Rebuild the image for this repo and push to the Artifact Registry.
2. Generate and apply the k8s configuration for the Django app.
   * **IMPORTANT!** You must make an edit to `k8s/djangoapp.yaml` for the container to restart. An environment variable `CHANGE_VALUE_TO_TRIGGER_RESTART` is in the YAML for this purpose.
   * This is because `kubectl rollout restart` does not use the initContainers, which means that restarting will fail to get service account credentials and you'll see a 500 error until manually deleting & applying the YAML.

See [cloudbuild.yaml](https://github.com/PHACDataHub/django-shiny/blob/main/cloudbuild.yaml).

## Setup - GCP

1. Create a new project on Google Cloud Platform

   1. From the dashboard, under project info, use the values to update the `project_name`, `project_number`, and `project_id` variables in [terraform.tfvars](terraform/terraform.tfvars)
   2. Also update the value of the `PROJECT_ID` variable in [gcp-setup.sh](terraform/gcp-setup.sh)
   3. In [providers.tf](terraform/providers.tf), inside `backend "gcs"`, suffix `bucket` and `credentials` with the `PROJECT_ID`. For example:

   ```
   backend "gcs" {
      bucket      = "tfstate-bucket-PROJECT_ID"
      prefix      = "terraform/state"
      credentials = "./terraform-service-account-key-PROJECT_ID.json"
   }
   ```
2. Create a file named [secrets.auto.tfvars](terraform/secrets.auto.tfvars) in the `terraform/` directory with the folllowing variables appropriately defined: (See [Setup - Manual Steps](./README.md#setup---manual-steps))

   ```
   // Values in plaintext
   email_host_user = ...
   email_host_password = ...
   github_oauth_token = ...
   ```
3. Install the [gcloud CLI](https://cloud.google.com/sdk/docs/install)
4. Open a terminal with the parent directory `/django-shiny` as the current working directory
5. Login with the CLI

   ```
    gcloud auth login  
   ```
6. Set the project property

   ```
   gcloud config set project PROJECT_ID
   ```
7. Change into the `terraform/` directory

   ```
   cd terraform/
   ```
8. Run `gcp-setup.sh`

   ```
   bash gcp-setup.sh
   ```
9. Now, we can run the following Terrafrom commands: (Note, the apply can take up to 30 minutes to finish provision all cloud resources)

   ```
   terraform init -reconfigure
   terraform apply
   ```
10. Now run trigger a cloudbuild by pushing to the respective envrionment branch (i.e. `dev` or `prod`)
11. Now, follow the steps and add the DNS zone's name servers to the [PHAC dns repo](https://github.com/PHACDataHub/dns). This can be tricky to understand at first, if so, ask John Bain for help. Remember that DNS changes usually take a few minutes to propagrate.

    1. If this is a `dev` environment, assuming the `prod` environment is already setup as described in step 10, you will instead add the name servers of `dev`'s DNS zone into `prod`'s DNS zone.
    2. From the web console in GCP, go to `prod`'s DNS zone and create a NS record with the NS data from `dev`'s DNS zone.
12. Now you can visit the website at the `url` as set in `terraform.tfvars`

## Setup - Creating an Admin Account

User account roles and permissions can be assigned using the website. However, the first admin account will need to granted manually as follows:

1. Use the gcloud CLI to authenticate in the cluster

   ```
   gcloud container clusters get-credentials django-shiny-platform-app-cluster --region northamerica-northeast1 --project PROJECT_ID
   ```
2. Navigate to the `url` as set in `terraform.tfvars` and login
3. Afterward, use `kubectl get pods` to find the ephemeral name of the pod running the djangoapp and use it to run the following command to access the command line inside the pod:

   ```
   kubectl exec -it <DJANGOAPP_DEPLOYMENT_NAME>  -- /bin/bash
   ```
4. Change into the `djangoapp/` directory and enter the Django shell_plus

   ```
   cd djangoapp/
   python ./manage.py shell_plus
   ```
5. We will now query the user model and grant it Admin status in the app. There are a few ways to do this. The easiest is probably the following command:

   ```
   User.objects.filter(email="<YOUR_EMAIL>").update(is_superuser=True)
   ```
6. Confirm by checking the website, the change should be immediate
7. Exit the shell and command line. (i.e. ctrl+d)

## Setup - Manual Steps

* Every Shiny app repo needs to grant owner permissions to the provider auth account of this connection, or else setting up cloud build for the shiny apps won't work!
  * This is currently set up with name "datahub-automation". You can just continue using this. It uses the GitHub account "datahub-automation", which is a hidden owner for the PHACDataHub github organization, intended for this kind of "machine use".

## To do

Technical debt

- Better secrets management

  - The secrets.yaml file could be stored in Secret Manager. See https://cloud.google.com/kubernetes-engine/docs/tutorials/workload-identity-secrets (not sure this is the right approach).

App features

- French translation of Django app. (Sync with Shiny app language selection? Is this possible?)
- Improve management UX (e.g. add an email match/group without leaving the Manage App page - HTMX modal; bootstrap checkboxes)

Unsolved process issues

- Connect data to Shiny apps

  - Google cloud storage
  - Azure blob storage
  - Databricks SQL?
