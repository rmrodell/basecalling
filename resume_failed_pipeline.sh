#!/bin/bash
#
# RECOVERY SCRIPT for the Dorado Pipeline
#
# WHAT IT DOES:
# 1. Re-runs only the specified FAILED basecalling tasks from a previous run.
# 2. After the failed tasks are successfully completed, it triggers the final
#    merge and demultiplex step on the COMPLETE set of BAM files.
#
# HOW TO USE:
# 1. Edit the "USER CONFIGURATION" section below.
# 2. Make this script executable: chmod +x resume_failed_pipeline.sh
# 3. Run from the login node: ./resume_failed_pipeline.sh
#

# --- USER CONFIGURATION ---

# The EXACT SAME output directory from the original, failed run.
OUTPUT_DIR="/scratch/groups/nicolemm/rodell/basecalling/InVitro_SHAPE_Rep2_20250731"

# The directory where the sbatch scripts are located.
SCRIPT_DIR="/home/users/rodell/basecalling"

# A comma-separated list of the task IDs that timed out or failed. NO SPACES.
FAILED_TASKS="24,25"

# --- END USER CONFIGURATION ---

echo "--- Starting Pipeline Recovery Workflow ---"

# --- Sanity Checks ---
# Ensure the original output directory and mapping file exist.
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "FATAL ERROR: The specified OUTPUT_DIR does not exist: $OUTPUT_DIR"
    exit 1
fi
MAP_FILE="$OUTPUT_DIR/directory_mapping.txt"
if [ ! -f "$MAP_FILE" ]; then
    echo "FATAL ERROR: The mapping file is missing: $MAP_FILE"
    exit 1
fi
echo "Verified that the original output directory and mapping file exist."

# --- Cleanup of Failed Output ---
echo "Cleaning up incomplete output from failed tasks: $FAILED_TASKS"
# Use tr to replace commas with spaces for the loop
for task_id in $(echo $FAILED_TASKS | tr ',' ' '); do
    # Find the directory name corresponding to the failed task ID
    dir_name=$(awk -v task_id="$task_id" '$1==task_id {print $2}' "$MAP_FILE")
    if [ -z "$dir_name" ]; then
        echo "WARNING: Could not find directory name for task ID $task_id in mapping file."
        continue
    fi
    
    failed_bam_file="$OUTPUT_DIR/$dir_name/output/basecalled.bam"
    if [ -f "$failed_bam_file" ]; then
        echo "--> Removing potentially corrupt file: $failed_bam_file"
        rm -f "$failed_bam_file"
    fi
done
echo "Cleanup complete."

# --- Job Submission ---

# 1. Re-submit Stage 1, but ONLY for the failed tasks.
echo "Submitting re-run of Stage 1 for tasks: $FAILED_TASKS..."
RECOVERY_JOB_ID=$(sbatch \
    --export=ALL,OUTPUT_DIR="$OUTPUT_DIR" \
    --parsable \
    --array=$FAILED_TASKS \
    "$SCRIPT_DIR/basecaller_sup_array.sbatch")

if [ $? -ne 0 ]; then echo "FATAL ERROR: Failed to submit recovery jobs."; exit 1; fi
echo "--> Recovery basecalling jobs submitted with Job Array ID: $RECOVERY_JOB_ID"

# 2. Submit Stage 2 with a dependency on the recovery job completing successfully.
echo "Submitting Stage 2: Merge and Demultiplex Job (will wait for recovery jobs)..."
FINAL_JOB_ID=$(sbatch \
    --export=ALL,OUTPUT_DIR="$OUTPUT_DIR" \
    --parsable \
    --dependency=afterok:$RECOVERY_JOB_ID \
    "$SCRIPT_DIR/demuxer_merge.sbatch")

if [ $? -ne 0 ]; then echo "FATAL ERROR: Failed to submit final Stage 2 job."; exit 1; fi
echo "--> Final merge/demux job submitted with Job ID: $FINAL_JOB_ID"
echo ""
echo "--- Recovery Pipeline Successfully Submitted ---"
echo "You can monitor job progress with: squeue -u $USER"