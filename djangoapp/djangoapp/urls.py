from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("", include("shinyauth.urls")),
    path('admin/', admin.site.urls),
    path('auth/', include('magiclink.urls', namespace='magiclink')),
]
