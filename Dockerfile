# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN groupadd --gid 10001 sdm && \
    useradd --uid 10001 --gid sdm --shell /sbin/nologin --create-home sdm

COPY scripts/requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r /app/requirements.txt

COPY scripts/ /app/scripts/
RUN chown -R sdm:sdm /app

FROM base AS aws
RUN pip install boto3==1.35.60
USER sdm
ENTRYPOINT ["python3", "/app/scripts/mask_invoices.py"]

FROM base AS azure
RUN pip install azure-storage-blob==12.23.1 azure-identity==1.19.0
USER sdm
ENTRYPOINT ["python3", "/app/scripts/mask_invoices.py"]
