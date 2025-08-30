#!/bin/bash
#
# This script submits a two-stage sequential job array workflow.
#

# --- USER CONFIGURATION ---

# The main project directory where your data subdirectories are located.
BASE_DIR="/path/to/your/project"

# The directory where your .sbatch scripts are located.
SCRIPT_DIR="/path/to/your/scripts"

# The total number of tasks/subdirectories to process.
TOTAL_JOBS=100

# The maximum number of jobs that can run simultaneously.
# This is set to 50 to respect the user's limit on the GPU partition.
# Since Stage 2 waits for Stage 1, this limit applies to each stage in turn.
MAX_CONCURRENT_JOBS=50

# --- END USER CONFIGURATION ---

# Create necessary directories and log file
LOG_FILE="$BASE_DIR/workflow.log"
mkdir -p "$BASE_DIR"

# Function to log messages to screen and file
log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Function to create a mapping file from array index to directory name
create_mapping_file() {
    local map_file="$BASE_DIR/directory_mapping.txt"
    log_message "Creating directory mapping file at $map_file"
    rm -f "$map_file"
    local count=1
    for dir in "$BASE_DIR"/*; do
        if [ -d "$dir" ] && [ -d "$dir/input" ]; then
            echo "$count $(basename "$dir")" >> "$map_file"
            count=$((count + 1))
        fi
    done

    if [ $((count-1)) -ne $TOTAL_JOBS ]; then
        log_message "WARNING: Expected $TOTAL_JOBS directories but found $((count-1))."
    fi
}

# --- MAIN SCRIPT EXECUTION ---

log_message "Starting two-stage workflow."
create_mapping_file

# Submit the first job array
log_message "Submitting Stage 1 job array."
JOB_ID_1=$(sbatch \
    --export=ALL,BASE_DIR="$BASE_DIR" \
    --parsable \
    --array=1-${TOTAL_JOBS}%${MAX_CONCURRENT_JOBS} \
    "$SCRIPT_DIR/step1_array.sbatch")

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to submit Stage 1 job array. Exiting."
    exit 1
fi
log_message "Stage 1 job array submitted with ID: $JOB_ID_1"

# Submit the second job array, dependent on the first one
log_message "Submitting Stage 2 job array, dependent on job $JOB_ID_1."
JOB_ID_2=$(sbatch \
    --export=ALL,BASE_DIR="$BASE_DIR" \
    --parsable \
    --array=1-${TOTAL_JOBS}%${MAX_CONCURRENT_JOBS} \
    --dependency=afterok:$JOB_ID_1 \
    "$SCRIPT_DIR/step2_array.sbatch")

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to submit Stage 2 job array. Exiting."
    exit 1
fi
log_message "Stage 2 job array submitted with ID: $JOB_ID_2"
log_message "Workflow successfully submitted. Monitor jobs with 'squeue -u $USER'."