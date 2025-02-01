# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Load Configuration
# shellcheck source=./config.sh
source "${toolpath}/config.sh"

# Load Constants
# shellcheck source=./constants.sh
source "${toolpath}/constants.sh"

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
    # cmd_returned_value=$(qm guest exec "${BENCHMARK_VM_ID}" --timeout 0 -- /bin/bash -c "${lcmd} > /dev/null 2>&1")
    # cmd_returned_value=$(qm guest exec "${BENCHMARK_VM_ID}" --timeout 0 -- /bin/bash -c "${lcmd}" > /dev/null 2>&1)
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
    local lblocksize=${1-"${BENCHMARK_VM_DEFAULT_RANDOM_BLOCK_SIZE}"}
    local lqueuedepth=${2-"${BENCHMARK_VM_DEFAULT_RANDOM_QUEUE_DEPTH}"}

    # Constant
    local lsize="${BENCHMARK_VM_DEFAULT_SIZE}"

    # Test Command
    echo "sudo fio --name=write_iops --directory=\"${BENCHMARK_VM_TEST_PATH}\" --size=\"${lsize}\" --runtime=600s --ramp_time=2s --ioengine=libaio --direct=1 --verify=0 --bs=\"${lblocksize}\" --iodepth=\"${lqueuedepth}\" --rw=randwrite --group_reporting=1"
}

# Throuput Test Function
throughput_io() {
    # Input Arguments
    local lblocksize=${1-"${BENCHMARK_VM_DEFAULT_THROUGHPUT_BLOCK_SIZE}"}
    local lqueuedepth=${2-"${BENCHMARK_VM_DEFAULT_THROUGHPUT_QUEUE_DEPTH}"}

    # Constant
    local lsize="${BENCHMARK_VM_DEFAULT_SIZE}"

    # Test Command
    echo "sudo fio --name=write_throughput --directory=\"${BENCHMARK_VM_TEST_PATH}\" --numjobs=16 --size=\"${lsize}\" --runtime=600s --ramp_time=2s --ioengine=libaio --direct=1 --verify=0 --bs=\"${lblocksize}\" --iodepth=\"${lqueuedepth}\" --rw=write --group_reporting=1"
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

# Get Smartctl LBA Written Bytes Data
get_smart_written_bytes() {
   # Input Arguments
   local ldev="$1"

   # Declare Local Variables
   local lattributes
   local linformation
   local lbas_written
   local lba_size

   # Check if it's a Physical Device
   if [[ "${ldev}" == "/dev/disk/by-id/"* ]]
   then
       # Read all Attributes
       lattributes=$(smartctl -A "${ldev}")

       # Read all Information
       linformation=$(smartctl -a "${ldev}")

       # Get Written LBAs
       lbas_written=$(echo "${lattributes}" | grep -E "Total_LBAs_Written" | awk '{print $10}')

       # Get Sector Size
       lba_size=$(echo "${linformation}" | grep "Sector Sizes" | sed -E "s|Sector Sizes:\s*?([0-9]+) bytes logical, ([0-9]+) bytes physical|\1|g")

       # Debug
       # echo "Attributes: ${lattributes}"
       # echo "Information: ${linformation}"
       # echo "LBAS Written: ${lbas_written}"
       # echo "LBA Size: ${lba_size}"

       # Convert LBAs -> bytes
       bytes_written=$(echo "${lbas_written} * ${lba_size}" | bc)

       # Convert into bigger Units
       # megabytes_written=$(echo "scale=3; ${bytes_written} / ${BYTES_PER_MB}" | bc)
       # gigabytes_written=$(echo "scale=3; ${bytes_written} / ${BYTES_PER_GB}" | bc)
       # terabytes_written=$(echo "scale=3; ${bytes_written} / ${BYTES_PER_TB}" | bc)

       # Return Value
       echo "${bytes_written}"
   else
       # Return dummy Value to be processed later
       echo "-1"
   fi
}

# Get IO Statistics Data
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics() {
    # Input Arguments
    local ldev="$1"
    local lmode=${2-"local"}

    # Declare Variables
    local lcmd_string
    local lcmd_return_value

    if [[ "${lmode}" == "local" ]]
    then
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
    elif [[ "${lmode}" == "remote" ]]
    then
       # Define Command String to run in VM
       # lcmd_string="ldev=$(basename $(readlink --canonicalize \"\${ldev}\"); if [[ -e \"/sys/block/${ldev}\" ]]; then cat \"/sys/block/${ldev}/stat\"); fi"
       lcmd_string="ldev=\"${ldev}\"; if [[ -L \"\${ldev}\" ]]; then ldev=\$(basename \$(readlink --canonicalize \"\${ldev}\")); fi; if [[ -e \"/sys/block/\${ldev}\" ]]; then cat \"/sys/block/\${ldev}/stat\"; fi"

       # Echo
       # echo "Run Command inside VM: ${lcmd_string}"

       # Run Command in VM
       lcmd_return_value=$(run_command_inside_vm "${lcmd_string}")

       # Echo
       # echo "Run Command on Host: echo ${lcmd_return_value} | jq -r '.\"out-data\"'"

       # Return Result from Inside
       echo ${lcmd_return_value} | jq -r '."out-data"'
    else
        # Echo
        echo "ERROR: Mode ${lmode} is NOT supported. Mode must be one of: [local,remote]. Aborting"

        # Abort
        exit 9
    fi
}

# Get IO Statistics Data (Read IOs)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_ios() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Return Value
   echo $(get_io_statistics "${ldev}" "${lmode}") | awk '{print $1}'
}

