# Generated by Django 4.2.6 on 2023-10-08 14:27

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("shinyauth", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="UserEmailMatch",
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
                ("name", models.CharField(max_length=100)),
                ("email_regex", models.CharField(max_length=500)),
            ],
        ),
        migrations.RemoveField(
            model_name="shinyapp",
            name="container_url",
        ),
        migrations.RemoveField(
            model_name="shinyapp",
            name="created_at",
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="branch",
            field=models.CharField(default="main", max_length=100),
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="contact_email",
            field=models.EmailField(blank=True, max_length=254, null=True),
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="repo",
            field=models.CharField(default="missing!", max_length=500),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="thumbnail",
            field=models.ImageField(blank=True, null=True, upload_to="thumbnails"),
        ),
        migrations.CreateModel(
            name="UserGroup",
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
                ("name", models.CharField(max_length=100, unique=True)),
                (
                    "email_matches",
                    models.ManyToManyField(blank=True, to="shinyauth.useremailmatch"),
                ),
            ],
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="accessible_by",
            field=models.ManyToManyField(
                blank=True, related_name="accessible_by", to="shinyauth.usergroup"
            ),
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="visible_to",
            field=models.ManyToManyField(
                blank=True, related_name="visible_to", to="shinyauth.usergroup"
            ),
        ),
    ]
