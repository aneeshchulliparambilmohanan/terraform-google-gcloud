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
    echo "Installing components ${FINAL_COMPONENT_LIST[*]}"

    su -c '
        set -e

        echo "Backing up existing APT sources..."
        cp /etc/apt/sources.list /etc/apt/sources.list.bak

        if [ -d /etc/apt/sources.list.d ]; then
            mkdir -p /etc/apt/sources.list.d.bak
            cp -r /etc/apt/sources.list.d/* /etc/apt/sources.list.d.bak/ 2>/dev/null || true
        fi

        echo "Switching to Debian archive repositories (temporary)..."
        cat > /etc/apt/sources.list <<EOF
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main
EOF

        echo "Disabling APT release expiry checks..."
        echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf.d/99no-check-valid

        echo "Updating package lists..."
        apt-get update

        echo "Installing sudo..."
        apt-get install -y sudo
    '

    echo "Verifying sudo installation..."
    whereis sudo

    echo "PATH is:"
    echo "$PATH"

    echo "Installing ASM required tools..."
    sudo apt-get update
    sudo apt-get install -y kubectl google-cloud-sdk-kpt

    su -c '
        set -e

        echo "Restoring original APT sources..."
        mv /etc/apt/sources.list.bak /etc/apt/sources.list

        if [ -d /etc/apt/sources.list.d.bak ]; then
            rm -rf /etc/apt/sources.list.d
            mv /etc/apt/sources.list.d.bak /etc/apt/sources.list.d
        fi

        echo "Removing temporary APT override..."
        rm -f /etc/apt/apt.conf.d/99no-check-valid

        echo "APT sources restored successfully."
    '

else
    echo "All components ${PROPOSED_COMPONENTS_TO_INSTALL[*]} already installed."
fi
