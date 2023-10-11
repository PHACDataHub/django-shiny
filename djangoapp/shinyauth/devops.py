from django.conf import settings
import os


def generate_deployment(app):
    """
    Generate k8s YAML, cloudbuild YAML and scripts for a Shiny app
    """
    parent_dir = os.path.dirname(settings.BASE_DIR)
    cloudbuild_dir = os.path.join(parent_dir, 'cloudbuild')
    k8s_dir = os.path.join(parent_dir, 'k8s')
    yaml_template = os.path.join(cloudbuild_dir, 'cloudbuild.example')
    sh_template = os.path.join(cloudbuild_dir, 'cloudbuild.sh.example')
    sh_delete_template = os.path.join(cloudbuild_dir, 'delete_cloudbuild.sh.example')
    k8s_template = os.path.join(k8s_dir, 'shinyapp.example')

    # This is based on an individual GitHub user.
    # TODO: Make a new connection with org-managed GitHub "bot" account
    # and give the bot account admin access to all repos.
    cloudbuild_connection = settings.CLOUDBUILD_CONNECTION


    # Set variables for the app
    app_slug = app.slug
    git_repo = app.repo
    git_branch = app.branch
    # Ensure git repo ends in ".git"; if not, append it
    if not git_repo.endswith('.git'):
        git_repo += '.git'
    # Get the git repo name from the URL
    repo_name = git_repo.split('/')[-1][:-4]

    # Delete existing *.cloudbuild.yaml and *.cloudbuild.sh files
    existing_files = [f for f in os.listdir(cloudbuild_dir) if f.endswith('.cloudbuild.yaml')]
    existing_files += [f for f in os.listdir(cloudbuild_dir) if f.endswith('.cloudbuild.sh')]
    existing_files += [f for f in os.listdir(cloudbuild_dir) if f.endswith('.delete_cloudbuild.sh')]
    existing_files += [f for f in os.listdir(k8s_dir) if f.endswith('.shinyapp.yaml')]
    for f in existing_files:
        try:
            os.remove(os.path.join(cloudbuild_dir, f))
            print("Deleted file: {}".format(f))
        except OSError:
            pass

    # Generate bash script to create / update and run cloudbuild trigger
    with open(sh_template) as f:
        template_lines = f.readlines()
        template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]
        template_lines = [line.replace('$GIT_REPO', git_repo) for line in template_lines]
        template_lines = [line.replace('$GIT_BRANCH', git_branch) for line in template_lines]
        template_lines = [line.replace('$CLOUDBUILD_CONNECTION', cloudbuild_connection) for line in template_lines]
        template_lines = [line.replace('$REPO_NAME', repo_name) for line in template_lines]
    new_file = os.path.join(cloudbuild_dir, f"{app_slug}.cloudbuild.sh")
    with open(new_file, 'w') as f:
        f.writelines(template_lines)
    print("Created file: {}".format(new_file))

    # Generate bash script to delete cloudbuild trigger
    with open(sh_delete_template) as f:
        template_lines = f.readlines()
        template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]
    new_file = os.path.join(cloudbuild_dir, f"{app_slug}.delete_cloudbuild.sh")
    with open(new_file, 'w') as f:
        f.writelines(template_lines)
    print("Created file: {}".format(new_file))

    # Generate Kubernetes deployment YAML but don't write it to file
    app_port = "8100"
    app_image = f'northamerica-northeast1-docker.pkg.dev/phx-datadissemination/shiny-apps/{app_slug}'
    with open(k8s_template) as f:
        template_lines = f.readlines()
        template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]
        template_lines = [line.replace('$APP_IMAGE', app_image) for line in template_lines]
        template_lines = [line.replace('$APP_PORT', app_port) for line in template_lines]
    k8s_lines = template_lines
    print("Created k8s deployment YAML")

    # Generate Cloud Build YAML
    with open(yaml_template) as f:
        template_lines = f.readlines()
        template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]

    print(template_lines)
    k8s_yaml_idx = template_lines.index('$K8S_YAML\n')
    # Indent the k8s YAML by 6 spaces
    k8s_lines = [' '*6 + line for line in k8s_lines]
    template_lines = template_lines[:k8s_yaml_idx] + k8s_lines + template_lines[k8s_yaml_idx+1:]

    new_file = os.path.join(cloudbuild_dir, f"{app_slug}.cloudbuild.yaml")
    with open(new_file, 'w') as f:
        f.writelines(template_lines)
    print("Created file: {}".format(new_file))

    print(f"Done creating cloudbuild YAML, gcloud scripts and k8s YAML files for {app}.")


def deploy_app(app):
    """
    Deploy a Shiny app to GKE using Cloud Build
    """
    generate_deployment(app)
    cloudbuild_dir = os.path.join(os.path.dirname(settings.BASE_DIR), 'cloudbuild')
    sh_file = os.path.join(cloudbuild_dir, f"{app.slug}.cloudbuild.sh")
    os.system(f"bash {sh_file}")
    print(f"Done setting up and running cloud build triggers for {app}.")


def delete_app(app):
    """
    Deploy a Shiny app to GKE using Cloud Build
    """
    generate_deployment(app)
    cloudbuild_dir = os.path.join(os.path.dirname(settings.BASE_DIR), 'cloudbuild')
    sh_file = os.path.join(cloudbuild_dir, f"{app.slug}.delete_cloudbuild.sh")
    os.system(f"bash {sh_file}")
    print(f"Done deleting cloud build triggers for {app}.")
