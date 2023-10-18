from django.contrib.auth import logout
from django.http import HttpResponse, JsonResponse
from django.shortcuts import render, redirect
from django.contrib import messages
from django.contrib.auth import get_user_model
from django.utils.safestring import mark_safe

from shinyauth.models import ShinyApp, UserGroup, UserEmailMatch
from shinyauth.forms import ShinyAppForm, UserGroupForm, UserEmailMatchForm, UserSuperuserForm

import requests
import threading
from bs4 import BeautifulSoup

User = get_user_model()


def health_check(request):
    return HttpResponse(status=200)


def home(request):
    context = {"active_tab": "index", "apps": ShinyApp.objects.all().order_by("-id")}
    return render(request, "djangoapp/home.jinja", context)


def logout_view(request):
    logout(request)
    messages.success(request, "You have successfully logged out.")
    return redirect("index")


def login_success(request):
    messages.success(request, "You have successfully logged in.")
    return redirect("index")


"""
Shiny app wrapper views
"""


def shiny(request, app_slug):
    app = ShinyApp.objects.get(slug=app_slug)
    if not app.check_access(request.user):
        messages.warning(
            request,
            mark_safe(
                f"You don't have permission to access this app. Please login with an authorized email or <a href='mailto:{app.contact_email}?subject=Access request for PHAC Shiny app: {app}'>email the app administrator</a> to request access."
            ) if app.contact_email else "You don't have permission to access this app. Please login with an authorized email."
        )
        return redirect(f"/login/?next=/shiny/{app_slug}/")
    context = {
        "app_slug": app_slug,
        "app_name": str(app),
        "fullscreen": request.GET.get("fullscreen", False),
        "full_width": app.full_width,
        "title": str(app),
    }
    return render(request, "djangoapp/shiny.jinja", context)


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


"""
App and user management views
"""


def manage_apps(request):
    if not request.user.is_superuser:
        return redirect("index")
    context = {"active_tab": "manage_apps", "apps": ShinyApp.objects.all().order_by("-id")}
    return render(request, "djangoapp/manage_apps.jinja", context)


def manage_app(request, app_slug):
    if not request.user.is_superuser:
        return redirect("index")
    app = ShinyApp.objects.get(slug=app_slug)

    if request.method == "POST":
        # Keep track of original repo and branch
        original_repo = app.repo
        original_branch = app.branch
        original_port = app.port
        original_mem_max = app.mem_max
        original_mem_min = app.mem_min
        form = ShinyAppForm(request.POST, request.FILES, instance=app)
        if form.is_valid():
            form.save()
            app = ShinyApp.objects.get(slug=app_slug)
            # If the repo or branch has changed, we need to update the automation
            if (
                app.repo != original_repo
                or app.branch != original_branch
                or app.port != original_port
                or app.mem_max != original_mem_max
                or app.mem_min != original_mem_min
            ):
                create_app_automation(app)
                messages.success(request, "App hosting info updated. It may take a few minutes for changes to appear.")
            else:
                messages.success(request, "App successfully updated.")
            return redirect("manage_apps")
        else:
            # Show the errors in a message
            messages.error(request, "App could not be updated: " + str(form.errors))

    form = ShinyAppForm(instance=app)
    context = {"active_tab": "manage_apps", "app": app, "form": form}
    return render(request, "djangoapp/manage_app.jinja", context)


def create_app(request):
    if not request.user.is_superuser:
        return redirect("index")
    if request.method == "POST":
        form = ShinyAppForm(request.POST, request.FILES)
        if form.is_valid():
            form.save()
            app = ShinyApp.objects.get(slug=form.cleaned_data["slug"])
            create_app_automation(app)
            messages.success(request, "App successfully created. It may take a few minutes to deploy.")
            return redirect("manage_apps")
        else:
            messages.error(request, "App could not be created: " + str(form.errors))
    context = {"active_tab": "manage_apps", "form": ShinyAppForm(), "create": True}
    return render(request, "djangoapp/manage_app.jinja", context)


def create_app_automation(app):
    # Set up cloud build for the new app
    automation_thread = threading.Thread(target=app.deploy)
    automation_thread.start()
    print(f"started automation thread for deploying app {app}")


def delete_app_automation(app):
    # Delete cloud build for the app
    automation_thread = threading.Thread(target=app.delete_deployment)
    automation_thread.start()
    print(f"started automation thread for deleting app {app}")


def delete_app(request, app_slug):
    if not request.user.is_superuser:
        return redirect("index")
    app = ShinyApp.objects.get(slug=app_slug)
    delete_app_automation(app)
    app.delete()
    messages.success(request, "App successfully deleted.")
    return redirect("manage_apps")


