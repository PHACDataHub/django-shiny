# Django-Shiny: Kubernetes hosting and authentication layer for Shiny apps

This is based on [Django Auth Server for Shiny](https://pawamoy.github.io/posts/django-auth-server-for-shiny/), but modified to use Kubernetes and [Magic Link authentication](https://github.com/pyepye/django-magiclink) (among other changes and improvements).

## Adding apps

In your Shiny app repo:
1. Containerize your app similarly to the example Shiny app in `/shinyapp_example/`.
2. Modify `cloudbuild.yaml` with your app slug (alphanumeric and hyphens only).
3. In GCP, set up a Cloud Build trigger for your repo.

In this repo:
1. Add the app to `/djangoapp/shiny_apps.json`. The app slug should be the same as you used in your `cloudbuild.yaml`. Copy the image URL as well, but manually substitute `${_APP_SLUG}` with your app slug.

When a new commit is pushed to main in this repo, Cloud Build will:
1. Rebuild the image for this repo and push to the Artifact Registry.
2. `python ./k8s/generate_shiny_yaml.py` (generate the k8s configurations for the shiny apps in `shiny_apps.json`)
3. `kubectl apply -f k8s` (apply all the k8s configurations)
4. `kubectl rollout restart deployment/djangoapp-deployment` (restart the django app)

## To do

This process could be streamlined by having this repo's CI generate the `cloudbuild.yaml` and set up triggers for each Shiny app automatically. This would lessen the burden on Shiny app creators (they would not need access to GCP).

The GitHub repo URL would be needed in the `shiny_apps.json`, instead of the image URL.
