"""
Django models go here
"""

from django.db import models
from django.contrib.auth.models import User


class ShinyApp(models.Model):
    """
    ShinyApp model
    """
    slug = models.SlugField(max_length=50, unique=True)
    container_url = models.CharField(max_length=500)
    display_name = models.CharField(max_length=100, null=True, blank=True)
    description = models.CharField(max_length=500, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.display_name if self.display_name else self.slug
