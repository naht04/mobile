from django.db import migrations, models


class Migration(migrations.Migration):
    """Add profile interests used by the friend recommendation score."""

    dependencies = [
        ("users", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="profile",
            name="interests",
            field=models.JSONField(blank=True, default=list),
        ),
    ]
