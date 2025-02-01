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

    # Run Test
    sudo fio --name=write_iops --directory="${BENCHMARK_VM_TEST_PATH}" --size=10G \
    --time_based --runtime=600s --ramp_time=2s --ioengine=libaio --direct=1 \
    --verify=0 --bs=4K --iodepth=64 --rw=randwrite --group_reporting=1
}

# Throuput Test Function
throuput_io() {
    # Input Arguments


    # Run Test
    sudo fio --name=write_throughput --directory="${BENCHMARK_VM_TEST_PATH}" --numjobs=16 \
    --size=10G --time_based --runtime=60s --ramp_time=2s --ioengine=libaio \
    --direct=1 --verify=0 --bs=1M --iodepth=64 --rw=write \
    --group_reporting=1
}

# Run Several Tests
