# Django-Shiny: Kubernetes hosting and authentication layer for Shiny apps

This is based on [Django Auth Server for Shiny](https://pawamoy.github.io/posts/django-auth-server-for-shiny/), but modified to use Kubernetes and [Magic Link authentication](https://github.com/pyepye/django-magiclink) (among other changes and improvements).

## Adding apps

In your Shiny app repo:
1. Containerize your app similarly to the example Shiny app in `/shinyapp_example/`.
2. Modify cloudbuild.yaml for your app name.
3. Set up a cloud build trigger for your repo.

In this repo:
1. Add the app to `/djangoapp/shiny_apps.json` with the appropriate image URL.


The following steps are handled by the CD pipeline (cloudbuild):
1. Rebuild the image for this repo and push to the Artifact Registry.
2. `python ./k8s/generate_shiny_yaml.py`
3. `kubectl apply -f k8s`
