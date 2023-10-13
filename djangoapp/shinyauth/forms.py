import re

from django import forms
from shinyauth.models import ShinyApp, UserGroup, UserEmailMatch
from django.contrib.auth import get_user_model
from django.core.validators import EmailValidator


User = get_user_model()


# Form for managing app permissions
class ShinyAppForm(forms.ModelForm):
    class Meta:
        model = ShinyApp
        fields = [
            "slug", "repo", "branch", "display_name", "description",
            "contact_email", "thumbnail", "accessible_by", "visible_to"
        ]
        # Choices for the accessible_by and visible_to fields
        # are from the UserGroup model
        widgets = {
            "accessible_by": forms.CheckboxSelectMultiple(),
            "visible_to": forms.CheckboxSelectMultiple()
        }

        # Set the choices
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.fields["accessible_by"].queryset = UserGroup.objects.all()
            self.fields["visible_to"].queryset = UserGroup.objects.all()

        # "slug" MUST NOT be one of the following: "database", "djangoapp"
        def clean_slug(self):
            slug = self.cleaned_data["slug"]
            if slug in [
                "database",
                "djangoapp",
                "djangoapp-ingress",
                "djangoapp-migrate",
                "database-storage",
                "djangoapp-storage",
                "secrets",
                "issuer-lets-encrypt-production"
            ]:
                raise forms.ValidationError("The slug cannot be a system-reserved name.")
            return slug


# Form for managing user groups
class UserGroupForm(forms.ModelForm):
    class Meta:
        model = UserGroup
        fields = [
            "name", "email_matches"
        ]
        widgets = {
            "email_matches": forms.CheckboxSelectMultiple()
        }

    # Set the choices
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["email_matches"].queryset = UserEmailMatch.objects.all()

    # At least one email_matches must be selected
    def clean(self):
        cleaned_data = super().clean()
        # Check if at least one checkbox is selected
        email_matches = cleaned_data.get("email_matches")
        if not email_matches:
            raise forms.ValidationError("At least one email match must be selected")
        return cleaned_data


# Form for managing user email matches
class UserEmailMatchForm(forms.ModelForm):
    class Meta:
        model = UserEmailMatch
        fields = [
            "name", "match", "match_type"
        ]
        # Specify match_type as bootstrap select widget
        widgets = {
            "match_type": forms.Select(attrs={"class": "form-select"})
        }
    def clean(self):
        cleaned_data = super().clean()
        match_type = cleaned_data.get("match_type")
        match = cleaned_data.get("match")

        # When match is regex, it must be *valid* regex
        if match_type == "regex":
            try:
                re.compile(match)
            except re.error as e:
                raise forms.ValidationError(f"The regex {match} is invalid: {str(e)}")
        elif match_type == "domain":
            if not match.startswith("@"):
                raise forms.ValidationError("Domain matches must start with @")
        elif match_type == "exact":
            # Must be a valid email address
            validator = EmailValidator()
            try:
                validator(match)
            except forms.ValidationError as e:
                raise forms.ValidationError(f"{match} is not a valid email address")
        return cleaned_data


# Form for making a user a superuser
class UserSuperuserForm(forms.ModelForm):
    class Meta:
        model = User
        fields = [
            "is_superuser"
        ]
        widgets = {
            "is_superuser": forms.CheckboxInput()
        }
