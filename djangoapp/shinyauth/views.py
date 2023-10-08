from django.contrib.auth import logout
from django.http import HttpResponse, JsonResponse
from django.shortcuts import render, redirect
from django.contrib import messages

from shinyauth.models import ShinyApp
from shinyauth.forms import ShinyAppForm

import requests
from bs4 import BeautifulSoup


def home(request):
    context = {"active_tab": "index", "apps": [
        app for app in ShinyApp.objects.all()
        if app.check_visibility(request.user)
    ]}
    return render(request, "djangoapp/home.jinja", context)


def logout_view(request):
    logout(request)
    messages.success(request, "You have successfully logged out.")
    return redirect("index")


def login_success(request):
    messages.success(request, "You have successfully logged in.")
    return redirect("index")


def shiny(request, app_slug):
    app = ShinyApp.objects.get(slug=app_slug)
    if not app.check_access(request.user):
        return redirect(f"/login/?next=/shiny/{app_slug}/")
    return render(
        request, "djangoapp/shiny.jinja",
        {"active_tab": app_slug, "app_slug": app_slug}
    )


def shiny_contents(request, app_slug):
    app = ShinyApp.objects.get(slug=app_slug)
    if not app.check_access(request.user):
        return redirect(f"/login/?next=/shiny/{app_slug}/")
    response = requests.get(f"http://{app_slug}-service:8100")
    soup = BeautifulSoup(response.content, "html.parser")
    return JsonResponse({"html_contents": str(soup)})


def auth(request, app_slug):
    app = ShinyApp.objects.get(slug=app_slug)
    if not app.check_access(request.user):
        return HttpResponse(status=403)
    return HttpResponse(status=200)


def manage_apps(request):
    if not request.user.is_superuser:
        return redirect("index")
    context = {"active_tab": "manage_apps", "apps": ShinyApp.objects.all()}
    return render(request, "djangoapp/manage_apps.jinja", context)


def manage_app(request, app_slug):
    if not request.user.is_superuser:
        return redirect("index")
    app = ShinyApp.objects.get(slug=app_slug)

    if request.method == "POST":
        form = ShinyAppForm(request.POST, request.FILES, instance=app)
        if form.is_valid():
            form.save()
            messages.success(request, "App successfully updated.")
        else:
            messages.error(request, "App could not be updated.")

    form = ShinyAppForm(instance=app)
    context = {"active_tab": "manage_apps", "app": app, "form": form}
    return render(request, "djangoapp/manage_app.jinja", context)


def manage_users(request):
    if not request.user.is_superuser:
        return redirect("index")
    context = {"active_tab": "manage_users"}
    return render(request, "djangoapp/manage_users.jinja", context)
