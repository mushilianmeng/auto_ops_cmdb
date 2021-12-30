from django.contrib import admin

# Register your models here.


from django.contrib import admin
from assets.models import *
from import_export import resources
from import_export.admin import ImportExportModelAdmin, ImportExportActionModelAdmin


class ProxyResource(resources.ModelResource):
    class Meta:
        model = Asset


@admin.register(Asset)
class Assetlist(ImportExportActionModelAdmin):

    resource_class = ProxyResource # 支持导入导出

    # ordering = []
    list_display = ['ip_url', 'ipadd', 'sn', 'area', 'asset_type', 'manufacturer', 'put_shelf_time', ]  # 分类
    list_filter = ['area', 'manufacturer']  # 右侧过滤栏
    # list_editable = ['manufacturer'] #可编辑项
    empty_value_display = '-'  # 空数据
    # fk_fields = ('tags',) # 设置显示外键字段

    list_per_page = 100  # 每页显示条数

    search_fields = ['sn', 'ip_url', 'ipadd']  # display 展示表字段，filter过滤分类，search搜索内容
    date_hierarchy = 'ctime'  # 按时间分类

    exclude = ('ctime', 'utime')  # 排除字段
    # fields = (('title','category'),'body','tags')  # 指定文章发布选项


# 名称、备注
class Arealist(admin.ModelAdmin):
    list_display = ['name','describe']


# 分类排序
from django.utils.text import capfirst

def find_model_index(name):
    count = 0
    for model, model_admin in admin.site._registry.items():
        if capfirst(model._meta.verbose_name_plural) == name:
            return count
        else:
            count += 1
    return count


def index_decorator(func):
    def inner(*args, **kwargs):
        templateresponse = func(*args, **kwargs)
        for app in templateresponse.context_data['app_list']:
            app['models'].sort(key=lambda x: find_model_index(x['name']))
        return templateresponse

    return inner
admin.site.index = index_decorator(admin.site.index)
admin.site.app_index = index_decorator(admin.site.app_index)






# 注册模块,前台显示
# admin.site.register(Asset) #资产
admin.site.register(Area,Arealist) #区域
admin.site.register(Manufacturer,Arealist) # 厂家


admin.site.site_header = '拓安信运维中台'
admin.site.site_title = '运维后台'