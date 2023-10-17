from django.db import migrations


def multiply_memory(apps, schema_editor):
    # Multiple memory values by 1024 since we are using MiB units instead of GiB
    ShinyApp = apps.get_model("shinyauth", "ShinyApp")
    for app in ShinyApp.objects.all():
        app.mem_min = app.mem_min * 1024
        app.mem_max = app.mem_max * 1024
        app.save()


class Migration(migrations.Migration):
    dependencies = [
        ("shinyauth", "0006_shinyapp_cpu_max_shinyapp_cpu_min_and_more"),
    ]

    operations = [
        migrations.RunPython(multiply_memory),
    ]