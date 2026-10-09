FROM python:3.11-slim

RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends git make gcc libpq-dev > /dev/null \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

WORKDIR /opt/dbt
ENV DBT_PROFILES_DIR=/opt/dbt
