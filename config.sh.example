#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

##################################################
############## CONVERSION OPTIONS ################
##################################################

# Program to copy Blocks (dd or ddrescue)
PROGRAM_COPY_BLOCKS="ddrescue"

##################################################
############### BENCHMARK OPTIONS ################
##################################################

# Debug Mode
if [[ ! -v BENCHMARK_DEBUG_ENABLE ]]
then
    BENCHMARK_DEBUG_ENABLE=0
fi

# Test Path
BENCHMARK_VM_TEST_PATH="/usr/src/stress-io/"

# Test Device
BENCHMARK_VM_TEST_DEVICE="/dev/disk/by-id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Timestamp
BENCHMARK_TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Folder where to save Information about the Original ZVOL
BENCHMARK_RESULTS_FOLDER="${toolpath}/data/${BENCHMARK_TIMESTAMP}"

# Log File
BENCHMARK_LOGFILE="${BENCHMARK_RESULTS_FOLDER}/debug.log"

# Guest ID
BENCHMARK_VM_ID=""

# Guest Virtual Disk
BENCHMARK_VM_VIRTUAL_DISK="rpool/data/vm-XXX-disk-Y"

# Maximum Attempts if QEMU Agent doesn't reply Immediately
# This can be useful for working around "QEMU guest agent is not running" (Error Return Code 255)
BENCHMARK_VM_MAX_ATTEMPS=10

# Default Random Block Size
BENCHMARK_VM_DEFAULT_RANDOM_BLOCK_SIZE="4K"

# Default Random Queue Depth
BENCHMARK_VM_DEFAULT_RANDOM_QUEUE_DEPTH="64"

# Default Throughput Block Size
BENCHMARK_VM_DEFAULT_THROUGHPUT_BLOCK_SIZE="1M"

# Default Throughput Queue Depth
BENCHMARK_VM_DEFAULT_THROUGHPUT_QUEUE_DEPTH="64"

# Whether to use ONE BIG FILE or LOTS OF SMALL FILES
BENCHMARK_VM_DEFAULT_RANDOM_USE_SINGLE_BIG_FILE=1

# Default Size to write to Disk for the entire Test
BENCHMARK_VM_DEFAULT_SIZE="1G"

# Groups to use with mkfs.ext4 -G
if [[ ! -v BENCHMARK_VM_MKFS_EXT4_GROUPS ]]
then
    BENCHMARK_VM_MKFS_EXT4_GROUPS=()
    BENCHMARK_VM_MKFS_EXT4_GROUPS+=("16")
    # BENCHMARK_VM_MKFS_EXT4_GROUPS+=("32")
    # BENCHMARK_VM_MKFS_EXT4_GROUPS+=("64")
    # BENCHMARK_VM_MKFS_EXT4_GROUPS+=("128")
    # BENCHMARK_VM_MKFS_EXT4_GROUPS+=("256")
    # BENCHMARK_VM_MKFS_EXT4_GROUPS+=("512")
    # BENCHMARK_VM_MKFS_EXT4_GROUPS+=("1024")
    # BENCHMARK_VM_MKFS_EXT4_GROUPS+=("2048")
    # BENCHMARK_VM_MKFS_EXT4_GROUPS+=("4096")
fi

# Random IO Testing Configuration
if [[ ! -v BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE ]]
then
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE=()
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE+=("512")
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE+=("1K")
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE+=("2K")
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE+=("4K")
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE+=("8K")
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE+=("16K")
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE+=("32K")
    BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE+=("64K")
fi

if [[ ! -v BENCHMARK_VM_FIO_RANDOM_QUEUE_DEPTH ]]
then
    BENCHMARK_VM_FIO_RANDOM_QUEUE_DEPTH=()
    BENCHMARK_VM_FIO_RANDOM_QUEUE_DEPTH+=("1")
    BENCHMARK_VM_FIO_RANDOM_QUEUE_DEPTH+=("8")
    BENCHMARK_VM_FIO_RANDOM_QUEUE_DEPTH+=("32")
fi

# Throughput IO Testing Configuration
if [[ ! -v BENCHMARK_VM_FIO_THROUGHPUT_BLOCK_SIZE ]]
then
    BENCHMARK_VM_FIO_THROUGHPUT_BLOCK_SIZE=()
    # BENCHMARK_VM_FIO_THROUGHPUT_BLOCK_SIZE+=("1M")
fi

if [[ ! -v BENCHMARK_VM_FIO_THROUGHPUT_QUEUE_DEPTH ]]
then
    BENCHMARK_VM_FIO_THROUGHPUT_QUEUE_DEPTH=()
    # BENCHMARK_VM_FIO_THROUGHPUT_QUEUE_DEPTH+=("32")
fi

# Host Devices to be Analyzed (MUST be overwritten in config.sh)
if [[ ! -v BENCHMARK_HOST_DEVICES ]]
then
    BENCHMARK_HOST_DEVICES=()
    BENCHMARK_HOST_DEVICES+=("/dev/disk/by-id/ata-XXX")
    BENCHMARK_HOST_DEVICES+=("/dev/disk/by-id/ata-YYY")
    BENCHMARK_HOST_DEVICES+=("/dev/mapper/ata-XXX_crypt")
    BENCHMARK_HOST_DEVICES+=("/dev/mapper/ata-YYY_crypt")
fi