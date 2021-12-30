from django.apps import AppConfig
import os

default_app_config = 'assets.Asset'
VERBOSE_APP_NAME = "资产管理"


def get_current_app_name(_file):
    return os.path.split(os.path.dirname(_file))[-1]


class Asset(AppConfig):
    name = get_current_app_name(__file__)
    verbose_name = VERBOSE_APP_NAME