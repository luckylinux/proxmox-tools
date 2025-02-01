#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
# shellcheck source=./config.sh
source ${toolpath}/config.sh

# List ZVOLs
# mapfile -t zvols < <( zfs get volblocksize -t volume )

# List ZVOLs with name & values Properties in one go (possibly more difficult to handle)
# mapfile -t zvols < <( zfs get volblocksize -o "name,value" -t volume -H )

# List ZVOLs with name (grab volblocksize inside Loop)
mapfile -t zvols < <( zfs get volblocksize -o "name" -t volume -H )

# Loop
for zvol in "${zvols[@]}"
do
    # Echo
    echo -e "Processing ZFS ZVOL ${zvol}"

    # Get VolBlockSize Property
    volblocksize_human=$(zfs get volblocksize -o "value" -t volume -H "${zvol}")

    # Get VolBlockSize Numeric Value
    volblocksize_numeric=$(zfs get volblocksize -p -o "value" -t volume -H "${zvol}")

    # Echo
    echo -e "\tVolume Block Size: ${volblocksize_human} (${volblocksize_numeric})"

    # Check if needed to Convert
    if [[ ${volblocksize_numeric} -lt 16384 ]]
    then
        # Echo
        echo -e "\tVolume Conversion is Required"
    else
        # Echo
        echo -e "\tNo Conversion Required"
    fi
done