# Get IO Statistics Data (Read Merges)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_merges() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Return Value
   echo $(get_io_statistics "${ldev}" "${lmode}") | awk '{print $2}'
}

# Get IO Statistics Data (Read Sectors)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_sectors() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Return Value
   echo $(get_io_statistics "${ldev}" "${lmode}") | awk '{print $3}'
}

# Get IO Statistics Data (Read Ticks)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_read_ticks() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Return Value
   echo $(get_io_statistics "${ldev}" "${lmode}") | awk '{print $4}'
}

# Get IO Statistics Data (Write IOs)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_ios() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Return Value
   echo $(get_io_statistics "${ldev}" "${lmode}") | awk '{print $5}'
}

# Get IO Statistics Data (Write Merges)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_merges() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Return Value
   echo $(get_io_statistics "${ldev}" "${lmode}") | awk '{print $6}'
}

# Get IO Statistics Data (Write Sectors)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_sectors() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Return Value
   echo $(get_io_statistics "${ldev}" "${lmode}") | awk '{print $7}'
}

# Get IO Statistics Data (Write Ticks)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_ticks() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Return Value
   echo $(get_io_statistics "${ldev}" "${lmode}") | awk '{print $8}'
}

# Get IO Statistics Data (Write Sectors are "standardized" 512b, indipendent of FS Block/Sector Size)
# https://www.kernel.org/doc/Documentation/block/stat.txt
get_io_statistics_write_bytes() {
   # Input Arguments
   local ldev="$1"
   local lmode=${2-"local"}

   # Get Number of Sectors written
   sectors=$(get_io_statistics_write_sectors "${ldev}" "${lmode}")

   # Calculate Bytes Value
   echo "${sectors} * 512" | bc
}

# Analyze Host Device
analyse_host_devices() {
   # The return Array is passed by nameref
   # Reference to output array
   declare -n lreturnarray_stat="${1}"
   declare -n lreturnarray_smart="${1}"

   # Echo
   echo "Analyse Host Devices"

   for device in "${BENCHMARK_HOST_DEVICES[@]}"
   do
       # Get Value using Linux Kernel Statistics
       write_bytes_stat=$(get_io_statistics_write_bytes "${device}" "local")

       # Convert to gigabytes
       write_gigabytes_stat=$(convert_bytes_to_gigabytes "${write_bytes_stat}")

       # Get Value using Smartmontools
       write_bytes_smart=$(get_smart_written_bytes "${device}")

       # If Data is not available, put the same Data as <stat>
       if [[ ${write_bytes_smart} -lt 0 ]]
       then
           # Echo
           echo -e "\tWARNING: SMART Data for ${device} is NOT Valid (${write_bytes_smart})"
           echo -e "\ŧWARNING: Setting write_bytes_smart=\${write_bytes_stat}=${write_bytes_stat} (using the same data as <stat>)"

           # Use the same Value as <stat>
           write_bytes_smart="${write_bytes_stat}"
       fi

       # Convert to gigabytes
       write_gigabytes_smart=$(convert_bytes_to_gigabytes "${write_bytes_smart}")

       # Select which Value to use
       # write_bytes="${write_bytes_stat}"

       # Store in Return Array
       lreturnarray_stat+=("${write_bytes_stat}")
       lreturnarray_smart+=("${write_bytes_smart}")

       # Echo
       echo "[HOST] Write Bytes for Device using Linux Kernel Statistics for ${device}: ${write_bytes_stat} B (${write_gigabytes_stat} GB)"

       # Echo
       echo "[HOST] Write Bytes for Device using smartmontools for ${device}: ${write_bytes_smart} B (${write_gigabytes_smart} GB)"
   done
}

