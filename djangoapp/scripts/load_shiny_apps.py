import json
from shinyauth.models import ShinyApp

def run():
    with open('shiny_apps.json') as f:
        data = json.load(f)['apps']

    for app in data:
        ShinyApp.objects.update_or_create(
            slug=app['slug'],
            defaults={
                "repo": app['repo'],
                "branch": app.get('branch', 'main')
            }
        )
