#!/bin/bash
#SBATCH --job-name=demux_concat-%j
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=50G
#SBATCH --time=0-01:00:00
#SBATCH --output=slurm_logs/demux_concat-%j.out
#SBATCH --error=slurm_logs/demux_concat-%j.err
#SBATCH --mail-user=rodell@stanford.edu
#SBATCH --mail-type=BEGIN,END,FAIL

module load biology dorado/1.1.0

FINAL_RESULTS_DIR="$BASE_DIR/$RUN_TAG"
mkdir -p "$FINAL_RESULTS_DIR"
mkdir -p slurm_logs

echo "--- STAGE 2 (Concat): Demux Job $SLURM_JOB_ID ---"
echo "Final results will be written to: $FINAL_RESULTS_DIR"

TEMP_FASTQ="$BASE_DIR/temp_concat_${RUN_TAG}.fastq"

echo "Concatenating intermediate FASTQ files into $TEMP_FASTQ..."
find "$BASE_DIR" -path "*/output/basecalled.fastq" -print0 | xargs -0 cat > "$TEMP_FASTQ"

if [ ! -s "$TEMP_FASTQ" ]; then
    echo "ERROR: Concatenated FASTQ file is empty or missing. Exiting."
    rm -f "$TEMP_FASTQ"
    exit 1
fi

echo "Running dorado demux on the concatenated file..."
dorado demux --output-dir "$FINAL_RESULTS_DIR" \
    --no-trim \
    --no-classify \
    "$TEMP_FASTQ"

if [ $? -ne 0 ]; then
    echo "ERROR: Dorado demux failed."
    rm -f "$TEMP_FASTQ"
    exit 1
fi

echo "Cleaning up temporary file..."
rm -f "$TEMP_FASTQ"

echo "--- STAGE 2 (Concat): Workflow complete. ---"