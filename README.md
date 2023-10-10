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

- Better secrets management
  - Right now, the GCP credentials file is manually copied (`kubectl cp`) to the running cluster and does not persist!
  - The secrets.yaml file and the GCP credentials file are not stored in any official location.
- Production-ready `/media/` hosting.
  - Use GCP cloud storage with django-storages backend
  - This will allow us to run the production app with debug=False (and have the images still work)
- Collapsible top bar
- Homepage
  - Improve branding
  - Better explain what the site is
- French translation of Django app. (Sync with Shiny app language selection? Is this possible?)
