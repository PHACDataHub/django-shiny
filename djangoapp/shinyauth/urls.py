from django.urls import path

from shinyauth import views
from . import magiclink_views

urlpatterns = [
    path('', views.home, name='index'),

    path("login/", magiclink_views.EmailLoginView.as_view(), name="email_login"),
    path("logout/", views.logout_view, name="logout"),
    path("login/success/", views.login_success, name="login_success"),

    path('shiny/<str:app_slug>/', views.shiny, name='shiny'),
    path('shiny_contents/<str:app_slug>/', views.shiny_contents, name='shiny_contents'),
    path('shiny_auth/<str:app_slug>/', views.auth, name='shiny_auth'),

    path('manage_apps/', views.manage_apps, name='manage_apps'),
    path('manage_app/<str:app_slug>/', views.manage_app, name='manage_app'),

    path('manage_users/', views.manage_users, name='manage_users'),
]
