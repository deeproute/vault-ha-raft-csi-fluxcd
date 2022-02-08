#! /usr/bin/env bash

# abort on nonzero exitstatus
set -o errexit

# abort on unbound variable
set -o nounset

# don't hide errors within pipes
set -o pipefail

function checkArgs()
{
  if (( $# < 1)) ; then
  
    echo "Script that initializes Hashicorp Vault in k8s"
    echo
    echo "Usage: ${0} <namespace>"
    echo "Example: ${0} vault-namespace"
    exit 1
  fi
}

function initVaultLeader()
{
    local -r namespace=${1}; shift
    local -r pod_name=${1}; shift

    kubectl exec -n "${namespace}" "${pod_name}" -- vault operator init --format=json > vault_cred.json

    unsealVaultPod "${namespace}" "${pod_name}"
}

function getLeaderAddress()
{
    local -r namespace=${1}; shift
    local -r pod_name=${1}; shift
    local -r scheme=${1}; shift
    local -r port=${1}; shift

    # Get Leader address
    local -r vault_token=$(jq -c '.root_token' vault_cred.json)
    local cmd_unseal="export VAULT_SKIP_VERIFY=1 && \
            export VAULT_TOKEN=${vault_token}"

    
    kubectl exec -n "${namespace}" "${pod_name}" -- /bin/sh -c "export VAULT_SKIP_VERIFY=1 && \
            export VAULT_TOKEN=${vault_token} && \
            vault operator raft list-peers --format=json" > list-peers.json

    local -r tmp_address=$(jq -r '.data.config.servers[] | select(.leader="true") | .address | split(":")[0]' list-peers.json)
    
    echo "${scheme}://${tmp_address}:${port}"
}

function joinVaultLeader()
{
    local -r namespace=${1}; shift
    local -r pod_name=${1}; shift
    local -r leader_address=${1}; shift

    kubectl exec -n "${namespace}" "${pod_name}" -- vault operator raft join "${leader_address}"
}

function unsealVaultPod()
{
    local -r namespace=${1}; shift
    local -r pod_name=${1}; shift

    local -r vault_token=$(jq -c '.root_token' vault_cred.json)
    local -r vault_key_threshold=$(jq -c '.recovery_keys_threshold' vault_cred.json)
    readarray -t vault_keys < <(jq -r '.unseal_keys_hex[]' vault_cred.json)

    local cmd_unseal="export VAULT_SKIP_VERIFY=1 && \
            export VAULT_TOKEN=${vault_token}"

    for i in $(seq 1 "${vault_key_threshold}"); do
        unlock_key="${vault_keys[$i]}"
        
        cmd_unseal="${cmd_unseal} && \
            vault operator unseal ${unlock_key}"
        
    done

    cmd_unseal="${cmd_unseal} && \
            unset VAULT_TOKEN"

    kubectl -n "${namespace}" exec "${pod_name}" -- /bin/sh -c "${cmd_unseal}" 1>/dev/null
}

function main()
{
    checkArgs "${@}"

    local -r namespace=${1}; shift
    local -r vault_pod_label="app.kubernetes.io/instance=vault-server"

    readarray -t vault_pods < <(kubectl -n "${namespace}" get pods -l "${vault_pod_label}" -oname | cut -d/ -f2)

    local -r vault_leader="${vault_pods[0]}"
    printf "\nInitializing Vault Leader %s ..\n" "${vault_leader}"

    initVaultLeader "${namespace}" "${vault_leader}"

    sleep 10s

    local -r leader_address=$(getLeaderAddress "${namespace}" "${vault_leader}" "http" "8200")
    
    local -r num_pods=$((${#vault_pods[@]} - 1))
    for i in $(seq 1 "${num_pods}"); do

        local vault_pod="${vault_pods[$i]}"
        printf "\nInitializing Vault Replica %s ..\n" "${vault_pod}"

        joinVaultLeader "${namespace}" "${vault_pod}" "${leader_address}"
        unsealVaultPod "${namespace}" "${vault_pod}"
    done
}

main "${@}"
