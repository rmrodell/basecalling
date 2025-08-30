#!/bin/bash
#SBATCH --job-name=step2_gpu_job
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=2-00:00:00
#SBATCH --output=slurm_logs/step2-%A_%a.out
#SBATCH --error=slurm_logs/step2-%A_%a.err

# --- PATH SETUP ---
MAP_FILE="$BASE_DIR/directory_mapping.txt"
DIR_NAME=$(awk -v task_id="$SLURM_ARRAY_TASK_ID" '$1==task_id {print $2}' "$MAP_FILE")
TASK_DIR="$BASE_DIR/$DIR_NAME"

PREVIOUS_OUTPUT_DIR="$TASK_DIR/output"
FINAL_RESULTS_DIR="$TASK_DIR/final_results"
mkdir -p "$FINAL_RESULTS_DIR"

echo "--- STAGE 2: Job $SLURM_ARRAY_JOB_ID, Task $SLURM_ARRAY_TASK_ID ---"
echo "Processing directory: $DIR_NAME"

# --- YOUR STAGE 2 LOGIC HERE ---
#
# Commands for the second step.
# Read intermediate data from $PREVIOUS_OUTPUT_DIR.
# Write final results to $FINAL_RESULTS_DIR.
# This code will also have access to one GPU.
#
# Example:
# another_gpu_program --input "$PREVIOUS_OUTPUT_DIR/intermediate.dat" --output "$FINAL_RESULTS_DIR/final.result"
#
# --- END OF YOUR LOGIC ---

echo "--- STAGE 2: Task $SLURM_ARRAY_TASK_ID Complete ---"