FROM google/cloud-sdk:latest

ENV PYTHONUNBUFFERED 1
RUN mkdir -p /opt/services/djangoapp/src
WORKDIR /opt/services/djangoapp/src

COPY requirements.txt /opt/services/djangoapp/src/
RUN pip install -r requirements.txt

COPY . /opt/services/djangoapp/src

EXPOSE 8000
CMD ["gunicorn", "-c", "config/gunicorn/conf.py", "--bind", ":8000", "--chdir", "djangoapp", "djangoapp.wsgi:application"]
