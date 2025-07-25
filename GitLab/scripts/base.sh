#!/bin/bash

BUILD_ID="runner-$CUSTOM_ENV_CI_RUNNER_ID-project-$CUSTOM_ENV_CI_PROJECT_ID-concurrent-$CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID"
export CONNECTION_INFO_ID=$BUILD_ID-connection-info

export ORKA_TOKEN=${ORKA_TOKEN:-${CUSTOM_ENV_ORKA_TOKEN:-}}
export ORKA_ENDPOINT=${ORKA_ENDPOINT:-${CUSTOM_ENV_ORKA_ENDPOINT:-}}
export ORKA_CONFIG_NAME=${ORKA_CONFIG_NAME:-${CUSTOM_ENV_ORKA_CONFIG_NAME:-}}
export ORKA_VM_NAME_PREFIX=${ORKA_VM_NAME_PREFIX:-${CUSTOM_ENV_ORKA_VM_NAME_PREFIX:-gl-runner}}
export ORKA_VM_USER=${ORKA_VM_USER:-${CUSTOM_ENV_ORKA_VM_USER:-admin}}
ORKA_SSH_KEY_FILE=${CUSTOM_ENV_ORKA_SSH_KEY_FILE:-}

mkdir -p ~/.ssh
echo "$ORKA_SSH_KEY_FILE" > ~/.ssh/orka_deployment_key
chmod 600 ~/.ssh/orka_deployment_key
ORKA_SSH_KEY_FILE=~/.ssh/orka_deployment_key

SETTINGS_FILE='/var/custom-executor/settings.json'

function generate_random_suffix {
    local chars="abcdefghijklmnopqrstuvwxyz0123456789"
    local random_suffix=""
    for i in {1..5}; do
        random_suffix+="${chars:$((RANDOM % ${#chars})):1}"
    done
    echo "$random_suffix"
}

function generate_vm_name {
    local random_suffix
    random_suffix=$(generate_random_suffix)
    echo "${ORKA_VM_NAME_PREFIX}-${random_suffix}"
}

function valid_ip {
    local ip=${1-}
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.' read -ra ip <<< "$ip"
        IFS=$OIFS

        if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]; then
            return 0
        fi
    fi
    return 255
}

function system_failure {
    if [ $? -eq 28 ]; then
        echo "Curl operation timed out. Exiting..."
    fi
    exit "$SYSTEM_FAILURE_EXIT_CODE"
}

function map_ip {
    local current_ip=${1}
    local result=$current_ip
    if [[ -f "$SETTINGS_FILE" ]]; then
        mappings=("$(jq -r '.mappings[] | .private_host, .public_host' "$SETTINGS_FILE")")
        for ((i = 0; i < ${#mappings[@]}; i+=2)); do
            if [[ "$current_ip" == "${mappings[$i]}" ]]; then
                result=${mappings[$((i + 1))]}
                break
            fi
        done
    fi
    echo "$result"
    return 0
}
