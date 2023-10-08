# Django-Shiny: Kubernetes hosting and authentication layer for Shiny apps

This is based on [Django Auth Server for Shiny](https://pawamoy.github.io/posts/django-auth-server-for-shiny/), but modified to use Kubernetes and [Magic Link authentication](https://github.com/pyepye/django-magiclink) (among other changes and improvements, notably cloud build automation).

## Adding apps

In your Shiny app repo:
1. Containerize your app similarly to the example Shiny app in `/shinyapp_example/`.

In this repo:
1. Add the app to `/djangoapp/shiny_apps.json`.
   - The "slug" can only contain alphanumeric characters and hyphens.
   - Branch (default: "main") and port (default: 8100) are optional.
   - Specifying a repo is preferred, but you can also specify an existing built container image URL.
  
## Cloud build automation (CI/CD)

When a new commit is pushed to main in this repo, Cloud Build will:
1. Rebuild the image for this repo and push to the Artifact Registry.
2. For each shiny app in `shiny_apps.json`:
   1. Generate and apply the kubernetes configuration.
   2. Generate the cloudbuild configuration.
   3. Set up a cloud build trigger for push to the branch (default: "main").
   4. Run the cloud build trigger manually.
   5. When cloud build is complete, restart the k8s pod for this shiny app.
5. Generate and apply the k8s configuration for the Django app.
6. Restart the k8s pod for the Django app.

## To do

- Finer grained permission management per-app, e.g. user groups, associating apps with user groups.
- App admin role to manage permissions.
- Collapsible top bar
- App admin GUI
  - edit user groups & associate apps with user groups
  - edit app display name, description, thumbnail image (?), contact email
  - edit app visibility (should it only be visible when user has access to it)
- Homepage
  - Improve branding
  - Better explain what the site is
  - App directory (list of apps with descriptions, thumbnail images?)
- Prevent unneccessary builds/restarts for Shiny Apps via this repo's cloud build pipeline.
  - Skip all k8s/cloud build steps for an app if it is unchanged from the previous commit of `shiny_apps.yaml`
- App usage analytics?
- French translation of Django app. (Sync with Shiny app language selection? Is this possible?)
