#!/bin/bash
#SBATCH --job-name=dorado_basecaller_sup
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=20G
#SBATCH --time=0-03:00:00
#SBATCH --output=slurm_logs/basecaller-%A_%a.out
#SBATCH --error=slurm_logs/basecaller-%A_%a.err
#SBATCH --mail-user=rodell@stanford.edu
#SBATCH --mail-type=BEGIN,END,FAIL

# Load required software modules.
module load biology dorado/1.1.0

# --- Path Setup ---
# Find the specific data batch this job is responsible for using the mapping file.
MAP_FILE="$OUTPUT_DIR/directory_mapping.txt"
DIR_NAME=$(awk -v task_id="$SLURM_ARRAY_TASK_ID" '$1==task_id {print $2}' "$MAP_FILE")

# Define the input and output directories for this specific task.
TASK_DIR="$OUTPUT_DIR/$DIR_NAME"
INPUT_DIR="$TASK_DIR/input"
BAM_OUTPUT_DIR="$TASK_DIR/output"
mkdir -p "$BAM_OUTPUT_DIR"
mkdir -p slurm_logs

echo "--- Stage 1: Basecalling Task ${SLURM_ARRAY_TASK_ID} ---"
echo "Processing files in: $INPUT_DIR"

# --- Dorado Basecaller ---
# Run the basecaller on the input .pod5 files for this batch.
# The output is redirected to a correctly named BAM file.
dorado basecaller sup "$INPUT_DIR" \
    --kit-name EXP-PBC096 \
    --no-trim > "$BAM_OUTPUT_DIR/basecalled.bam"

echo "--- Stage 1: Task ${SLURM_ARRAY_TASK_ID} Complete ---"