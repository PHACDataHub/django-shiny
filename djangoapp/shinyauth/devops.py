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

    cloudbuild_connection = settings.CLOUDBUILD_CONNECTION

    # Set variables for the app
    app_slug = app.slug
    git_repo = app.repo
    git_branch = app.branch
    app_port = str(app.port)
    mem_min = str(app.mem_min)
    mem_max = str(app.mem_max)
    cpu_min = str(app.cpu_min)
    cpu_max = str(app.cpu_max)

    # Ensure git repo ends in ".git"; if not, append it
    if not git_repo.endswith('.git'):
        git_repo += '.git'
    # Get the git repo name from the URL
    repo_name = git_repo.split('/')[-1][:-4]

    # Generate Cloud Build YAML
    with open(yaml_template) as f:
        template_lines = f.readlines()
        template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]
    new_file = os.path.join(cloudbuild_dir, f"{app_slug}.cloudbuild.yaml")
    with open(new_file, 'w') as f:
        f.writelines(template_lines)
    print("Created file: {}".format(new_file))

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

    # Generate Kubernetes deployment YAML
    app_image = f'northamerica-northeast1-docker.pkg.dev/phx-datadissemination/shiny-apps/{app_slug}'
    with open(k8s_template) as f:
        template_lines = f.readlines()
        template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]
        template_lines = [line.replace('$APP_IMAGE', app_image) for line in template_lines]
        template_lines = [line.replace('$APP_PORT', app_port) for line in template_lines]
        template_lines = [line.replace('$MEM_MIN', mem_min) for line in template_lines]
        template_lines = [line.replace('$MEM_MAX', mem_max) for line in template_lines]
        template_lines = [line.replace('$CPU_MIN', cpu_min) for line in template_lines]
        template_lines = [line.replace('$CPU_MAX', cpu_max) for line in template_lines]
    new_file = os.path.join(k8s_dir, f"{app_slug}.shinyapp.yaml")
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
