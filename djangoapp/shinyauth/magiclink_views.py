"""
Override magiclink package methods to only allow certain emails
Also provides for different email APIs
"""

import json
import logging

import requests
from django.contrib.auth import get_user_model, logout
from django.http import HttpResponseRedirect
from magiclink import settings
from magiclink.forms import LoginForm
from magiclink.helpers import create_magiclink, get_or_create_user
from magiclink.models import MagicLinkError
from magiclink.utils import get_url_path
from magiclink.views import Login

from djangoapp.settings import (
    ALLOWED_EMAIL_DOMAINS,
    GC_NOTIFY_API_KEY,
    GC_NOTIFY_TEMPLATE_ID,
    MAGICLINK_METHOD,
    POWER_AUTOMATE_URL,
)

# from notifications_python_client.notifications import NotificationsAPIClient


User = get_user_model()
log = logging.getLogger(__name__)


class EmailLoginView(Login):
    template_name = "auth/login.jinja"

    def post(self, request, *args, **kwargs):
        logout(request)
        context = self.get_context_data(**kwargs)
        context["require_signup"] = settings.REQUIRE_SIGNUP
        form = LoginForm(request.POST)
        if not form.is_valid():
            context["login_form"] = form
            return self.render_to_response(context)

        email = form.cleaned_data["email"]
        if not (
            "*" in ALLOWED_EMAIL_DOMAINS
            or email.split("@")[-1] in ALLOWED_EMAIL_DOMAINS
        ):
            form.add_error(
                "email", f"Email must end in {' | '.join(ALLOWED_EMAIL_DOMAINS)}"
            )
            context["login_form"] = form
            return self.render_to_response(context)

        if not settings.REQUIRE_SIGNUP:
            get_or_create_user(email)

        redirect_url = self.login_redirect_url(request.GET.get("next", ""))
        try:
            magiclink = create_magiclink(email, request, redirect_url=redirect_url)
        except MagicLinkError as e:
            form.add_error("email", str(e))
            context["login_form"] = form
            return self.render_to_response(context)

        magiclink_url = magiclink.generate_url(request)

        # Option 1: Use Django SMTP to send email (e.g. through SendGrid)
        if MAGICLINK_METHOD == "django_smtp":
            magiclink.send(request)

        # Option 2: Use GC Notify to send email
        elif MAGICLINK_METHOD == "gc_notify":
            notifications_client = NotificationsAPIClient(
                GC_NOTIFY_API_KEY, base_url="https://api.notification.canada.ca"
            )
            response = notifications_client.send_email_notification(
                email_address=email,
                template_id=GC_NOTIFY_TEMPLATE_ID,
                personalisation={
                    "magiclink": magiclink_url,
                    "magiclink_expiry": magiclink.expiry.strftime("%Y-%m-%d %H:%M:%S"),
                },
            )

        # Option 3: Send POST request to Power Automate to send email
        elif MAGICLINK_METHOD == "power_automate":
            url = POWER_AUTOMATE_URL
            payload = json.dumps(
                {
                    "email": email,
                    "magiclink": magiclink_url,
                    "expiry": magiclink.expiry.strftime("%Y-%m-%d %H:%M:%S"),
                }
            )
            headers = {"Content-Type": "application/json"}
            response = requests.request("POST", url, headers=headers, data=payload)

        else:
            raise ValueError(f"Invalid magiclink_method: {MAGICLINK_METHOD}")

        log.info(f"Email sent to {email} with link {magiclink_url}.")
        sent_url = get_url_path(settings.LOGIN_SENT_REDIRECT)
        response = HttpResponseRedirect(sent_url)
        if settings.REQUIRE_SAME_BROWSER:
            cookie_name = f"magiclink{magiclink.pk}"
            response.set_cookie(cookie_name, magiclink.cookie_value)
            log.info(f"Cookie {cookie_name} set for {email}")
        return response
