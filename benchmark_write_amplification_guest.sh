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

# Just Analyse the first Host Device
# device="${BENCHMARK_HOST_DEVICES[0]}"

