from django.db import models

# Create your models here.




class Asset(models.Model):
    """    所有资产的共有数据表    """
    asset_type_choice = (
        ('cloud_host', '云主机'),
        ('virtual_machine', '虚拟机'),
        ('virtual_node','虚拟机节点'),
        ('container_node','容器主机节点'),
        ('server', '物理机'),
        ('switch', '交换机'),
        ('route', '路由器'),
        ('firewall', '防火墙'),
        ('mysql','mysql数据库'),
        ('oracle','oracle数据库'),
        ('VPN','VPN虚拟专用网络'),
        ('pgsql', 'PostgreSQL数据库')
    )# 类型


    asset_status_choice = (
        (0, '激活'),
        (1, '停用'),
        (2, '故障'),
    )# 状态




    UHIGH_CHOICE = (
        (0, 1),
        (1, 2),
        (2, 4),
        (9,0)
    )# u数
    #choices 用于页面上的选择框标签，需要先提供一个二维的二元元组

    area = models.ForeignKey('Area',verbose_name='项目', null=True, blank=True, on_delete=models.CASCADE)
    ip_url = models.CharField(max_length=64, unique=True,verbose_name='ip地址/URL') # 服务器的ip地址
    # ipadd = models.GenericIPAddressField(verbose_name='IP地址')  # 指定了ip类型
    ipadd = models.CharField(max_length=32, blank=True, null=True,unique=False,verbose_name='账号')
    sn = models.CharField(max_length=128, null=True, blank=True, unique=False, verbose_name="密码")  # 不可重复
    manufacturer = models.ForeignKey('Manufacturer',verbose_name='厂家', null=True, blank=True, on_delete=models.CASCADE)
    asset_type = models.CharField(choices=asset_type_choice, max_length=64, default='virtual_machine', verbose_name="资产类型")
    status = models.SmallIntegerField(choices=asset_status_choice, default=0, verbose_name='设备状态')

    cpu = models.CharField(max_length=60,blank=True, null=True)
    disk = models.CharField(max_length=60,blank=True, null=True)
    memory = models.CharField(max_length=60,blank=True, null=True)
    cabinet = models.CharField(max_length=32, null=True, blank=True, verbose_name='机柜号')
    uhight = models.IntegerField(choices=UHIGH_CHOICE, null=True, blank=True, verbose_name="u高")
    railnum = models.IntegerField(null=True, blank=True, verbose_name="导轨位置")
    put_shelf_time = models.DateField(verbose_name='上线时间')
    ctime = models.DateTimeField(auto_now_add=True, null=True,blank=True,verbose_name='创建时间')
    utime = models.DateTimeField(auto_now=True, null=True, blank=True, verbose_name='更新时间')
    comment = models.TextField(max_length=128, default='', blank=True, verbose_name='备注')
    def __str__(self):
        return self.ip_url
    class Meta:
        verbose_name_plural = "账户信息"
        ordering = ['-ctime']


class Area(models.Model):
    """机房"""
    name = models.CharField(max_length=64, unique=True, verbose_name="项目")   #xxx机房；阿里云xx区
    subnet = models.CharField(max_length=64,blank=True, null=True, default='', verbose_name="IP地址段")
    bandwidth = models.CharField(max_length=32, blank=True, null=True, default='', verbose_name='出口带宽')
    contact = models.CharField(max_length=16, blank=True, null=True, verbose_name='联系人')
    phone = models.CharField(max_length=32, blank=True, null=True, verbose_name='联系电话')
    address = models.CharField(max_length=128, blank=True, null=True, default='', verbose_name="机房地址")
    contract_date = models.CharField(max_length=30, null=True, verbose_name='合同时间')
    describe = models.TextField(max_length=128,blank=True, null=True, verbose_name='备注')
    needed_cabinet = models.BooleanField(default=False, verbose_name=u"是否需要渲染机架图")

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "所属区域"


class Manufacturer(models.Model):
    """
    供应商
    """
    name = models.CharField(max_length=32, unique=True,verbose_name='厂家供应商')
    contact = models.CharField(max_length=16, blank=True, null=True, verbose_name='联系人')
    phone = models.CharField(max_length=32, blank=True, null=True, verbose_name='联系电话')
    describe = models.TextField(max_length=128, blank=True, null=True, verbose_name='备注')

    def __str__(self):
        return self.name
    class Meta:
       verbose_name_plural = "厂家信息"