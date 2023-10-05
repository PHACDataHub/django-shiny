"""
Substitutes the values in the template shinyapp.example file
for each shiny app in shiny_apps.json
"""

import os
import json

def main():
    current_dir = os.path.dirname(os.path.realpath(__file__))

    # shiny_apps.json is in ../djangoapp/
    parent_dir = os.path.dirname(current_dir)
    shiny_apps_json = os.path.join(parent_dir, 'djangoapp', 'shiny_apps.json')

    template = os.path.join(current_dir, 'shinyapp.example')

    with open(shiny_apps_json) as f:
        shiny_apps = json.load(f)['apps']

    # Delete existing *.shinyapp.yaml files
    existing_files = [f for f in os.listdir(current_dir) if f.endswith('.shinyapp.yaml')]
    for f in existing_files:
        try:
            os.remove(os.path.join(current_dir, f))
            print("Deleted file: {}".format(f))
        except OSError:
            pass
    for app in shiny_apps:
        app_slug = str(app['slug'])
        app_image = str(app['image'])
        app_port = str(app['port'])

        with open(template) as f:
            template_lines = f.readlines()
            # The variables are $APP_SLUG, $APP_IMAGE and $APP_PORT
            # in the template file
            template_lines = [line.replace('$APP_SLUG', app_slug) for line in template_lines]
            template_lines = [line.replace('$APP_IMAGE', app_image) for line in template_lines]
            template_lines = [line.replace('$APP_PORT', app_port) for line in template_lines]


        # Write the new file
        new_file = os.path.join(current_dir, f"{app_slug}.shinyapp.yaml")
        with open(new_file, 'w') as f:
            f.writelines(template_lines)

        print("Created file: {}".format(new_file))

    print("Done creating YAML files for shiny apps.")


if __name__ == '__main__':
    main()
