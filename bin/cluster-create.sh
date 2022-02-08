#! /usr/bin/env bash

# abort on nonzero exitstatus
set -o errexit

# abort on unbound variable
set -o nounset

# don't hide errors within pipes
set -o pipefail

function checkArgs()
{
  if (( $# < 2)) ; then
  
    echo "Creates a kind cluster with ingress enabled"
    echo
    echo "Usage: ${0} <name> <config-file>"
    echo "Example: ${0} k8sdev configs/kind.config"
    exit 1
  fi
}

function checkIfClusterExistsAndAbort()
{
    local -r name=${1}; shift

    local -r cluster_list=$(kind get clusters | grep "${name}")
    if [[ -n ${cluster_list} ]] ; then
      exit 0;
    fi
}

function createKindCluster()
{
    local -r name=${1}; shift
    local -r config=${1}; shift

    kind create cluster --name "${name}" --config "${config}" --wait 5m
}

function installIngress()
{
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

  kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
}

function main()
{
    checkArgs "${@}"

    local -r name=${1}; shift
    local -r config_path=${1}; shift
    
    checkIfClusterExistsAndAbort "${name}"
    createKindCluster "${name}" "${config_path}"

    installIngress
}

main "${@}"