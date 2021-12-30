from django.http import HttpResponse
from log.models import alarm

def logs(request):
    return HttpResponse(alarm.objects.get(id=request.GET["id"]))