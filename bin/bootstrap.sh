#! /usr/bin/env bash

# abort on nonzero exitstatus
set -o errexit

# abort on unbound variable
set -o nounset

# don't hide errors within pipes
set -o pipefail

function main()
{
    echo "To run this script you need the following CLIs installed:"
    echo "- kubectl"
    echo "- kind - kind cluster CLI"
    echo "- flux - FluxCD to sync the helm charts of Vault"
    echo "- gh - github CLI to authenticate with the GitHub repo"
    echo "- vault (optional - only needed if you want to interact with Hashicorp Vault outside the cluster"
    echo ""
    echo "You also need to specify your fluxcd github repo which you can fork based from this URL:"
    echo "https://github.com/deeproute/localdev"
    echo ""
    echo "Furthermore, if you want to use your vault outside your cluster you need to perform the following changes:"
    echo "- In /etc/hosts - add the domain you wish to use pointing to localhost IP"
    echo "- In your forked github repo - change this host to the one specified previously: https://github.com/deeproute/localdev/blob/main/clusters/kind/overlays/infrastructure/vault-server/values.yaml#L29"
    echo "- export VAULT_ADDR=http://your-vault-domain"
    echo "- export VAULT_TOKEN=<get the root token from vault_cred.json file>"
    echo ""
    read -r -p "Press enter to continue"

    local -r cluster_name="kind-vault-csi"
    local -r cluster_config="configs/kind.config"
    local -r github_user="deeproute"
    local -r github_repo="vault-ha-raft-csi-fluxcd"
    local -r github_path="../fluxcd/clusters/kind"
    local -r namespace_vault="vault-server"

    echo ""
    echo "The bootstrap has the below defined vars. Change to your needs."
    echo "Kind Cluster Name: ${cluster_name}"
    echo "Kind Cluster Config: ${cluster_config}"
    echo "GitHub User/Owner: ${github_user}"
    echo "GitHub Repo: ${github_repo}"
    echo "GitHub Path: ${github_path}"
    echo "Namespace where Vault Server will be installed: ${namespace_vault}"
    echo ""

    read -r -p "Press enter to continue or CTRL+C to abort to change the vars."

    ./cluster-create.sh "${cluster_name}" "${cluster_config}"

    ./fluxcd-install.sh "${github_user}" "${github_repo}" "${github_path}"
    
    echo "Waiting for Vault pods to be ready.."
    sleep 1m

    ./vault-init.sh "${namespace_vault}"

    echo "Vault Credentials:"
    cat "vault_cred.json"
}

main "${@}"
