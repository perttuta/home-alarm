FROM debian:12

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    supervisor \
    mosquitto-clients \
    curl \
    jq \
    procps \
    ffmpeg \
    awscli \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/cache/alarm-video /var/log/supervisor /root/.aws

COPY bin/alarm-delete-video.sh \
     bin/alarm-mqtt-action.sh \
     bin/alarm-publish-photo-action.sh \
     bin/alarm-publish-video-action.sh \
     bin/alarm-record-video.sh \
     bin/alarm-util.sh \
     /usr/bin/

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY supervisor/ /etc/supervisor/conf.d/

RUN chmod +x /usr/bin/alarm-*.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]