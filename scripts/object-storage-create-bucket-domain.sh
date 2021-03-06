#!/bin/bash

##############################################################################
# Copyright 2019 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################################

root_folder=$(cd $(dirname $0); pwd)

# SETUP logging (redirect stdout and stderr to a log file)
readonly LOG_FILE="${root_folder}/object-storage.log"
readonly ENV_FILE="${root_folder}/../local.env"
touch $LOG_FILE
exec 3>&1 # Save stdout
exec 4>&2 # Save stderr
exec 1>$LOG_FILE 2>&1

function _out() {
  echo "$@" >&3
  echo "$(date +'%F %H:%M:%S') $@"
}

function _err() {
  echo "$@" >&4
  echo "$(date +'%F %H:%M:%S') $@"
}

function check_tools() {
    MISSING_TOOLS=""
    git --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} git"
    curl --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} curl"
    vue --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} vue"
    ibmcloud --version &> /dev/null || MISSING_TOOLS="${MISSING_TOOLS} ibmcloud"    
    if [[ -n "$MISSING_TOOLS" ]]; then
      _err "Some tools (${MISSING_TOOLS# }) could not be found, please install them first"
      exit 1
    fi
}

function ibmcloud_login() {
  # Skip version check updates
  ibmcloud config --check-version=false

  # Obtain the API endpoint from BLUEMIX_REGION and set it as default
  _out Logging in to IBM cloud
  ibmcloud api --unset
  #IBMCLOUD_API_ENDPOINT=$(ibmcloud api | awk '/'$BLUEMIX_REGION'/{ print $2 }')
  ibmcloud api https://cloud.ibm.com

  # Login to ibmcloud, generate .wskprops
  ibmcloud login --apikey $IBMCLOUD_API_KEY -r $BLUEMIX_REGION
  ibmcloud target -o "$IBMCLOUD_ORG" -s "$IBMCLOUD_SPACE"
  ibmcloud fn api list > /dev/null

  # Show the result of login to stdout
  ibmcloud target
}

function setup() {
  _out Creating bucket
  IAM_TOKEN=$(ibmcloud iam oauth-tokens | awk '/IAM/{ print $4 }')

  CLOUD_ORG="${IBMCLOUD_ORG//@}"
  CLOUD_ORG="${CLOUD_ORG//_}"
  CLOUD_ORG="${CLOUD_ORG//.}"
  BUCKET_NAME_CUSTOM_DOMAIN="emotions-demo-domain-${CLOUD_ORG}"
  _out BUCKET_NAME_CUSTOM_DOMAIN: $BUCKET_NAME_CUSTOM_DOMAIN
  printf "\nBUCKET_NAME_CUSTOM_DOMAIN=$BUCKET_NAME_CUSTOM_DOMAIN" >> $ENV_FILE
  curl -X "PUT" "https://s3.us-south.objectstorage.softlayer.net/${BUCKET_NAME_CUSTOM_DOMAIN}" \
    -H "Authorization: Bearer ${IAM_TOKEN}" \
    -H "ibm-service-instance-id: ${COS_ID}"

  #curl -X "PUT" "https://s3.us-south.objectstorage.softlayer.net/${BUCKET_NAME_CUSTOM_DOMAIN}?cors=" \
  #  -H "Authorization: Bearer ${IAM_TOKEN}" \
  #  -H "ibm-service-instance-id: ${COS_ID}"

  _out Bucket ${BUCKET_NAME_CUSTOM_DOMAIN} has been created
}

# Main script starts here
check_tools

# Load configuration variables
if [ ! -f $ENV_FILE ]; then
  _err "Before deploying, copy template.local.env into local.env and fill in environment specific values."
  exit 1
fi
source $ENV_FILE
export IBMCLOUD_ORG IBMCLOUD_API_KEY BLUEMIX_REGION APPID_TENANTID APPID_OAUTHURL APPID_CLIENTID APPID_SECRET CLOUDANT_USERNAME CLOUDANT_PASSWORD IBMCLOUD_SPACE COS_ID

_out Full install output in $LOG_FILE
ibmcloud_login
setup
