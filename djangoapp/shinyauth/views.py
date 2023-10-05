from django.contrib.auth.decorators import login_required
from django.contrib.auth import logout
from django.http import HttpResponse, JsonResponse
from django.shortcuts import render, redirect
from django.contrib import messages

from djangoapp.settings import env

import requests

from bs4 import BeautifulSoup


def home(request):
    return render(request, "djangoapp/home.jinja", {"active_tab": "index"})


def logout_view(request):
    logout(request)
    messages.success(request, "You have successfully logged out.")
    return redirect("index")


def login_success(request):
    # Add success message
    messages.success(request, "You have successfully logged in.")
    return redirect("index")


@login_required
def shiny(request, app_slug):
    return render(
        request, "djangoapp/shiny.jinja", {"active_tab": app_slug, "app_slug": app_slug}
    )


@login_required
def shiny_contents(request, app_slug):
    response = requests.get(f"http://{app_slug}-service:8100")
    soup = BeautifulSoup(response.content, "html.parser")
    return JsonResponse({"html_contents": str(soup)})


def auth(request, app_slug):
    """
    TODO: Modify to use per-application/per-user permissions checking
    """
    if request.user.is_authenticated:
        return HttpResponse(status=200)
    return HttpResponse(status=403)
