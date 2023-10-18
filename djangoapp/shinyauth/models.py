from django.db import models
from shinyauth import devops
import re


def check_matches(user, groups):
    for group in groups:
        for match in group.email_matches.all():
            if match.match_type == "exact":
                if user.email == match.match:
                    return True
            elif match.match_type == "domain":
                if user.email.endswith(match.match):
                    return True
            elif match.match_type == "regex":
                try:
                    if re.match(match.match, user.email):
                        return True
                except:
                    # If the email regex is invalid, skip it
                    print(f"Invalid email regex: {match.match}")
                    pass
    return False


class ShinyApp(models.Model):
    # Required for hosting
    slug = models.SlugField(max_length=50, unique=True)
    repo = models.CharField(max_length=500)
    branch = models.CharField(max_length=100, default="main")
    port = models.IntegerField(default=8100)
    mem_min = models.IntegerField(default=1024) # Mi
    mem_max = models.IntegerField(default=2048) # Mi
    cpu_min = models.FloatField(default=0.5) # vCPU
    cpu_max = models.FloatField(default=1) # vCPU

    # Optional: edited manually in the admin interface
    display_name = models.CharField(max_length=100, blank=True)
    description = models.CharField(max_length=500, blank=True)
    contact_email = models.EmailField(blank=True)
    thumbnail = models.ImageField(upload_to='thumbnails', null=True, blank=True)
    full_width = models.BooleanField(default=True)
    full_width_header = models.BooleanField(default=False)

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
                try:
                    if re.match(match.email_regex, user.email):
                        return True
                except:
                    # If the email regex is invalid, skip it
                    print(f"Invalid email regex: {match.email_regex}")
                    pass
        return False
    
    def check_visibility(self, user):
        # Visible to admins and to users matching accessible_to OR visible_to
        if user.is_superuser:
            return "accessible"
        if user.is_anonymous:
            if self.is_publicly_accessible:
                return "accessible"
            elif self.is_publicly_viewable:
                return "viewable"
            else:
                return False
        if check_matches(user, self.accessible_by.all()):
            return "accessible"
        if check_matches(user, self.visible_to.all()):
            return "viewable"
        return False
    
    def generate_deployment(self):
        devops.generate_deployment(self)

    def deploy(self):
        devops.deploy_app(self)

    def delete_deployment(self):
        devops.delete_app(self)
    
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
    name = models.CharField(max_length=100, blank=True)
    email_matches = models.ManyToManyField('UserEmailMatch', blank=True)

    def __str__(self):
        str_value = self.name
        if self.email_matches.count() > 0:
            if self.name:
                str_value += ": "
            str_value += f"{', '.join([str(match) for match in self.email_matches.all()])}"
        return str_value


class UserEmailMatch(models.Model):
    name = models.CharField(max_length=100, blank=True)
    match = models.CharField(max_length=500)
    match_type = models.CharField(max_length=10, choices=[
        ('exact', 'Exact (e.g. person@example.com)'),
        ('domain', 'Domain (e.g. @example.com)'),
        ('regex', 'Regular expression (e.g. .*@.*\.gc\.ca$)'),
    ], default='exact')

    def __str__(self):
        return self.name or self.match
