from django import forms
from shinyauth.models import ShinyApp, UserGroup, UserEmailMatch
from django.contrib.auth import get_user_model

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
            if slug == "database" or slug == "djangoapp":
                raise forms.ValidationError("The slug cannot be 'database' or 'djangoapp'.")
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


# Form for managing user email matches
class UserEmailMatchForm(forms.ModelForm):
    class Meta:
        model = UserEmailMatch
        fields = [
            "name", "email_regex"
        ]


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
