#!/bin/bash
#
# This script automatically distributes POD5 files from a single source directory
# into batch subdirectories and then runs a two-stage "scatter-pipe" workflow.
#

# --- USER CONFIGURATION ---
# The main project directory where batch subdirectories will be created.
BASE_DIR="/scratch/users/rodell/basecalling/round2"
# The directory where your .sbatch scripts are located.
SCRIPT_DIR="/home/users/rodell/basecalling"
# The SINGLE directory containing all your input .pod5 files.
POD5_DIR="/scratch/users/rodell/basecalling/pod5_test"
# The number of parallel jobs (batches) you want to split the work into.
NUM_BATCHES=3
# The maximum number of jobs that can run simultaneously on the GPU partition.
MAX_CONCURRENT_JOBS=50
# Unique identifier for each run
RUN_TAG="round_2"

# --- END USER CONFIGURATION ---

LOG_FILE="$BASE_DIR/workflow_${RUN_TAG}.log"
mkdir -p "$BASE_DIR"

log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message" >> "$LOG_FILE"
}

# Automatically distributes POD5 files into batch directories.
distribute_pod5_files() {
    log_message "Preparing to distribute POD5 files from $POD5_DIR..."

    # 1. Clean up old batch directories to ensure a fresh start.
    log_message "Removing any existing batch directories in $BASE_DIR..."
    find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -name "batch_*" -exec rm -rf {} +

    # 2. Find all .pod5 files and store them in a bash array.
    mapfile -t all_files < <(find "$POD5_DIR" -type f -name "*.pod5")
    local file_count=${#all_files[@]}

    if [ "$file_count" -eq 0 ]; then
        log_message "ERROR: No .pod5 files found in $POD5_DIR. Exiting."
        exit 1
    fi
    log_message "Found $file_count .pod5 files to distribute into $NUM_BATCHES batches."

    # 3. Loop through all files and create symbolic links in target batch directories.
    local i=0
    for file_path in "${all_files[@]}"; do
        # Determine the target batch number using round-robin (modulo arithmetic).
        local batch_num=$(( (i % NUM_BATCHES) + 1 ))
        # Format the directory name with zero-padding (e.g., batch_01, batch_02).
        local batch_dir_name=$(printf "batch_%02d" $batch_num)
        local target_dir="$BASE_DIR/$batch_dir_name/input"

        # Create the directory structure if it doesn't exist.
        mkdir -p "$target_dir"

        # Create a symbolic link instead of moving the file.
        ln -s "$file_path" "$target_dir/"
        
        i=$((i+1))
    done

    log_message "Successfully created symbolic links for $file_count files."
}

# This function now relies on the directories created by distribute_pod5_files.
create_mapping_file() {
    local map_file="$BASE_DIR/directory_mapping.txt"
    log_message "Creating directory mapping file for Stage 1 at $map_file"
    rm -f "$map_file"
    local count=1
    # Use 'sort -V' for natural sorting of numbers (batch_1, batch_2, ... batch_10).
    for dir in $(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -name "batch_*" | sort -V); do
        if [ -d "$dir/input" ]; then
            echo "$count $(basename "$dir")" >> "$map_file"
            count=$((count + 1))
        fi
    done
}

# --- MAIN SCRIPT EXECUTION ---

log_message "Starting Dorado 'scatter-pipe' workflow for run: $RUN_TAG"

# Run the new distribution function FIRST.
distribute_pod5_files

# This function now runs on the newly created directories.
create_mapping_file

# Submit Stage 1: A parallel job array for basecalling
DEP_FLAG=""
if [ ! -z "$1" ]; then
  DEP_FLAG="--dependency=$1"
fi
log_message "Submitting Stage 1 (parallel basecaller) job array."
JOB_ID_1=$(sbatch \
    --export=ALL,BASE_DIR="$BASE_DIR" \
    --parsable \
    --parsable $DEP_FLAG --array=1-${NUM_BATCHES}%${MAX_CONCURRENT_JOBS} \
    "$SCRIPT_DIR/dorado_basecaller_array.sbatch")

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to submit Stage 1 job array. Exiting."
    exit 1
fi
log_message "Stage 1 job array submitted with ID: $JOB_ID_1"

# Submit Stage 2: A SINGLE job for demultiplexing that waits for the whole array
log_message "Submitting Stage 2 (streaming demux job), dependent on array $JOB_ID_1."
JOB_ID_2=$(sbatch \
    --export=ALL,BASE_DIR="$BASE_DIR",RUN_TAG="$RUN_TAG" \
    --parsable \
    --dependency=afterok:$JOB_ID_1 \
    "$SCRIPT_DIR/dorado_demux_stream.sbatch")

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to submit Stage 2 job. Exiting."
    exit 1
fi
log_message "Stage 2 job submitted with ID: $JOB_ID_2"
echo $JOB_ID_2