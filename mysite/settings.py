"""
Django settings for mysite project.

Generated by 'django-admin startproject' using Django 2.2.5.

For more information on this file, see
https://docs.djangoproject.com/en/2.2/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/2.2/ref/settings/
"""

import os

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/2.2/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = ')__4+br89g(k+mzg+@(n3g20a1d4=v7wktly3esrtv0#u)8%*h'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

ALLOWED_HOSTS = ["*"]

DEFAULT_AUTO_FIELD = 'django.db.models.AutoField'
# Application definition

INSTALLED_APPS = [
    'simpleui',
    'import_export',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'assets',
    'alarm',
    'log',
    'ci_cd',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    #'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'mysite.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'mysite.wsgi.application'


# Database
# https://docs.djangoproject.com/en/2.2/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'auto_ops_cmdb',
        'USER':'root',
        'PASSWORD':'oneinstack',
        'HOST':'10.0.0.63',
        'PORT':'3306',
        'OPTIONS':{'isolation_level':None}
    }
}


# Password validation
# https://docs.djangoproject.com/en/2.2/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/2.2/topics/i18n/



LANGUAGE_CODE = 'zh-hans'
TIME_ZONE = 'UTC'

USE_I18N = True
USE_L10N = True
USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/2.2/howto/static-files/

STATIC_URL = '/static/'
STATICFILES_DIRS = (
    os.path.join(BASE_DIR, "static", ),
)

STATIC_ROOT = os.path.join(BASE_DIR, "/static/")


# 媒体文件的路径
MEDIA_ROOT = os.path.join(BASE_DIR, 'uploads')
MEDIA_URL = '/media/'

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'loggers': {
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
        },
    },
}




### simpleui 配置 ###
# 隐藏simpleui服务器信息
SIMPLEUI_HOME_INFO = False
# Logo图标
SIMPLEUI_LOGO = '/static/custom/img/logo.png'
# False的时候，默认从第三方的cdn获取加载静态资源 2.1.3或以上的版本
SIMPLEUI_STATIC_OFFLINE = True


LOGIN_URL = 'admin/login/'
LOGIN_REDIRECT_URL = '/'
# 认证登录




SIMPLEUI_CONFIG = {
    'system_keep': False,
    'menus': [

        {
            'app': 'assets',
            'name': '资产管理',
            'icon': 'fas fa-archive',
            'models': [
                {
                    'name': '账户信息',
                    'url': 'assets/asset',
                    'icon': 'fas fa-archive'
                },
                {
                    'name': '所属项目',
                    'url': 'assets/area',
                    'icon': 'fas fa-landmark'
                },
                {
                    'name': '厂家信息',
                    'url': 'assets/manufacturer',
                    'icon': 'fas fa-address-book'
                },


            ]
        },

        {
            'app': 'alarm',
            'name': '告警机器人',
            'icon': 'icon fas fa-tags',
            'models': [
                {
                    'name': '告警',
                    'url': 'alarm/alarm',
                    'icon': 'fas fa-list'
                },
                {
                    'name': '日志告警',
                    'url': 'alarm/log_alarm',
                    'icon': 'icon fas fa-tags'
                },
            ]
        },

        {
            'app': 'ci_cd',
            'name': '持续发布',
            'icon': 'icon fas fa-tags',
            'models': [
                {
                    'name': '发版信息',
                    'url': 'ci_cd/ci_cd_info',
                    'icon': 'fas fa-list'
                },
            ]
        },

        {
            'app': 'auth',
            'name': '权限认证',
            'icon': 'fas fa-user-shield',
            'models': [
                {
                    'name': '用户',
                    'icon': 'fa fa-user',
                    'url': 'auth/user'
                },
                {
                    'name': '用户组',
                    'icon': 'fa fa-user-friends',
                    'url': 'auth/group'
                }

            ]
        }]
}
