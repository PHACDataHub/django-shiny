# Generated by Django 4.2.6 on 2023-10-17 14:58

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("shinyauth", "0005_shinyapp_mem_max_shinyapp_mem_min_shinyapp_port"),
    ]

    operations = [
        migrations.AddField(
            model_name="shinyapp",
            name="cpu_max",
            field=models.FloatField(default=1),
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="cpu_min",
            field=models.FloatField(default=0.25),
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="full_width",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="shinyapp",
            name="full_width_header",
            field=models.BooleanField(default=False),
        ),
    ]
