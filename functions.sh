# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
# shellcheck source=./config.sh
source "${toolpath}/config.sh"

# Repeat Character N times
repeat_character() {
   # Character to repeat
   local lcharacter=${1}

   # Number of Repetitions
   local lrepetitions=${2}

   # Print using Brace Expansion
   #for i in {1 ... ${lrepetitions}}
   for i in $(seq 1 1 ${lrepetitions})
   do
       echo -n "${lcharacter}"
   done
}

# Add Line Separator
add_separator() {
   local lcharacter=${1-"#"}
   local lrows=${2-"1"}

   # Get width of Terminal
   local lwidth=$(tput cols)

   # Repeat Character
   for r in $(seq 1 1 ${lrows})
   do
      repeat_character "${lcharacter}" "${lwidth}"
   done
}

# Add Line Separator with Description
add_section() {
   local lcharacter=${1-"#"}
   local lrows=${2-"1"}
   local ldescription=${3-""}

   # Determine number of Separators BEFORE and AFTER the Description
   #local lrowsseparatorsbefore=$(echo "${lrows-1} / ( 2 )" | bc -l)
   #local lrowsseparatorafter="${lrowsseparatorsbefore}"
   local lrowsbefore="${lrows}"
   local lrowsafter="${lrows}"

   # Add Separator
   add_separator "${lcharacter}" "${lrowsbefore}"

   # Add Header with Description
   add_description "${lcharacter}" "${ldescription}"

   # Add Separator
   add_separator "${lcharacter}" "${lrowsafter}"
}

add_description() {
   # User Inputs
   local lcharacter=${1-"#"}
   local ldescription=${2-""}

   # Add one Space before and after the original String
   ldescription=" ${ldescription} "

   # Get width of Terminal
   local lwidth=$(tput cols)

   # Get length of Description
   local llengthdescription=${#ldescription}

   # Get width of Terminal
   local lwidth=$(tput cols)

   # Subtract Description from Terminal Width
   local llengthseparator=$((lwidth - llengthdescription))

   # Divide by two
   local llengtheachseparator=$(echo "${llengthseparator} / ( 2 )" | bc -l)

   # Remainer
   local lremainer=$((llengthseparator % 2))
   local lextrastr=$(repeat_character "${lcharacter}" "${lremainer}")

   # Get String of Characters for BEFORE and AFTER the Description
   local lseparator=$(repeat_character "${lcharacter}" "${llengtheachseparator}")

   # Print Description Line
   echo "${lseparator}${ldescription}${lextrastr}${lseparator}"
}

# Exec Function in Guest
run_command_inside_vm() {
    # Input Arguments
    local lcmd="$@"

    # Run Command inside VM
    local cmd_returned_value
    cmd_returned_value=$(qm guest exec "${BENCHMARK_VM_ID}" --timeout 0 -- /bin/bash -c "${lcmd}")

    # Return Value (JSON)
    echo "${cmd_returned_value}"
}

# Init / Reset Folder
init_guest_test() {
    # Check if Variable is non-empty
    if [[ -n "${BENCHMARK_VM_TEST_PATH}" ]] && [[ "${BENCHMARK_VM_TEST_PATH}" != "/" ]]
    then
        # Remove Folder if it exists & (Re)Create Folder
        run_command_inside_vm rm -rf "${BENCHMARK_VM_TEST_PATH}"

        # (Re)Create Folder
        run_command_inside_vm mkdir -p "${BENCHMARK_VM_TEST_PATH}"
    else
        echo "ERRRO: Value of ${BENCHMARK_VM_TEST_PATH} in NOT valid !!"
        exit 9
    fi
}

# Random IO Test Function
random_io() {
    # Input Arguments
    local lbs=${1-"${BENCHMARK_VM_DEFAULT_RANDOM_BLOCK_SIZE}"}
    local lqueuedepth=${2-"${BENCHMARK_VM_DEFAULT_RANDOM_QUEUE_DEPTH}"}
    local lsize=${3-"${BENCHMARK_VM_DEFAULT_SIZE}"}

    # Test Command
    echo "sudo fio --name=write_iops --directory=\"${BENCHMARK_VM_TEST_PATH}\" --size=\"${lsize}\" --runtime=600s --ramp_time=2s --ioengine=libaio --direct=1 --verify=0 --bs=\"${lbs}\" --iodepth=\"${lqueuedepth}\" --rw=randwrite --group_reporting=1"
}

# Throuput Test Function
throughput_io() {
    # Input Arguments
    local lbs=${1-"${BENCHMARK_VM_DEFAULT_THROUGHPUT_BLOCK_SIZE}"}
    local lqueuedepth=${2-"${BENCHMARK_VM_DEFAULT_THROUGHPUT_QUEUE_DEPTH}"}
    local lsize=${3-"${BENCHMARK_VM_DEFAULT_SIZE}"}

    # Test Command
    echo "sudo fio --name=write_throughput --directory=\"${BENCHMARK_VM_TEST_PATH}\" --numjobs=16 --size=\"${lsize}\" --runtime=600s --ramp_time=2s --ioengine=libaio --direct=1 --verify=0 --bs=\"${lbs}\" --iodepth=\"${lqueuedepth}\" --rw=write --group_reporting=1"
}

# Convert Gigabytes to Bytes
convert_gigabytes_to_bytes() {
   # Input Arguments
   local lgigabytes="$1"

   # Convert gigabytes -> bytes
   local lbytes
   lbytes=$(echo "scale=3; ${lgigabytes} * ${BYTES_PER_GB}" | bc)

   # Return Value
   echo "${lbytes}" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'

}

# Convert Bytes to Gigabytes
convert_bytes_to_gigabytes() {
   # Input Arguments
   local lbytes="$1"

   # Convert bytes -> gigabytes
   local lgigabytes
   lgigabytes=$(echo "scale=3; ${lbytes} / ${BYTES_PER_GB}" | bc)

   # Return Value
   echo "${lgigabytes}" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'
}

# Get IO Statistics Data
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics() {
    # Input Arguments
    local ldev="$1"

    if [[ "${ldev}" == "/dev/disk/by-id/"* ]] || [[ "${ldev}" == "/dev/mapper/"* ]] || [[ "${ldev}" == "/dev/loop/"* ]]
    then
        # Get the simplified Name that we can look in /sys/block/<dev>/stat
        ldev=$(basename $(readlink "${ldev}"))
    fi

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
   echo $(get_io_statistics "${ldev}") | awk '{print $1}'
}

# Get IO Statistics Data (Read Merges)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_merges() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   echo $(get_io_statistics "${ldev}") | awk '{print $2}'
}

