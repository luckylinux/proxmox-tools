#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Abort on Error
set -e

# Load Configuration
# shellcheck source=./config.sh
source ${toolpath}/config.sh

# List ZVOLs
# mapfile -t zvols < <( zfs get volblocksize -t volume )

# List ZVOLs with name & values Properties in one go (possibly more difficult to handle)
# mapfile -t zvols < <( zfs get volblocksize -o "name,value" -t volume -H )

# List ZVOLs with name (grab volblocksize inside Loop)
mapfile -t zvols < <( zfs get volblocksize -o "name" -t volume -H )

# Generate Timestamp
timestamp=$(date +"%Y%m%d-%H%M%S")

# Folder where to save Information about the Original ZVOL
infofolder="${toolpath}/data/$(hostname -f)/${timestamp}"

# Create Folder if not Exist yet
mkdir -p "${infofolder}"

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

    # Define ZVOL Info Folder
    zvol_infofolder="${infofolder}/${zvol}"

    # Create Information Folder
    mkdir -p "${zvol_infofolder}"

    # Dump all Information to File
    zfs get all -t volume "${zvol}" > "${zvol_infofolder}/info.txt"

    # Check if needed to Convert
    if [[ ${volblocksize_numeric} -lt 16384 ]]
    then
        # Echo
        echo -e "\tVolume Conversion is Required"

        # Get Volume Size
        volsize=$(zfs get volsize -o "value" -t volume -H "${zvol}")

        # This corresponds to volblocksize
        # blockdev --getpbsz /dev/zvol/${zvol}

        # This usually yields 512b
        # blockdev --getss /dev/zvol/${zvol}

        # Define Temporary ZVOL Name
        zvol_old="${zvol}_${volblocksize_human}"

        # Define Source Device
        source_device="/dev/zvol/${zvol_old}"

        # Define Destination Device
        destination_device="/dev/zvol/${zvol}"

        # Check if Target Volume already Exists
        if [[ -e "${source_device}" ]]
        then
            # Echo
            echo "ERROR: Temporary Old Volume ${zvol_old} already exists at ${source_device}. Aborting !"

            # Abort
            exit 9
        fi

        # Rename ZVOL
        zfs rename -u -f "${zvol}" "${zvol_old}"

        # Create new ZVOL
        zfs create -V "${volsize}" -o volblocksize=16K "${zvol}"

        # Copy the old Data into it
        if [[ "${program_copy_blocks}" == "dd" ]]
        then
            # Use dd

            # Options conv=noerror,sync will keep going on read errors and can REALLY mess up the Result up to an entire Block Size (bs)
            # For this Reason, keep "bs" as default (512 = 512 bytes) to limit potential Damage to a Minimum
            # dd if="${source_device}" of="${destination_device}" status=progress conv=noerror,sync iflag=fullblock

            # Abort on Error but still use "sync" for padding up to "bs"
            # dd if="${source_device}" of="${destination_device}" status=progress conv=sync iflag=fullblock

            # Use "sync" IO for both Reading and Writing
            # dd if="${source_device}" of="${destination_device}" status=progress iflag=fullblock,sync oflag=sync
        elif [[ "${program_copy_blocks}" == "ddrescue" ]]
        then
            # Use ddrescue

            # First Round
            ddrescue --force --no-scrape "${source_device}" "${destination_device}" "${zvol_infofolder}/rescue.map"

            # Second Round
            ddrescue --force --idirect --retry-passes=3 --no-scrape "${source_device}" "${destination_device}" "${zvol_infofolder}/rescue.map"
        else
            # Echo
            echo "ERROR: Copy Program ${program_copy_blocks} is NOT supported to perform Block Level Copy of /dev/zvol/${zvol_old} -> /dev/zvol/${zvol}. Aborting !"

            # Abort
            exit 9
        fi
    else
        # Echo
        echo -e "\tNo Conversion Required"
    fi
done

