# Django-Shiny: Kubernetes hosting and authentication layer for Shiny apps

This is based on [Django Auth Server for Shiny](https://pawamoy.github.io/posts/django-auth-server-for-shiny/), but modified to use Kubernetes and [Magic Link authentication](https://github.com/pyepye/django-magiclink) (among other changes and improvements).

## Adding apps

1. Create a repo for your shiny app. Containerize it similarly to the example Shiny app in `/shinyapp_example/`.
2. Build and push the image to the Artifact Registry - or set up Cloud Build for your shiny app's repo. Note the image URL.
3. In this repo, create a new branch.
4. Add the app to `/djangoapp/shiny_apps.json`.
5. Commit, push, and open a PR in this repo.

The following steps will be handled by the CD pipeline for this repo after the PR is merged (**TODO**):

6. Rebuild the image for this repo and push to the Artifact Registry.
7. `cd k8s`
8. `python generate_shiny_yaml.py`
9. Update the `djangoapp.yaml` image URL.
10. `kubectl apply -f .`