# Get IO Statistics Data (Read Sectors)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_sectors() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   echo $(get_io_statistics "${ldev}") | awk '{print $3}'
}

# Get IO Statistics Data (Read Ticks)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_ticks() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   echo $(get_io_statistics "${ldev}") | awk '{print $4}'
}

# Get IO Statistics Data (Write IOs)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_ios() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   echo $(get_io_statistics "${ldev}") | awk '{print $5}'
}

# Get IO Statistics Data (Write Merges)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_merges() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   echo $(get_io_statistics "${ldev}") | awk '{print $6}'
}

# Get IO Statistics Data (Write Sectors)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_sectors() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   echo $(get_io_statistics "${ldev}") | awk '{print $7}'
}

# Get IO Statistics Data (Write Ticks)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_ticks() {
   # Input Arguments
   local ldev="$1"

   # Return Value
   echo $(get_io_statistics "${ldev}") | awk '{print $8}'
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

# Analyze Devices
analyse_host_devices() {
   # The return Array is passed by nameref
   # Reference to output array
   declare -n lreturnarray="${1}"

   for device in "${BENCHMARK_HOST_DEVICES[@]}"
   do
       # Get Value
       write_bytes=$(get_io_statistics_write_bytes "${device}")

       # Store in Return Array
       lreturnarray+=("${write_bytes}")

       # Echo
       echo "Write Bytes for Device ${device}: ${write_bytes}"
   done
}

# Run Standard Test Batch
run_test_batch() {
    # For each Group passed on to mkfs.ext4 -G <#>
    for flex_group in "${BENCHMARK_VM_MKFS_EXT4_GROUPS[@]}"
    do
        # Echo
        # echo "Using flex_group = ${flex_group} for mkfs.ext4 -G"


        # Perform Random IO Testing
        for random_block_size in "${BENCHMARK_VM_FIO_RANDOM_BLOCK_SIZE[@]}"
        do
            # Echo
            # echo "Using random_block_size = ${random_block_size} for fio"

            for random_queue_depth in "${BENCHMARK_VM_FIO_RANDOM_QUEUE_DEPTH[@]}"
            do
                # Echo
                # echo "Using random_queue_depth = ${random_queue_depth} for fio"

                # Run Benchmark
                run_test_iteration "${flex_group}" "random" "${random_block_size}" "${random_queue_depth}"
            done

        done

        # Perform Throughput IO Testing
        for throughput_block_size in "${BENCHMARK_VM_FIO_THROUGHPUT_BLOCK_SIZE[@]}"
        do
            # Echo
            # echo "Using throughput_block_size = ${throughput_block_size} for fio"

            for throughput_queue_depth in "${BENCHMARK_VM_FIO_THROUGHPUT_QUEUE_DEPTH[@]}"
            do
                # Echo
                # echo "Using throughput_queue_depth = ${throughput_queue_depth} for fio"

                # Run Benchmark
                run_test_iteration "${flex_group}" "throughput" "${throughput_block_size}" "${throughput_queue_depth}"
            done
        done
    done
}

