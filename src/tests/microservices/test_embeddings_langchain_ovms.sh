#!/bin/bash
# Copyright (C) 2024-2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

# This test checks embedding microservice by sending request and verifying 200 response code and response content.
# Framework: Langchain
# Moder server: OVMS

set -xe

WORKPATH=$(dirname "$(dirname "$PWD")")
IP_ADDRESS=$(hostname -I | awk '{print $1}')

CONTAINER_NAME_BASE="test-comps-embeddings"

ENDPOINT_CONTAINER_DIR="./comps/embeddings/impl/model-server/ovms/docker"
ENDPOINT_CONTAINER_NAME="${CONTAINER_NAME_BASE}-endpoint"
ENDPOINT_IMAGE_NAME="opea/${ENDPOINT_CONTAINER_NAME}:comps"
ENDPOINT_BUILD_VENV_NAME="test-embeddings-langchain-ovms-venv"
ENDPOINT_BUILD_VENV_SRC="${WORKPATH}/tests/${ENDPOINT_BUILD_VENV_NAME}"

MICROSERVICE_API_PORT=5005
MICROSERVICE_CONTAINER_NAME="${CONTAINER_NAME_BASE}-microservice-langchain"
MICROSERVICE_IMAGE_NAME="opea/${MICROSERVICE_CONTAINER_NAME}:comps"

function test_fail() {
    echo "FAIL: ${1}" 1>&2
    test_clean
    exit 1
}

function build_docker_images() {
    cd $WORKPATH
    echo $(pwd)

    docker build -t ${ENDPOINT_IMAGE_NAME} -f comps/embeddings/impl/model-server/ovms/docker/Dockerfile comps/embeddings/impl/model-server/ovms/
    docker build --target langchain -t ${MICROSERVICE_IMAGE_NAME} -f comps/embeddings/impl/microservice/Dockerfile .
    }


function delete_build_env() {
     if [ -d "$WORKPATH/${ENDPOINT_CONTAINER_DIR}/data" ]; then
      rm -rf "$WORKPATH/${ENDPOINT_CONTAINER_DIR}/data"
    fi
}

function start_service() {
    model="BAAI/bge-large-en-v1.5"
    internal_communication_port=9000
    unset http_proxy

    cd $WORKPATH/${ENDPOINT_CONTAINER_DIR}

    docker run -d --name ${ENDPOINT_CONTAINER_NAME} \
        --runtime runc \
        -p ${internal_communication_port}:${internal_communication_port} \
        -e OVMS_MODEL_NAME=$model \
        -e HF_TOKEN=${HF_TOKEN} \
        -v ./data:/data \
        ${ENDPOINT_IMAGE_NAME}
    sleep 1m

    docker run -d --name ${MICROSERVICE_CONTAINER_NAME} \
        --runtime runc \
        -p ${MICROSERVICE_API_PORT}:6000 \
        -e http_proxy=$http_proxy \
        -e https_proxy=$https_proxy \
        -e no_proxy=$no_proxy \
        -e EMBEDDING_MODEL_NAME="${model}" \
        -e EMBEDDING_MODEL_SERVER="ovms" \
        -e EMBEDDING_CONNECTOR=langchain \
        -e EMBEDDING_MODEL_SERVER_ENDPOINT="http://${IP_ADDRESS}:${internal_communication_port}" \
        --ipc=host \
        ${MICROSERVICE_IMAGE_NAME}
    sleep 15s
}

function check_containers() {
  container_names=("${ENDPOINT_CONTAINER_NAME}" "${MICROSERVICE_CONTAINER_NAME}")
  failed_containers="false"

  for name in "${container_names[@]}"; do
    if [ "$( docker container inspect -f '{{.State.Status}}' "${name}" )" != "running" ]; then
      echo "Container '${name}' failed. Print logs:"
      docker logs "${name}"
      failed_containers="true"
    fi
  done

  if [[ "${failed_containers}" == "true" ]]; then
    test_fail "There are failed containers"
  fi
}

function validate_microservice() {
    # Command errors here are not exceptions, but handled as test fails.
    set +e

    unset http_proxy
    unset https_proxy

    http_response=$(curl \
        --write-out "HTTPSTATUS:%{http_code}" \
        http://${IP_ADDRESS}:${MICROSERVICE_API_PORT}/v1/embeddings \
        -X POST \
        -d '{"text":"What is Deep Learning?"}' \
        -H 'Content-Type: application/json' \
    )

    http_status=$(echo $http_response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    if [ "$http_status" -ne "200" ]; then
        test_fail "HTTP status is not 200. Received status was $http_status"
		fi

    http_content=$(echo "$http_response" | sed 's/HTTPSTATUS.*//')
		echo "${http_content}" | jq; parse_return_code=$?
		if [ "${parse_return_code}" -ne "0" ]; then
        test_fail "HTTP response content is not json parsable. Response content was: ${http_content}"
		fi

		set -e
}

function purge_containers() {
    cids=$(docker ps -aq --filter "name=${CONTAINER_NAME_BASE}-*")
    if [[ ! -z "$cids" ]]
    then
      docker stop $cids
      docker rm $cids
    fi
}

function remove_images() {
    # Remove images and the build cache
    iid=$(docker images \
      --filter=reference=${ENDPOINT_IMAGE_NAME} \
      --filter=reference=${MICROSERVICE_IMAGE_NAME} \
      --format "{{.ID}}" \
    )
    if [[ ! -z "$iid" ]]; then docker rmi $iid && sleep 1s; fi
}

function test_clean() {
    purge_containers
    remove_images
    delete_build_env
}

function main() {
    test_clean
    build_docker_images
    start_service
    check_containers
    validate_microservice
    test_clean
}

main
