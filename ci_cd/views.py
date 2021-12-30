from django.http import HttpResponse
from ci_cd.models import ci_cd_info

def ci_cd_info(request):
    return HttpResponse(info.objects.get(status=request.GET["status"]))