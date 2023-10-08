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
