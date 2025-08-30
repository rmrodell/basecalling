#!/bin/bash
#SBATCH --job-name=dorado_basecall_scatter
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=20G
#SBATCH --time=0-02:00:00
#SBATCH --output=slurm_logs/basecaller-%A_%a.out
#SBATCH --error=slurm_logs/basecaller-%A_%a.err

# --- ENVIRONMENT SETUP ---
module load biology dorado/1.1.0

# --- PATH SETUP ---
MAP_FILE="$BASE_DIR/directory_mapping.txt"
DIR_NAME=$(awk -v task_id="$SLURM_ARRAY_TASK_ID" '$1==task_id {print $2}' "$MAP_FILE")
TASK_DIR="$BASE_DIR/$DIR_NAME"
INPUT_DIR="$TASK_DIR/input"
OUTPUT_DIR="$TASK_DIR/output"
mkdir -p "$OUTPUT_DIR"
mkdir -p slurm_logs

echo "--- STAGE 1 (SCATTER): Basecalling Job $SLURM_ARRAY_JOB_ID, Task $SLURM_ARRAY_TASK_ID ---"
echo "Processing directory: $DIR_NAME"

# --- DORADO BASECALLER LOGIC ---
dorado basecaller sup "$INPUT_DIR" \
    --kit-name EXP-PBC096 \
    --no-trim > "$OUTPUT_DIR/basecalled.fastq"

echo "--- STAGE 1 (SCATTER): Task $SLURM_ARRAY_TASK_ID Complete ---"