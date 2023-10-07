"""
Substitutes the values in the template cloudbuild.example file
for each shiny app in shiny_apps.json
"""

import os
import json


def main():
    current_dir = os.path.dirname(os.path.realpath(__file__))

    # shiny_apps.json is in ../djangoapp/
    parent_dir = os.path.dirname(current_dir)
    shiny_apps_json = os.path.join(parent_dir, 'djangoapp', 'shiny_apps.json')

    yaml_template = os.path.join(current_dir, 'cloudbuild.example')
    sh_template = os.path.join(current_dir, 'cloudbuild.sh.example')

    with open(shiny_apps_json) as f:
        shiny_apps_dict = json.load(f)

    shiny_apps = shiny_apps_dict['apps']
    
    # This is based on an individual GitHub user.
    # TODO: Make a new connection with org-managed GitHub "bot" account
    # and give the bot account admin access to all repos.
    cloudbuild_connection = shiny_apps_dict["cloudbuild_connection"]

    # Delete existing *.cloudbuild.yaml and *.cloudbuild.sh files
    existing_files = [f for f in os.listdir(current_dir) if f.endswith('.cloudbuild.yaml')]
    existing_files += [f for f in os.listdir(current_dir) if f.endswith('.cloudbuild.sh')]

    for f in existing_files:
        try:
            os.remove(os.path.join(current_dir, f))
            print("Deleted file: {}".format(f))
        except OSError:
            pass
    for app in shiny_apps:
        app_slug = str(app['slug'])
        git_repo = app.get('repo', None)
        if not git_repo:
            print("No repo specified for app: {}".format(app_slug))
            continue
        else:
            # Ensure git repo ends in ".git"; if not, append it
            if not git_repo.endswith('.git'):
                git_repo += '.git'
            # Get the git repo name from the URL
            repo_name = git_repo.split('/')[-1][:-4]
        git_branch = app.get('branch', 'main')

        with open(yaml_template) as f:
            template_lines = f.readlines()
            # The variable we care about is $APP_SLUG in the template file
            template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]

        # Write the new file
        new_file = os.path.join(current_dir, f"{app_slug}.cloudbuild.yaml")
        with open(new_file, 'w') as f:
            f.writelines(template_lines)

        print("Created file: {}".format(new_file))

        with open(sh_template) as f:
            template_lines = f.readlines()
            template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]
            template_lines = [line.replace('$GIT_REPO', git_repo) for line in template_lines]
            template_lines = [line.replace('$GIT_BRANCH', git_branch) for line in template_lines]
            template_lines = [line.replace('$CLOUDBUILD_CONNECTION', cloudbuild_connection) for line in template_lines]
            template_lines = [line.replace('$REPO_NAME', repo_name) for line in template_lines]

        # Write the new file
        new_file = os.path.join(current_dir, f"{app_slug}.cloudbuild.sh")
        with open(new_file, 'w') as f:
            f.writelines(template_lines)

        print("Created file: {}".format(new_file))


    print("Done creating cloudbuild.yaml and cloudbuild.sh files for shiny apps.")


if __name__ == '__main__':
    main()
