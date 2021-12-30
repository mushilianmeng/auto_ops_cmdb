from django.db import models
# Create your models here.
from django.utils import timezone


# 记录类型  主机记录  记录值  备注

class log_alarm(models.Model):  # 标签
    ID = models.IntegerField(verbose_name='告警ID')
    log = models.TextField(blank=True, null=True, verbose_name='日志告警信息')
    class Meta:
        db_table = 'log_alarm'
        managed = False

    def __str__(self):
        return str(self.ID)


class alarm(models.Model):
    #ID = models.ForeignKey('log_alarm',verbose_name='告警ID', null=True, blank=True, on_delete=models.CASCADE)
    ID = models.IntegerField(verbose_name='告警ID')
    content = models.CharField(max_length=64, verbose_name='告警信息')
    date = models.DateTimeField(verbose_name='告警接收时间', default=timezone.now)  # 告警接收时间
    is_send = models.IntegerField(verbose_name='告警是否发送')
    send_role = models.CharField(max_length=64, verbose_name='告警角色')
    is_log = models.IntegerField(verbose_name='告警是否是日志告警')
    class Meta:
        db_table = 'alarm'

    def __str__(self):
        return str(self.ID)