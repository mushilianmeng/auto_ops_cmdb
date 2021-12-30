from django.db import models

# Create your models here.

class alarm(models.Model):
    log = models.TextField()
    def __str__(self):
        return self.log