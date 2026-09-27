#!/bin/bash
set -e

# The alarm scripts load their config from $ENV_FILE. Source it here too so the
# AWS profile written below can reuse the same settings.
if [ -n "${ENV_FILE:-}" ] && [ -f "$ENV_FILE" ]; then
    set -a; source "$ENV_FILE"; set +a
fi

# Write AWS credentials for the profile used by the alarm scripts.
# Values are taken from env vars so the same image works for both real AWS
# (production) and a local S3 instance (testing).
mkdir -p /root/.aws

if [ -n "${S3_ACCESS_KEY_ID:-}" ]; then
    cat > /root/.aws/credentials <<EOF
[${S3_PROFILE:-alarm-video-s3}]
aws_access_key_id = ${S3_ACCESS_KEY_ID}
aws_secret_access_key = ${S3_SECRET_ACCESS_KEY}
EOF

    cat > /root/.aws/config <<EOF
[profile ${S3_PROFILE:-alarm-video-s3}]
region = ${S3_REGION:-eu-west-1}
EOF
fi

exec supervisord -n -c /etc/supervisor/supervisord.conf