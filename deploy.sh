#!/bin/sh

set -e

LB_CONTAINER_NAME="letsencrypt"
PULLABLE_LABEL="com.centurylinklabs.watchtower.enable=true"
DEPLOY_STARTED_AT=`date +%s`

check_user() {
    if [[ -z "${USER_UID}" ]]; then
        echo "'USER_UID' has not been set in .env"
        exit -1
    fi

    if [[ -z "${USER_GID}" ]]; then
        echo "'USER_GID' has not been set in .env"
        exit -1
    fi

    if ! id "$USER_UID" &>/dev/null; then
        echo "User '$USER_UID' does not exist"
        exit -1
    fi

    if ! (id -nG "$USER_UID" | grep -qw "$USER_GID"); then
        echo "User '$USER_UID' does not belong to group '$USER_GID'"
        exit -1
    fi
}

load_env() {
    ENV_FILE="$(pwd)/.env"
    if [ ! -f "$ENV_FILE" ]; then
        echo ".env file does not exist, please create one (see .env.example)"
        exit -1
    fi

    if [ -f .env ]; then
        export $(cat "$ENV_FILE" | sed 's/#.*//g' | xargs)
    fi
}

validate_docker_changes() {
    docker-compose -f docker-compose.yml config
}

check_for_nginx_changes() {
    ! git diff --quiet HEAD HEAD^ -- "config/$LB_CONTAINER_NAME"
}

pull_latest_images() {
    if [ "$1" = "all" ]; then
        CONTAINERS=`docker ps --format '{{.Names}}' | tr '\n' ' '`
    else
        CONTAINERS=`docker ps --filter "label=$PULLABLE_LABEL" --format '{{.Names}}' | tr '\n' ' '`
    fi
    docker-compose pull $CONTAINERS
    if check_for_nginx_changes; then
        docker-compose pull "$LB_CONTAINER_NAME"
    fi
}

deploy_load_balancer_changes() {
    STARTED_TIMESTAMP=`date --date="$(docker inspect --format='{{.State.StartedAt}}' letsencrypt)" +%s`
    if check_for_nginx_changes && [ $STARTED_TIMESTAMP -lt $DEPLOY_STARTED_AT ]; then
        docker-compose restart letsencrypt
    fi
}

deploy_docker_changes() {
    docker-compose up -d --build --remove-orphans
}

cleanup_docker() {
    docker system prune -af
}

create_config_entities() {
    for entity in $(grep -E '^[- \t]+(\/etc|\.\/)' docker-compose.yml | sed -E 's/(^[- \t]+)|(:.+$)//g' | sort | uniq)
    do
        if ! [ -e "$entity" ]; then
            echo "[NEW] $entity. Creating..."
            mkdir -p "$entity"
            chown -R $USER_UID:$USER_GID "$entity"
        fi
    done
}

deploy() {
    load_env
    check_user
    validate_docker_changes
    pull_latest_images "$1"
    create_config_entities
    deploy_docker_changes
    deploy_load_balancer_changes
    cleanup_docker
}

deploy "$1"
