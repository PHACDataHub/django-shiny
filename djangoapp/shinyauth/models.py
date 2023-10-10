from django.db import models
from shinyauth import devops
import re


class ShinyApp(models.Model):
    # Required: added from the shiny_apps.json file
    slug = models.SlugField(max_length=50, unique=True)
    repo = models.CharField(max_length=500)
    branch = models.CharField(max_length=100, default="main")

    # Optional: edited manually in the admin interface
    display_name = models.CharField(max_length=100, blank=True)
    description = models.CharField(max_length=500, blank=True)
    contact_email = models.EmailField(blank=True)
    thumbnail = models.ImageField(upload_to='thumbnails', null=True, blank=True)

    # When there are no user groups, only admins can access the app
    accessible_by = models.ManyToManyField('UserGroup', related_name='accessible_by', blank=True)
    visible_to = models.ManyToManyField('UserGroup', related_name='visible_to', blank=True)

    def __str__(self):
        return self.display_name if self.display_name else self.slug
    
    def check_access(self, user):
        # Accessible by admins and to users matching accessible_to
        if user.is_superuser:
            return True
        # Anonymous users can only access public apps
        if user.is_anonymous:
            return self.is_publicly_accessible
        for group in self.accessible_by.all():
            # Check user email against regexes for each group
            for match in group.email_matches.all():
                if re.match(match.email_regex, user.email):
                    return True
        return False
    
    def check_visibility(self, user):
        # Visible to admins and to users matching accessible_to OR visible_to
        if user.is_superuser:
            return True
        if user.is_anonymous:
            return self.is_publicly_viewable
        for group in self.visible_to.all() | self.accessible_by.all():
            # Check user email against regexes for each group
            for match in group.email_matches.all():
                if re.match(match.email_regex, user.email):
                    return True
        return False
    
    def generate_deployment(self):
        devops.generate_deployment(self)

    def deploy(self):
        devops.deploy_app(self)
    
    @property
    def is_admin_only(self):
        return self.accessible_by.count() == 0 and self.visible_to.count() == 0
    
    @property
    def is_publicly_viewable(self):
        public_user_group = UserGroup.objects.get(name='Public')
        return public_user_group in self.visible_to.all() | self.accessible_by.all()
    
    @property
    def is_publicly_accessible(self):
        public_user_group = UserGroup.objects.get(name='Public')
        return public_user_group in self.accessible_by.all()
    

class UserGroup(models.Model):
    # This does not include actual "User" objects, but defines
    # groups of users that can access a shiny app based on their email addresses
    name = models.CharField(max_length=100, unique=True)
    email_matches = models.ManyToManyField('UserEmailMatch', blank=True)

    def __str__(self):
        return self.name + ': ' + ', '.join(
            [e.name for e in self.email_matches.all()]
        )


class UserEmailMatch(models.Model):
    name = models.CharField(max_length=100)
    email_regex = models.CharField(max_length=500)

    def __str__(self):
        return self.name + ': ' + self.email_regex