def manage_users(request):
    if not request.user.is_superuser:
        return redirect("index")
    context = {
        "active_tab": "manage_users",
        "user_groups": UserGroup.objects.all(),
        "email_matches": UserEmailMatch.objects.all(),
        "superusers": User.objects.filter(is_superuser=True).all(),
        "non_superusers": User.objects.filter(is_superuser=False).all(),    
    }
    return render(request, "djangoapp/manage_users.jinja", context)


def manage_user_group(request, group_id):
    if not request.user.is_superuser:
        return redirect("index")
    group = UserGroup.objects.get(id=group_id)
    if group.name == "Public":
        # Not allowed to edit this group
        messages.warning(request, "You cannot edit the Public group.")
        return redirect("manage_users")
    if request.method == "POST":
        form = UserGroupForm(request.POST, instance=group)
        if form.is_valid():
            form.save()
            messages.success(request, "User group successfully updated.")
            return redirect("manage_users")
        else:
            messages.error(request, "User group could not be updated: " + str(form.errors))
    context = {
        "active_tab": "manage_users",
        "group": group,
        "form": UserGroupForm(instance=group),
    }
    return render(request, "djangoapp/manage_user_group.jinja", context)


def delete_user_group(request, group_id):
    group = UserGroup.objects.get(id=group_id)
    group.delete()
    messages.success(request, "User group successfully deleted.")
    return redirect("manage_users")


def create_user_group(request):
    if not request.user.is_superuser:
        return redirect("index")
    if request.method == "POST":
        form = UserGroupForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, "User group successfully created.")
            return redirect("manage_users")
        else:
            messages.error(request, "User group could not be created.")
    context = {
        "active_tab": "manage_users",
        "form": UserGroupForm(),
        "group": {"name": "", "users": []},
        "create": True,
    }
    return render(request, "djangoapp/manage_user_group.jinja", context)


def manage_email_match(request, match_id):
    if not request.user.is_superuser:
        return redirect("index")
    match = UserEmailMatch.objects.get(id=match_id)
    if request.method == "POST":
        form = UserEmailMatchForm(request.POST, instance=match)
        if form.is_valid():
            form.save()
            messages.success(request, "Email match successfully updated.")
            return redirect("manage_users")
        else:
            messages.error(request, "Email match could not be updated: " + str(form.errors))
    context = {
        "active_tab": "manage_users",
        "match": match,
        "form": UserEmailMatchForm(instance=match),
    }
    return render(request, "djangoapp/manage_email_match.jinja", context)


def delete_email_match(request, match_id):
    match = UserEmailMatch.objects.get(id=match_id)
    match_groups = list(match.usergroup_set.values_list("id", flat=True))
    match.delete()
    for group_id in match_groups:
        group = UserGroup.objects.get(id=group_id)
        # Delete groups that have no matches anymore
        if group.email_matches.count() == 0:
            group.delete()
    messages.success(request, "Email match successfully deleted.")
    return redirect("manage_users")


def create_email_match(request):
    if not request.user.is_superuser:
        return redirect("index")
    if request.method == "POST":
        form = UserEmailMatchForm(request.POST)
        if form.is_valid():
            form.save()
            if request.POST.get("create_group", False) == "on":
                # Create a user group with the email match
                group = UserGroup()
                group.save()
                group.email_matches.add(form.instance)
                group.save()
                messages.success(request, "Email match and user group successfully created.")
            else:
                messages.success(request, "Email match successfully created.")
            return redirect("manage_users")
        else:
            messages.error(request, "Email match could not be created: " + str(form.errors))
    context = {
        "active_tab": "manage_users",
        "form": UserEmailMatchForm(),
        "match": {"name": "", "email_regex": ""},
        "create": True,
    }
    return render(request, "djangoapp/manage_email_match.jinja", context)


def manage_user(request, user_id):
    # Only superusers can manage users.
    # The purpose of this page is simply set the user as superuser, or not
    if not request.user.is_superuser:
        return redirect("index")
    user = User.objects.get(id=user_id)
    if request.method == "POST":
        form = UserSuperuserForm(request.POST, instance=user)
        if form.is_valid():
            form.save()
            messages.success(request, "User successfully updated.")
            return redirect("manage_users")
        else:
            messages.error(request, "User could not be updated.")
    context = {
        "active_tab": "manage_users",
        "user": user,
        "form": UserSuperuserForm(instance=user),
    }
    return render(request, "djangoapp/manage_user.jinja", context)
