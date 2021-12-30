FROM python:3.7
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY cmdb /usr/src/app/
RUN pip  install -i http://mirrors.aliyun.com/pypi/simple  --trusted-host mirrors.aliyun.com  -r install/requirements.txt
RUN python manage.py makemigrations
RUN python manage.py migrate
CMD [ "python", "./manage.py", "runserver", "0.0.0.0:8080"]


# git clone https://gitee.com/attacker/cmdb
# docker build -t lghost/cmdb:latest .
