# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Abort on Error
set -e

# Load Configuration
# shellcheck source=./config.sh
source ${toolpath}/config.sh

# Exec Function in Guest
run_command_inside_vm() {
    # Input Arguments
    local lcmd=$1

    # Run Command inside VM
    qm guest exec "${BENCHMARK_VM_ID}" --timeout 0 -- /bin/bash -c "${lcmd}"
}

# Random IO Test Function
random_io() {
    # Input Arguments
    local lbs=${1-"${BENCHMARK_VM_DEFAULT_RANDOM_BLOCK_SIZE}"}
    local lsize=${2-"${BENCHMARK_VM_DEFAULT_SIZE}"}

    # Test Command
    echo "sudo fio --name=write_iops --directory=\"${BENCHMARK_VM_TEST_PATH}\" --size=\"${lsize}\" --runtime=600s --ramp_time=2s --ioengine=libaio --direct=1 --verify=0 --bs=\"${lbs}\" --iodepth=64 --rw=randwrite --group_reporting=1"
}

# Throuput Test Function
throuput_io() {
    # Input Arguments
    local lbs=${1-"${BENCHMARK_VM_DEFAULT_RANDOM_BLOCK_SIZE}"}
    local lsize=${2-"${BENCHMARK_VM_DEFAULT_SIZE}"}

    # Test Command
    echo "sudo fio --name=write_throughput --directory=\"${BENCHMARK_VM_TEST_PATH}\" --numjobs=16 --size=\"${lsize}\" --runtime=60s --ramp_time=2s --ioengine=libaio --direct=1 --verify=0 --bs=\"${lbs}\" --iodepth=64 --rw=write --group_reporting=1"
}

# Get IO Statistics Data
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics() {
    # Input Arguments
    local ldev="$1"

    # Return Value
    if [[ -e "/sys/block/${ldev}" ]]
    then
        cat "/sys/block/${ldev}/stat"
    fi
}

# Get IO Statistics Data (Read IOs)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_ios() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   $(get_io_statistics "${ldev}") | awk '{print $1}'
}

# Get IO Statistics Data (Read Merges)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_merges() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   $(get_io_statistics "${ldev}") | awk '{print $2}'
}

# Get IO Statistics Data (Read Sectors)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_sectors() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   $(get_io_statistics "${ldev}") | awk '{print $3}'
}

# Get IO Statistics Data (Read Ticks)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_ticks() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   $(get_io_statistics "${ldev}") | awk '{print $4}'
}

# Get IO Statistics Data (Write IOs)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_ios() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   $(get_io_statistics "${ldev}") | awk '{print $5}'
}

# Get IO Statistics Data (Write Merges)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_merges() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   $(get_io_statistics "${ldev}") | awk '{print $6}'
}

# Get IO Statistics Data (Write Sectors)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_sectors() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   $(get_io_statistics "${ldev}") | awk '{print $7}'
}

# Get IO Statistics Data (Write Ticks)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_ticks() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   $(get_io_statistics "${ldev}") | awk '{print $8}'
}

# Get IO Statistics Data (Write Sectors are "standardized" 512b, indipendent of FS Block/Sector Size)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_bytes() {
   # Input Arguments
   local ldev="$1"

   # Get Number of Sectors written
   sectors=$(get_io_statistics_write_sectors "${ldev}")

   # Calculate Bytes Value
   echo "${sectors} * 512" | bc
}


# Just Analyse the first Host Device
device="${BENCHMARK_HOST_DEVICES[0]}"

# Value before Test
write_bytes_before_test=$(get_io_statistics_write_bytes "${device}")

# Run Several Tests
run_command_inside_vm $(random_io "4K")

# Value after Test
write_bytes_after_test=$(get_io_statistics_write_bytes "${device}")
