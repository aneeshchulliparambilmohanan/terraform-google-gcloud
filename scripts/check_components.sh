#!/usr/bin/env bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

if [ "$#" -lt 2 ]; then
    >&2 echo "Not all expected arguments set."
    exit 1
fi

GCLOUD_PATH=$1
PROPOSED_COMPONENTS_TO_INSTALL=$2

# get list of currently installed components
CURRENTLY_INSTALLED=$($GCLOUD_PATH components list --quiet --filter='state.name!="Not Installed"' --format="csv[no-heading,terminator=','](id)" 2> /dev/null)
# this creates a trailing comma that needs to be removed
CURRENTLY_INSTALLED=${CURRENTLY_INSTALLED%?}
# transform to arrays
IFS=',' read -r -a CURRENTLY_INSTALLED <<< "$CURRENTLY_INSTALLED"
IFS=',' read -r -a PROPOSED_COMPONENTS_TO_INSTALL <<< "$PROPOSED_COMPONENTS_TO_INSTALL"

echo "Currently installed: $CURRENTLY_INSTALLED "

#get diff btw components already installed and those that need to be installed
FILTER_COMPONENT_LIST=()
for component in "${PROPOSED_COMPONENTS_TO_INSTALL[@]}"
do
    if [[ ! ${CURRENTLY_INSTALLED[*]} =~ $component ]]; then
        FILTER_COMPONENT_LIST+=("$component")
    else
        echo "Found $component via gcloud component manager";
    fi
done

# check if any component exists as a binary
FINAL_COMPONENT_LIST=()
for component in "${FILTER_COMPONENT_LIST[@]}"
do
    if [[ $(command -v "$component") ]]; then
        echo "Found $component via $(command -v "$component")";
    else
        FINAL_COMPONENT_LIST+=("$component")
    fi
done


# if there is any component left in list, install via gcloud
if [[ ${FINAL_COMPONENT_LIST[*]} ]]; then
    echo "Installing components ${FINAL_COMPONENT_LIST[*]}";
    #$GCLOUD_PATH components install "${FINAL_COMPONENT_LIST[@]}" --quiet
    # su -c 'apt-get install sudo'
    # whereis sudo
    # echo "path is :"
    # echo $PATH
    # sudo apt-get install kubectl google-cloud-sdk-kpt
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    chmod 644 /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubectl

    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    apt-get update
    apt-get install -y google-cloud-sdk-kpt
    #apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
    #apt-get install -y jq
else
    echo "All components ${PROPOSED_COMPONENTS_TO_INSTALL[*]} already installed."
fi
