#!/bin/bash
#SBATCH --job-name=step1_gpu_job
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=2-00:00:00
#SBATCH --output=slurm_logs/step1-%A_%a.out
#SBATCH --error=slurm_logs/step1-%A_%a.err

# --- PATH SETUP ---
MAP_FILE="$BASE_DIR/directory_mapping.txt"
DIR_NAME=$(awk -v task_id="$SLURM_ARRAY_TASK_ID" '$1==task_id {print $2}' "$MAP_FILE")
TASK_DIR="$BASE_DIR/$DIR_NAME"

INPUT_DIR="$TASK_DIR/input"
OUTPUT_DIR="$TASK_DIR/output"
mkdir -p "$OUTPUT_DIR"

echo "--- STAGE 1: Job $SLURM_ARRAY_JOB_ID, Task $SLURM_ARRAY_TASK_ID ---"
echo "Processing directory: $DIR_NAME"

# --- YOUR STAGE 1 LOGIC HERE ---
#
# Commands for the first step.
# Read data from $INPUT_DIR.
# Write intermediate results to $OUTPUT_DIR.
# This code will have access to one GPU.
#
# Example:
# my_gpu_program --input "$INPUT_DIR/data.file" --output "$OUTPUT_DIR/intermediate.dat"
#
# --- END OF YOUR LOGIC ---

echo "--- STAGE 1: Task $SLURM_ARRAY_TASK_ID Complete ---"