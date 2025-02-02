#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Abort on Error
set -e

# Load Configuration
# shellcheck source=./config.sh
source "${toolpath}/config.sh"

# Load Functions
# shellcheck source=./functions.sh
source "${toolpath}/functions.sh"

# Create Results Folder if not exist yet
mkdir -p "${BENCHMARK_RESULTS_FOLDER}"

# Run Test Batch
run_test_batch
