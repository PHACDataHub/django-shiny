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

    path('manage/apps/', views.manage_apps, name='manage_apps'),
    path('manage/app/<str:app_slug>/', views.manage_app, name='manage_app'),
    path('manage/apps/create/', views.create_app, name='create_app'),
    path('manage/app/delete/<str:app_slug>/', views.delete_app, name='delete_app'),

    path('manage/users/', views.manage_users, name='manage_users'),
    path('manage/user/<int:user_id>/', views.manage_user, name='manage_user'),
    
    path('manage/user_group/<int:group_id>/', views.manage_user_group, name='manage_user_group'),
    path('manage/user_group/create/', views.create_user_group, name='create_user_group'),
    path('manage/user_group/delete/<int:group_id>/', views.delete_user_group, name='delete_user_group'),
    
    path('manage/email_match/<int:match_id>/', views.manage_email_match, name='manage_email_match'),
    path('manage/email_match/create/', views.create_email_match, name='create_email_match'),
    path('manage/email_match/delete/<int:match_id>/', views.delete_email_match, name='delete_email_match'),
]   
