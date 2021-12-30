# Generated by Django 2.2.5 on 2019-10-01 14:34

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('assets', '0002_belong'),
    ]

    operations = [
        migrations.AddField(
            model_name='asset',
            name='belong',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, to='assets.Belong', verbose_name='所属公司'),
        ),
    ]
