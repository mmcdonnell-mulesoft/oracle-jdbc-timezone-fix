#!/usr/bin/env bash

# Requires connected app with the following permissions:
#     Create Applications
#     Delete Applications
#     Read   Applications
# https://help.mulesoft.com/s/article/Oracle-JDBC-timezone-region-not-found-in-CloudHub

# Client ID Variable
CID=""
# Client Secret Variable
CSECRET=""

##############################################
## GETOPT VARIABLES + ARGUMENT PARSING START##
##############################################

# Initializing other variables that will be taking in via getopt
unset -v ORGID
unset -v ENVID
unset -v APPNAME

# Arguments for script
LONG_ARGS="appname:,orgid:,environmentid:,help"
SHORT_ARGS="n:,i:,s:,o:,e:,h"

# Help Function
help()
{
    echo "Based on standards I found on the internet - MPM"
    echo "Usage: ${0}
               -n | --appname
               -o | --orgid
               -e | --environmentid
               -h | --help"
    exit 2
}

OPTS=$(getopt --options ${SHORT_ARGS} --longoptions ${LONG_ARGS} -- "$@")
eval set -- "${OPTS}"
while :
do
  case "$1" in
    -n | --appname )
        APPNAME="$2"
        shift 2
        ;;
    -o | --orgid )
        ORGID="$2"
        shift 2
        ;;
    -e | --environmentid )
        ENVID="$2"
        shift 2
        ;;
    -h | --help )
      help
      ;;
    --)
      shift;
      break
      ;;
    *)
      echo "Unexpected option: $1"
      help
      ;;
  esac
done

##############################################
## GETOPT VARIABLES + ARGUMENT PARSING END  ##
##############################################

echo "Updating App: ${APPNAME}"
echo "  Org: ${ORGID}"
echo "  Environment: ${ENVID}"

#constants
BASEURI="https://anypoint.mulesoft.com/"
TOKENURI="${BASEURI}/accounts/api/v2/oauth2/token"
MEURI="${BASEURI}/accounts/api/profile"
ORGSURI="${BASEURI}/accounts/api/organizations"
ENVIRONMENTURI="${BASEURI}/apiplatform/repository/v2/organizations/${ORGID}/environments"
DEPLOYMENTSURI="${BASEURI}/amc/application-manager/api/v2/organizations/${ORGID}/environments/${ENVID}/deployments"

echo "Getting our auth token for Client: ${CID}"
FULLTOKEN=$(curl -s -X POST -d "client_id=${CID}&client_secret=${CSECRET}&grant_type=client_credentials" ${TOKENURI})
TOKEN=$(echo ${FULLTOKEN} | jq -r .access_token)

# Get Application
# Get Deployment of a given app
echo "Looking for all deployments!"
DEPLOYMENTS=$(curl -s ${DEPLOYMENTSURI} -H "Accept: application/json" -H "Authorization: Bearer ${TOKEN}")

echo "Filtering deployments on name (${APPNAME})"
APPID=$(echo ${DEPLOYMENTS} | jq -r ".items | map(select(.name == \"${APPNAME}\")) | first | .id")
APPDEPLOYURI="${DEPLOYMENTSURI}/${APPID}"

echo "Saving the current application state"
APPSTATE=$(curl -s ${APPDEPLOYURI} -H "Accept: application/json" -H "Authorization: Bearer ${TOKEN}")

echo "Getting existing properties of ${APPNAME}"
EXISTINGPROPS=$(echo ${APPSTATE} | jq -r '.application.configuration."mule.agent.application.properties.service".properties')

echo "Adding user.timezone and oracle.jdbc.timezoneAsRegion to properties manifest"
ALTEREDPROPS=$(echo $EXISTINGPROPS | jq '. += {"user.timezone":"Etc/UTC","oracle.jdbc.timezoneAsRegion":false}')

echo "Updating ${APPNAME} with new properties now."
QUIETYOU=$(curl -s -X PATCH ${APPDEPLOYURI} -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' -H 'Accept: application/json' -d "{\"application\": {\"configuration\":{\"mule.agent.application.properties.service\":{\"properties\":${ALTEREDPROPS}}}}}")
# TODO: This is a validation to see if the last command actually succeeded.
# Honestly - it may not validate the curl as much as it validates the assignment.
# I didn't have time to test this.
if [ $? != 0 ]; then
    echo "Update failed!";
else
    echo "Update succeeded!";
fi;