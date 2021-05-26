ARG PYTHON_BASE_IMAGE_VERSION=3.7-20210115
FROM metabrainz/python:$PYTHON_BASE_IMAGE_VERSION

ARG PYTHON_BASE_IMAGE_VERSION

LABEL org.label-schema.vcs-url="https://github.com/metabrainz/listenbrainz-server.git" \
      org.label-schema.vcs-ref="" \
      org.label-schema.schema-version="1.0.0-rc1" \
      org.label-schema.vendor="MetaBrainz Foundation" \
      org.label-schema.name="ListenBrainz" \
      org.metabrainz.based-on-image="metabrainz/python:$PYTHON_BASE_IMAGE_VERSION"


ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ENV SENTRY_CLI_VERSION 1.63.1
RUN wget -O /usr/local/bin/sentry-cli https://downloads.sentry-cdn.com/sentry-cli/$SENTRY_CLI_VERSION/sentry-cli-Linux-x86_64 \
    && chmod +x /usr/local/bin/sentry-cli


COPY ./docker/run-lb-command /usr/local/bin
COPY ./docker/lb-startup-common.sh /etc

# runit service files
# All services are created with a `down` file, preventing them from starting
# rc.local removes the down file for the specific service we want to run in a container
# http://smarden.org/runit/runsv.8.html

# cron
COPY ./docker/services/cron/consul-template-cron-config.conf /etc/consul-template-cron-config.conf
COPY ./docker/services/cron/cron-config.service /etc/service/cron-config/run
RUN touch /etc/service/cron/down
RUN touch /etc/service/cron-config/down

# API Compat (last.fm) server
COPY ./docker/services/api_compat/uwsgi-api-compat.ini /etc/uwsgi/uwsgi-api-compat.ini
COPY ./docker/services/api_compat/consul-template-api-compat.conf /etc/consul-template-api-compat.conf
COPY ./docker/services/api_compat/api_compat.service /etc/service/api_compat/run
COPY ./docker/services/api_compat/api_compat.finish /etc/service/api_compat/finish
RUN touch /etc/service/api_compat/down

COPY ./docker/rc.local /etc/rc.local

# crontabs
COPY ./docker/services/cron/stats-crontab /etc/cron.d/stats-crontab
RUN chmod 0644 /etc/cron.d/stats-crontab
COPY ./docker/services/cron/dump-crontab /etc/cron.d/dump-crontab
RUN chmod 0644 /etc/cron.d/dump-crontab


ARG GIT_COMMIT_SHA
LABEL org.label-schema.vcs-ref=$GIT_COMMIT_SHA
ENV GIT_SHA ${GIT_COMMIT_SHA}

USER root
