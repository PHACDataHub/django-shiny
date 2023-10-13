"""
Django settings for djangoapp project.

Generated by 'django-admin startproject' using Django 2.0.3.

For more information on this file, see
https://docs.djangoproject.com/en/2.0/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/2.0/ref/settings/
"""

import json
import os
import environ
from pathlib import Path
from urllib.parse import urlparse

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

env = environ.Env()
env_file = os.path.join(BASE_DIR, ".env")

if os.path.isfile(env_file):
    # Use a local secret file, if provided
    print("Loading .env file")
    env.read_env(env_file)

SECRET_KEY = env("SECRET_KEY", default='abc123')

CLOUDBUILD_CONNECTION = env("CLOUDBUILD_CONNECTION", default=None)

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = env("DEBUG", default=False)
SQLITE_DB = env("SQLITE_DB", default=False)
FAKE_EMAIL = env("FAKE_EMAIL", default=False)

print("DEBUG: ", DEBUG)

ALLOWED_HOSTS = [
    'localhost',
    '127.0.0.1',
    'testserver',
    'djangoapp',
    '34.95.50.116',
    'djangoapp-service.default.svc.cluster.local',
    'shiny.phac.alpha.canada.ca',
]

INTERNAL_IPS = [
    '127.0.0.1',
]

# Application definition
INSTALLED_APPS = [
    "shinyauth.apps.ShinyAuthConfig",
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    "django_jinja",
    "magiclink",
    "django_extensions",
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    "whitenoise.middleware.WhiteNoiseMiddleware",
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

AUTHENTICATION_BACKENDS = (
    "magiclink.backends.MagicLinkBackend",
    "django.contrib.auth.backends.ModelBackend",
)

CSRF_TRUSTED_ORIGINS = [
    'https://shiny.phac.alpha.canada.ca',
]
CSRF_ALLOWED_ORIGINS = [
    'https://shiny.phac.alpha.canada.ca',
]
CORS_ORIGINS_WHITELIST = [
    'https://shiny.phac.alpha.canada.ca',
]

LOGIN_URL = "email_login"
LOGIN_REDIRECT_URL = "/login/success/"  # Redirect to homepage with success banner
MAGICLINK_LOGIN_SENT_TEMPLATE_NAME = "auth/login_link_sent.jinja"
MAGICLINK_LOGIN_FAILED_TEMPLATE_NAME = "auth/login_failed.jinja"
MAGICLINK_REQUIRE_SIGNUP = False
MAGICLINK_TOKEN_USES = 3  # M365 "clicks" links to check them, so must be > 1
MAGICLINK_REQUIRE_SAME_IP = False  # Otherwise M365 checks will invalidate token
MAGICLINK_REQUIRE_SAME_BROWSER = False  # As above
MAGICLINK_EMAIL_SUBJECT = "Login link for PHAC Shiny App Directory"
MAGICLINK_METHOD = env("MAGICLINK_METHOD", default="django_smtp")
ALLOWED_EMAIL_DOMAINS = env.list("ALLOWED_EMAIL_DOMAINS", default=["*"])
GC_NOTIFY_API_KEY = env("GC_NOTIFY_API_KEY", default=None)
GC_NOTIFY_TEMPLATE_ID = env("GC_NOTIFY_TEMPLATE_ID", default=None)
POWER_AUTOMATE_URL = env("POWER_AUTOMATE_URL", default=None)

if FAKE_EMAIL:
    EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
else:
    EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
    EMAIL_HOST = env("EMAIL_HOST", default=None)
    EMAIL_PORT = env("EMAIL_PORT", default=None)
    EMAIL_USE_TLS = env("EMAIL_USE_TLS", default=None)
    EMAIL_HOST_USER = env("EMAIL_HOST_USER", default=None)
    EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD", default=None)
    DEFAULT_FROM_EMAIL = env("EMAIL_FROM", default="fake@email.com")

ROOT_URLCONF = 'djangoapp.urls'

TEMPLATES = [
    {
        "BACKEND": "django_jinja.jinja2.Jinja2",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "globals": {
                "len": len,
                "str": str,
                "list": list,
            },
            "context_processors": [
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
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

WSGI_APPLICATION = 'djangoapp.wsgi.application'


# Database
# https://docs.djangoproject.com/en/2.0/ref/settings/#databases

if SQLITE_DB:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": os.path.join(BASE_DIR, "db.sqlite3"),
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql_psycopg2',
            'NAME': 'postgres',
            'USER': 'postgres',
            'PASSWORD': os.getenv('POSTGRES_PASSWORD'),
            'HOST': 'database-service'
        }
    }
    STORAGES = {
        "default": {"BACKEND": "storages.backends.gcloud.GoogleCloudStorage"},
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
        },
    }
    GS_BUCKET_NAME = env("GS_BUCKET_NAME")
    GS_BLOB_CHUNK_SIZE = 5 * 1024 * 1024
    GS_FILE_OVERWRITE = False


# Password validation
# https://docs.djangoproject.com/en/2.0/ref/settings/#auth-password-validators

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
# https://docs.djangoproject.com/en/2.0/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_L10N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/2.0/howto/static-files/

MEDIA_ROOT = os.path.join(BASE_DIR, "media")
MEDIA_URL = '/media/'

STATIC_URL = '/static/'

if DEBUG:
    STATICFILES_DIRS = [
        os.path.join(BASE_DIR, "static"),
    ]
else:
    STATIC_ROOT = BASE_DIR + '/static/'

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

APPEND_SLASH = True
