from django.contrib import admin
from django.urls import include, path

from django.conf import settings
from django.conf.urls.static import static
from django.conf.urls.i18n import i18n_patterns

from  phac_aspc.django.helpers.urls import urlpatterns as phac_aspc_helper_urls

urlpatterns = [
    *phac_aspc_helper_urls,
]

urlpatterns += i18n_patterns (
    path("", include("shinyauth.urls")),
    path('admin/', admin.site.urls),
    path('auth/', include('magiclink.urls', namespace='magiclink')),
    prefix_default_language=False,
)

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL,
                            document_root=settings.MEDIA_ROOT)
