FROM python:3.10

ENV PYTHONUNBUFFERED 1
RUN mkdir -p /opt/services/djangoapp/src
WORKDIR /opt/services/djangoapp/src

COPY requirements.txt /opt/services/djangoapp/src/
RUN pip install -r requirements.txt

COPY . /opt/services/djangoapp/src

EXPOSE 8000
# ENTRYPOINT ["/opt/services/djangoapp/src/djangoapp/entrypoint.sh"]
CMD ["gunicorn", "-c", "config/gunicorn/conf.py", "--bind", ":8000", "--chdir", "djangoapp", "djangoapp.wsgi:application"]
