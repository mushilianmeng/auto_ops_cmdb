# Generated by Django 3.2 on 2021-07-20 03:41

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('ci_cd', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='ci_cd_info',
            name='a_ID',
            field=models.IntegerField(blank=True, default=1),
            preserve_default=False,
        ),
    ]