# Run Test Iteration
run_test_iteration() {
    # Input Arguments
    local lgroups="$1"
    local ltype="$2"
    local lblocksize="$3"
    local lqueuedepth="$4"

    # Vertical Space
    echo -e "\n\n"

    # Echo
    add_section "#" "2" "Run Test Iteration"

    echo -e ""

    echo -e "Number of Groups (Flex Groups): ${lgroups}"
    echo -e "Type of IO Test: ${ltype}"
    echo -e "Block Size of IO Test: ${lblocksize}"
    echo -e "Queue Depth of IO Test: ${lqueuedepth}"

    # Vertical Space
    echo -e "\n\n"

    # Declare write_bytes_host_before_test as a (global) array that we will pass to analyse_host_devices() by reference
    declare -a write_bytes_host_before_test

    # Analyse Host Devices before Test
    analyse_host_devices write_bytes_host_before_test

    # Vertical Space
    echo -e "\n\n"

    # Value before Test
    # write_bytes_before_test=$(get_io_statistics_write_bytes "${device}")

    # Init Test
    # (ONLY if **NOT** using a Separate Device)
    if [[ -z "${BENCHMARK_VM_TEST_DEVICE}" ]]
    then
        # Init Guest Test
        init_guest_test
    else
        # Setup Guest Device
        setup_guest_device "${flex_group}"
    fi

    # Vertical Space
    echo -e "\n\n"

    # Run Benchmark inside VM
    echo -e "Writing ${BENCHMARK_VM_DEFAULT_SIZE} inside VM"

    # Decide whether to run Random IO or Throughput IO Benchmark
    if [[ "${ltype}" == "random" ]]
    then
        # Run Benchmark and store Return Value in Variable
        cmd_string=$(random_io "${lblocksize}" "${lqueudepth}")
        cmd_return_value=$(run_command_inside_vm "${cmd_string}")
    elif [[ "${ltype}" == "throughput" ]]
    then
        # Run Benchmark and store Return Value in Variable
        cmd_string=$(throughput_io "${lblocksize}" "${lqueudepth}")
        cmd_return_value=$(run_command_inside_vm "${cmd_string}")
    else
        # Echo
        echo "ERROR: Benchmark Type ${ltype} is NOT supported. Valid Choices are: [random, thoughput]. Aborting."]

        # Abort
        exit 9
    fi

    # Vertical Space
    echo -e "\n\n"

    # Value after Test
    # write_bytes_after_test=$(get_io_statistics_write_bytes "${device}")

    # Declare write_bytes_host_before_test as a (global) array that we will pass to analyse_host_devices() by reference
    declare -a write_bytes_host_after_test

    # Analyse Host Devices after Test
    analyse_host_devices write_bytes_host_after_test

    # Vertical Space
    echo -e "\n\n"
}

# Setup Guest Device
setup_guest_device() {
    # Input Arguments

    # Flex Groups as fed to mkfs.ext4 -G <#>
    # HyperV Reccomends 4096 since the Host Block Size on NTFS is quite Big (1MB)
    local lgroups="$1"

    # Block Size
    # local lbs=${2-""}

    # Make sure to UNMOUNT the Device before starting
    run_command_inside_vm "if mountpoint -q \"${BENCHMARK_VM_TEST_PATH}\"; then umount \"${BENCHMARK_VM_TEST_PATH}\"; fi"

    # Make sure to UNMOUNT the Device before starting
    run_command_inside_vm "device_short_name=$(readlink \"${BENCHMARK_VM_TEST_DEVICE}\"); if [[ $(cat /proc/mounts | grep \"${device_short_name}\" | wc -l) -ge 1 ]]; then umount \"${BENCHMARK_VM_TEST_DEVICE}\"; fi"

    # Make Mountpoint Mutable (again)
    run_command_inside_vm "if [[ -d \"${BENCHMARK_VM_TEST_PATH}\" ]]; then chattr -i \"${BENCHMARK_VM_TEST_PATH}\"; fi"

    # Remove Mountpoint and everything in it (if present)
    run_command_inside_vm rm -rf "${BENCHMARK_VM_TEST_PATH}"

    # Create Mountpoint
    run_command_inside_vm mkdir -p "${BENCHMARK_VM_TEST_PATH}"

    # Make Mountpoint Immutable
    run_command_inside_vm chattr +i "${BENCHMARK_VM_TEST_PATH}"

    # Format Device
    run_command_inside_vm mkfs.ext4 -F -G "${lgroups}" "${BENCHMARK_VM_TEST_DEVICE}"

    # Mount Device
    run_command_inside_vm mount "${BENCHMARK_VM_TEST_DEVICE}" "${BENCHMARK_VM_TEST_PATH}"
}
