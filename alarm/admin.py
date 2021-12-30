from django.contrib import admin

# Register your models here.
from django.contrib import admin
from .models import  log_alarm,alarm
from django.utils.html import format_html



# 列表
class alarmlist(admin.ModelAdmin):


    #ordering = []
    list_display = ['ID','content','date','is_sends','send_role','is_logs'] #分类

    '''重定义is_logs,使前端可读性更好'''
    def is_logs(self,obj):
        if obj.is_log == 1:
            return format_html("<a href=/admin/alarm/log_alarm/"+str(obj.ID)+"/change/>是</a>")
        else:
            return '否'
    is_logs.short_description = u'是否是日志告警'

    '''重定义is_sends,使前端可读性更好'''
    def is_sends(self,obj):
        if obj.is_send == 1:
            return '是'
        else:
            return '否'
    is_sends.short_description = u'告警是否发送'


    list_display_links = ['is_logs']
    list_filter = ['send_role'] #右侧过滤栏
    # list_editable = ['category'] #可编辑项

    empty_value_display = '无数据' # 空数据
    #fk_fields = ('tags',) # 设置显示外键字段

    list_per_page = 20 #每页显示条数

    search_fields = ['content']   #display 展示表字段，filter过滤分类，search搜索内容
    # date_hierarchy = 'publish' #按时间分类

    #exclude = ('view','comment','publish') # 排除字段
    fields = ('content','ID','date','is_send','send_role','is_log')  # 指定文章发布选项



# 分类展示
class log_alarmlist(admin.ModelAdmin):
    list_display = ['ID','log']  # 分类
    search_fields = ['ID']
    #list_display_links = None
    list_per_page = 20  # 每页显示条数


admin.site.register(alarm,alarmlist)
admin.site.register(log_alarm,log_alarmlist)
