from django.contrib import admin

# Register your models here.
from .models import ci_cd_info

class info(admin.ModelAdmin):
    list_display = ['ID','requestid','xiang_mu','date','jar_pack','jar_url','status']
    list_filter = ['xiang_mu']
    search_fields = ['jar_pack']  # display 展示表字段，filter过滤分类，search搜索内容
admin.site.register(ci_cd_info,info)