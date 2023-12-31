# Generated by Django 4.2.5 on 2023-10-05 13:19

from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="ShinyApp",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("slug", models.SlugField(unique=True)),
                ("container_url", models.CharField(max_length=500)),
                (
                    "display_name",
                    models.CharField(blank=True, max_length=100, null=True),
                ),
                (
                    "description",
                    models.CharField(blank=True, max_length=500, null=True),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
        ),
    ]
