#!/bin/bash

################################################################
# Azure DevOps
# Script to approve releases requiring manual approval
# Uses Azure API
# Requires release id, organisation, and project as parameters.
# Token can be provided by System.AccessToken
################################################################

function usage {
  cat <<EOF
    approval.sh <-t token> <-o organisation> <-p project> <-r release id>

    -t Azure Personal Access Token
    -o Organisation Name
    -p Project Name
    -r Release ID

EOF
}

while getopts "t:o:p:r:" flag; do
case "$flag" in
    t) export AZURE_PAT="${OPTARG}";;
    o) export AZURE_ORG="${OPTARG}";;
    p) export AZURE_PROJECT="${OPTARG}";;
    r) export RELEASE_ID="${OPTARG}";;
    *) echo "Error: Flag is not recognised" && usage && exit 1;;
esac
done

if [ -z "${AZURE_PAT}" ]; then
    echo "AZURE_PAT - Variable has not been set"
    usage
    exit 1
elif [ -z "${RELEASE_ID}" ]; then
    echo "RELEASE_ID - Variable has not been set"
    usage
    exit 1
elif [ -z "${AZURE_PROJECT}" ]; then
    echo "AZURE_PROJECT - Variable has not been set"
    usage
    exit 1
elif [ -z "${AZURE_ORG}" ]; then
    echo "AZURE_ORG - Variable has not been set"
    usage
    exit 1
fi

APPROVALS_LIST=$(curl -u ":${AZURE_PAT}" "https://vsrm.dev.azure.com/${AZURE_ORG}/${AZURE_PROJECT}/_apis/release/approvals?api-version=6.0")

if [ -z "${APPROVALS_LIST}" ] || echo "${APPROVALS_LIST}" | jq > /dev/null 2>&1; then
    APPROVAL_ID=$(echo "${APPROVALS_LIST}" | jq '.value[] | select(.release.id=='"${RELEASE_ID}"') | .id')
    if [ -n "${APPROVAL_ID}" ]; then
        echo "Approval ID found: ${APPROVAL_ID}"
        if curl --header "Content-Type: application/json" --data '{"status": "approved","comments": "ServiceNow request has been approved."}' -u ":${AZURE_PAT}" --request PATCH "https://vsrm.dev.azure.com/${AZURE_ORG}/${AZURE_PROJECT}/_apis/release/approvals/${APPROVAL_ID}?api-version=6.0" | grep "approvedBy" > /dev/null 2>&1; then
            echo "Successfully approved release to production."
        else
            echo "Failed to approve release to production."
        fi
    else
        echo "Approval ID not found"
    fi
else
    echo -e "\nFailed to fetch approvals list.\n\nError: \n${APPROVALS_LIST}"
fi