# Analyze Guest Device
analyse_guest_device() {
   # The return Array is passed by nameref
   # Reference to output array
   declare -n lreturnarray="${1}"

   # Declare local Variables
   local lcmd_string

   # Echo
   echo "Analyse Guest Device"

   # Define Device
   local ldevice="${BENCHMARK_VM_TEST_DEVICE}"

   #for device in "${BENCHMARK_VM_TEST_DEVICE[@]}"
   #do
       # Test Standalone Command to see what's happening
       # get_io_statistics "${ldevice}" "remote"

       # Get Value (get_io_statistics_write_bytes already runs the command inside the VM if desired)
       write_bytes=$(get_io_statistics_write_bytes "${ldevice}" "remote")

       # Convert to gigabytes
       write_gigabytes=$(convert_bytes_to_gigabytes "${write_bytes}")

       # Store in Return Array
       lreturnarray+=("${write_bytes}")

       # Echo
       echo "[GUEST] Write Bytes for Device ${device}: ${write_bytes} B (${write_gigabytes} GB)"
   #done
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
    declare -a write_bytes_stat_host_before_test
    declare -a write_bytes_smart_host_before_test
    declare -a write_bytes_guest_before_test

    # Analyse Guest Devices before Test
    analyse_guest_device write_bytes_guest_before_test

    # Vertical Space
    echo -e "\n"

    # Analyse Host Devices before Test
    analyse_host_devices write_bytes_host_stat_before_test write_bytes_smart_host_before_test

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
        cmd_string=$(random_io "${lblocksize}" "${lqueuedepth}")
        echo "Running Command String: ${cmd_string}"
        # run_command_inside_vm "${cmd_string}"
        cmd_return_value=$(run_command_inside_vm "${cmd_string}")
    elif [[ "${ltype}" == "throughput" ]]
    then
        # Run Benchmark and store Return Value in Variable
        cmd_string=$(throughput_io "${lblocksize}" "${lqueuedepth}")
        echo "Running Command String: ${cmd_string}"
        # run_command_inside_vm "${cmd_string}"
        cmd_return_value=$(run_command_inside_vm "${cmd_string}")
    else
        # Echo
        echo "ERROR: Benchmark Type ${ltype} is NOT supported. Valid Choices are: [random, thoughput]. Aborting."]

        # Abort
        exit 9
    fi

    # Flush Writes
    cmd_return_value=$(run_command_inside_vm "sync")

    # Vertical Space
    echo -e "\n\n"

    # Value after Test
    # write_bytes_after_test=$(get_io_statistics_write_bytes "${device}")

    # Declare write_bytes_host_before_test as a (global) array that we will pass to analyse_host_devices() by reference
    declare -a write_bytes_stat_host_after_test
    declare -a write_bytes_smart_host_after_test
    declare -a write_bytes_guest_after_test

    # Analyse Host Devices after Test
    analyse_host_devices write_bytes_stat_host_after_test write_bytes_smart_host_after_test

    # Vertical Space
    echo -e "\n"

    # Analyze Guest Device after Test
    analyse_guest_device write_bytes_guest_after_test

    # Vertical Space
    echo -e "\n"

    # Calculate Difference on Guest

    # Before
    before_value_guest=${write_bytes_guest_before_test[0]}

    # After
    after_value_guest=${write_bytes_guest_after_test[0]}

    # Delta
    delta_value_guest=$((${after_value_guest} - ${before_value_guest}))


    # Calculate Difference on Host
    number_items=${#write_bytes_stat_host_after_test[@]}
    for index in $(seq 0 $((${number_items}-1)))
    do
        # Host Device
        device_host="${BENCHMARK_HOST_DEVICES[$index]}"

        # Before (stat)
        before_value_stat_host=${write_bytes_stat_host_before_test[${index}]}

        # After (stat)
        after_value_stat_host=${write_bytes_stat_host_after_test[${index}]}

        # Delta (stat)
        delta_value_stat_host=$((${after_value_stat_host} - ${before_value_stat_host}))

        # Calculate Write Amplification (stat)
        write_amplification_factor_stat=$(echo "scale=3; ${delta_value_stat_host} / ${delta_value_guest}" | bc)


        # Before (smart)
        before_value_smart_host=${write_bytes_smart_host_before_test[${index}]}

        # After (stat)
        after_value_smart_host=${write_bytes_smart_host_after_test[${index}]}

        # Delta (stat)
        delta_value_smart_host=$((${after_value_smart_host} - ${before_value_smart_host}))

        # Calculate Write Amplification (smart)
        write_amplification_factor_smart=$(echo "scale=3; ${delta_value_smart_host} / ${delta_value_guest}" | bc)


        # Echo
        echo -e "Write Amplification from GUEST to HOST [${device_host}] using stat: ${write_amplification_factor_stat}"
        echo -e "\tValue before Benchmark on HOST [${device_host}]: ${before_value_stat_host} B ($(convert_gigabytes_to_bytes ${before_value_stat_host}) GB)"
        echo -e "\tValue after Benchmark on HOST [${device_host}]: ${after_value_stat_host} B ($(convert_gigabytes_to_bytes ${after_value_stat_host}) GB))"
        echo -e "\tValue difference Benchmark on HOST [${device_host}]: ${delta_value_stat_host} B ($(convert_gigabytes_to_bytes ${delta_value_stat_host}) GB))"

        # Echo
        echo -e "Write Amplification from GUEST to HOST [${device_host}] using smartmontools: ${write_amplification_factor_smart}"
        echo -e "\tValue before Benchmark on HOST [${device_host}]: ${before_value_smart_host} B ($(convert_gigabytes_to_bytes ${before_value_smart_host}) GB)"
        echo -e "\tValue after Benchmark on HOST [${device_host}]: ${after_value_smart_host} B ($(convert_gigabytes_to_bytes ${after_value_smart_host}) GB))"
        echo -e "\tValue difference Benchmark on HOST [${device_host}]: ${delta_value_smart_host} B ($(convert_gigabytes_to_bytes ${delta_value_smart_host}) GB))"
    done

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
    # local lblocksize=${2-""}

    # Make sure to UNMOUNT the Device before starting
    run_command_inside_vm "if mountpoint -q \"${BENCHMARK_VM_TEST_PATH}\"; then umount \"${BENCHMARK_VM_TEST_PATH}\"; fi" > /dev/null 2>&1

    # Make sure to UNMOUNT the Device before starting
    run_command_inside_vm "device_short_name=$(readlink \"${BENCHMARK_VM_TEST_DEVICE}\"); if [[ $(cat /proc/mounts | grep \"${device_short_name}\" | wc -l) -ge 1 ]]; then umount \"${BENCHMARK_VM_TEST_DEVICE}\"; fi" > /dev/null 2>&1

    # Make Mountpoint Mutable (again)
    run_command_inside_vm "if [[ -d \"${BENCHMARK_VM_TEST_PATH}\" ]]; then chattr -i \"${BENCHMARK_VM_TEST_PATH}\"; fi" > /dev/null 2>&1

    # Remove Mountpoint and everything in it (if present)
    run_command_inside_vm rm -rf "${BENCHMARK_VM_TEST_PATH}" > /dev/null 2>&1

    # Create Mountpoint
    run_command_inside_vm mkdir -p "${BENCHMARK_VM_TEST_PATH}" > /dev/null 2>&1

    # Make Mountpoint Immutable
    run_command_inside_vm chattr +i "${BENCHMARK_VM_TEST_PATH}" > /dev/null 2>&1

    # Format Device
    run_command_inside_vm mkfs.ext4 -F -G "${lgroups}" "${BENCHMARK_VM_TEST_DEVICE}" > /dev/null 2>&1

    # Mount Device
    run_command_inside_vm mount "${BENCHMARK_VM_TEST_DEVICE}" "${BENCHMARK_VM_TEST_PATH}" > /dev/null 2>&1
}
