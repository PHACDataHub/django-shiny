from django.contrib.auth.decorators import login_required
from django.contrib.auth import logout
from django.http import HttpResponse, JsonResponse
from django.shortcuts import render, redirect
from django.contrib import messages

from djangoapp.settings import env, SHINY_APPS

import requests

from bs4 import BeautifulSoup

shiny_apps = {app["slug"]: app for app in SHINY_APPS}

def user_has_access(user, app_slug):
    return shiny_apps[app_slug]["access"] == "public" or user.is_authenticated


def home(request):
    return render(request, "djangoapp/home.jinja", {"active_tab": "index"})


def logout_view(request):
    logout(request)
    messages.success(request, "You have successfully logged out.")
    return redirect("index")


def login_success(request):
    messages.success(request, "You have successfully logged in.")
    return redirect("index")


def shiny(request, app_slug):
    if not user_has_access(request.user, app_slug):
        return redirect(f"/login/?next=/shiny/{app_slug}/")
    return render(
        request, "djangoapp/shiny.jinja", {"active_tab": app_slug, "app_slug": app_slug}
    )


def shiny_contents(request, app_slug):
    if not user_has_access(request.user, app_slug):
        return redirect(f"/login/?next=/shiny/{app_slug}/")
    response = requests.get(f"http://{app_slug}-service:8100")
    soup = BeautifulSoup(response.content, "html.parser")
    return JsonResponse({"html_contents": str(soup)})


def auth(request, app_slug):
    if not user_has_access(request.user, app_slug):
        return HttpResponse(status=200)
    return HttpResponse(status=403)
