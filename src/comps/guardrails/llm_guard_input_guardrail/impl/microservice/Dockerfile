# Copyright (C) 2024-2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# Dockerfile for the RAG LLM Guard Input Guardrail microservice
# This Dockerfile is used to build the container image for the RAG LLM Guard Output Guardrail microservice.

FROM python:3.11-slim

# Install system packages needed for building
RUN apt-get update -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN rm -f /usr/bin/dmesg /usr/bin/base64 /usr/bin/perl

RUN useradd -m -s /bin/bash user

USER user
ENV PATH="$PATH:/home/user/.local/bin"
ENV PYTHONPATH="/home/user"

COPY ./comps/guardrails/llm_guard_input_guardrail/impl/microservice/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# Install packages required for Anonymize Scanner
RUN python -m spacy download zh_core_web_sm
RUN python -m spacy download en_core_web_sm

WORKDIR /home/user/
COPY --chown=user:user ./comps/cores ./comps/cores
COPY --chown=user:user ./comps/__init__.py ./comps/__init__.py
COPY --chown=user:user ./comps/guardrails/__init__.py ./comps/guardrails/__init__.py
COPY --chown=user:user ./comps/guardrails/llm_guard_input_guardrail/__init__.py ./comps/guardrails/llm_guard_input_guardrail/__init__.py
COPY --chown=user:user ./comps/guardrails/llm_guard_input_guardrail/utils ./comps/guardrails/llm_guard_input_guardrail/utils
COPY --chown=user:user ./comps/guardrails/llm_guard_input_guardrail/opea_llm_guard_input_guardrail_microservice.py ./comps/guardrails/llm_guard_input_guardrail/opea_llm_guard_input_guardrail_microservice.py
COPY --chown=user:user ./comps/guardrails/llm_guard_input_guardrail/impl/microservice/.env ./comps/guardrails/llm_guard_input_guardrail/.env
COPY --chown=user:user ./comps/guardrails/utils/scanners.py ./comps/guardrails/utils/scanners.py

WORKDIR /home/user/comps/guardrails/llm_guard_input_guardrail/
CMD ["python", "opea_llm_guard_input_guardrail_microservice.py"]
