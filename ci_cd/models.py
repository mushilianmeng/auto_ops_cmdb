from django.db import models

# Create your models here.
class ci_cd_info(models.Model):
    ID = models.AutoField(auto_created=True,primary_key=True, serialize=False, verbose_name='ID',blank=True, null=False)
    requestid = models.IntegerField(blank=True,unique=True,null=False,verbose_name='OA请求ID')
    xiang_mu = models.CharField(max_length=255, blank=True, null=False,verbose_name='项目')
    date = models.CharField(max_length=255, blank=True, null=False,verbose_name='拉包时间')
    jar_pack = models.CharField(max_length=255,blank=True, null=False,verbose_name='jar包名')
    jar_url = models.CharField(max_length=255,blank=True, null=False,verbose_name='jar包地址')
    status = models.IntegerField(blank=True, null=False)
    class Meta:
        db_table = 'ci_cd_info'
        managed = False
    def __str__(self):
        return str(self.jar_url+"/"+self.jar_pack)
