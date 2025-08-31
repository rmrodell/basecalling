#!/bin/bash
#
# MASTER CONTROLLER for the Dorado Basecalling and Demultiplexing Pipeline
#
# WHAT IT DOES:
# 1. Prepares the workspace by distributing input .pod5 files into batches.
# 2. Submits Stage 1: A parallel job array to basecall all batches into BAM files.
# 3. Submits Stage 2: A single job that waits for all basecalling to finish,
#    merges the resulting BAM files, and then demultiplexes the final merged file.
#
# HOW TO USE:
# 1. Edit the "USER CONFIGURATION" section below.
# 2. Make this script executable: chmod +x run_basecaller_sup_pipeline.sh
# 3. Run from the login node: ./run_basecaller_sup_pipeline.sh
#

# --- USER CONFIGURATION ---

# The main project directory where all output will be created.
# A unique directory is recommended for each sequencing run.
OUTPUT_DIR="/scratch/groups/nicolemm/rodell/basecalling/InVitro_SHAPE_Rep2_20250731"

# The directory where the sbatch scripts are located.
SCRIPT_DIR="/home/users/rodell/basecalling"

# The SINGLE directory containing all your input .pod5 files for this run.
POD5_DIR="/scratch/groups/nicolemm/rodell/basecalling/InVitro_SHAPE_Rep2_20250731/pod5"

# The number of parallel basecalling jobs you want to run.
# More batches can speed up basecalling but may use more resources, potentially slowing your place in the queue.
NUM_BATCHES=25

# The maximum number of basecalling jobs allowed to run at the same time.
MAX_CONCURRENT_JOBS=50

# --- END USER CONFIGURATION ---

LOG_FILE="$OUTPUT_DIR/pipeline_setup.log"
mkdir -p "$OUTPUT_DIR"

# Function to log setup progress to a file.
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# This function organizes the input files for parallel processing.
distribute_pod5_files() {
    log_message "Preparing workspace in $OUTPUT_DIR..."
    log_message "Cleaning up any old batch directories..."
    find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -name "batch_*" -exec rm -rf {} +

    log_message "Locating .pod5 files in $POD5_DIR..."
    mapfile -t all_files < <(find "$POD5_DIR" -type f -name "*.pod5")
    local file_count=${#all_files[@]}
    if [ "$file_count" -eq 0 ]; then
        echo "FATAL ERROR: No .pod5 files found in $POD5_DIR. Exiting."
        exit 1
    fi
    log_message "Found $file_count .pod5 files. Distributing into $NUM_BATCHES batches..."

    # Create symbolic links to distribute files into batches without copying them.
    local i=0
    for file_path in "${all_files[@]}"; do
        local batch_num=$(( (i % NUM_BATCHES) + 1 ))
        local target_dir="$OUTPUT_DIR/$(printf "batch_%02d" $batch_num)/input"
        mkdir -p "$target_dir"
        ln -s "$file_path" "$target_dir/"
        i=$((i+1))
    done
    log_message "File distribution complete."
}

# This function creates a mapping file that tells each parallel job which batch to work on.
create_mapping_file() {
    local map_file="$OUTPUT_DIR/directory_mapping.txt"
    log_message "Creating job-to-directory mapping file..."
    rm -f "$map_file"
    local count=1
    for dir in $(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -name "batch_*" | sort -V); do
        if [ -d "$dir/input" ]; then
            echo "$count $(basename "$dir")" >> "$map_file"
            count=$((count + 1))
        fi
    done
}

# --- MAIN SCRIPT EXECUTION ---

echo "--- Starting Dorado Pipeline Setup ---"
distribute_pod5_files
create_mapping_file

# Submit Stage 1: A parallel job array for basecalling.
echo "Submitting Stage 1: Parallel Basecalling Jobs..."
JOB_ID_1=$(sbatch \
    --export=ALL,OUTPUT_DIR="$OUTPUT_DIR" \
    --parsable \
    --array=1-${NUM_BATCHES}%${MAX_CONCURRENT_JOBS} \
    "$SCRIPT_DIR/basecaller_sup_array.sbatch")

if [ $? -ne 0 ]; then echo "FATAL ERROR: Failed to submit Stage 1 jobs."; exit 1; fi
echo "--> Stage 1 submitted with Job Array ID: $JOB_ID_1"

# Submit Stage 2: A single job that waits for all of Stage 1 to finish successfully.
echo "Submitting Stage 2: Merge and Demultiplex Job (will wait for Stage 1)..."
JOB_ID_2=$(sbatch \
    --export=ALL,OUTPUT_DIR="$OUTPUT_DIR" \
    --parsable \
    --dependency=afterok:$JOB_ID_1 \
    "$SCRIPT_DIR/demuxer_merge.sbatch")

if [ $? -ne 0 ]; then echo "FATAL ERROR: Failed to submit Stage 2 job."; exit 1; fi
echo "--> Stage 2 submitted with Job ID: $JOB_ID_2"
echo ""
echo "--- Pipeline Successfully Submitted ---"
echo "You can monitor job progress with: squeue -u $USER"
echo "Detailed setup log is at: $LOG_FILE"