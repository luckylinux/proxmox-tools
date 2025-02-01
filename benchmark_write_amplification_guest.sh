# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Abort on Error
set -e

# Load Configuration
# shellcheck source=./config.sh
source "${toolpath}/config.sh"

# Load Functions
source "${toolpath}/functions.sh"

# Generate Timestamp
timestamp=$(date +"%Y%m%d-%H%M%S")

# Folder where to save Information about the Original ZVOL
resultsfolder="${toolpath}/data/${timestamp}"

# Create Folder if not exist yet
mkdir -p "${infofolder}"

# Run Test Batch
run_test_batch
