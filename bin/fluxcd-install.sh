#! /usr/bin/env bash

# abort on nonzero exitstatus
set -o errexit

# abort on unbound variable
set -o nounset

# don't hide errors within pipes
set -o pipefail

function main()
{
    local -r github_user=${1}; shift
    local -r github_repo=${1}; shift
    local -r github_path=${1}; shift

    local -r is_token_defined=$(env | grep GITHUB_TOKEN)
    if [[ -z "${is_token_defined}" ]]; then
        gh auth login
        gh auth status -t

        printf "\nDefine the env var:\n"
        printf "export GITHUB_TOKEN=<token>\n\n"
        printf "Then run this script again.\n"

        exit 0;
    fi

    flux bootstrap github \
    --owner="${github_user}" \
    --repository="${github_repo}" \
    --branch=main \
    --path="${github_path}" \
    --personal 
}

main "${@}"