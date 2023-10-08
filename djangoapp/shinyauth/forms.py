from django import forms
from shinyauth.models import ShinyApp, UserGroup, UserEmailMatch


# Form for managing app permissions
class ShinyAppForm(forms.ModelForm):
    class Meta:
        model = ShinyApp
        fields = [
            "slug", "repo", "branch", "display_name", "description",
            "contact_email", "thumbnail", "accessible_by", "visible_to"
        ]
        widgets = {
            "accessible_by": forms.CheckboxSelectMultiple(),
            "visible_to": forms.CheckboxSelectMultiple(),
        }

