#!/bin/bash
#SBATCH --job-name=merge
#SBATCH --partition=normal
#SBATCH --cpus-per-task=8
#SBATCH --mem=50G
#SBATCH --time=0-01:00:00
#SBATCH --output=slurm_logs/merge-%j.out
#SBATCH --error=slurm_logs/merge-%j.err
#SBATCH --mail-user=rodell@stanford.edu
#SBATCH --mail-type=BEGIN,END,FAIL

# Load both dorado AND samtools, as both are needed in this stage.
module load biology samtools/1.16.1

# --- Path Setup ---
# The OUTPUT_DIR is inherited from the main controller script.
# Final file will be placed in a 'final_results' directory.
FINAL_RESULTS_DIR="$OUTPUT_DIR/final_results"
mkdir -p "$FINAL_RESULTS_DIR"
mkdir -p slurm_logs

echo "--- Stage 2: Merge Job $SLURM_JOB_ID ---"
echo "Final results will be written to: $FINAL_RESULTS_DIR"

# --- Merge Intermediate BAM Files ---

# 1. Locate all the 'basecalled.bam' files produced by the Stage 1 jobs.
echo "Finding all intermediate BAM files from Stage 1..."
BAM_PATHS_LOG="$FINAL_RESULTS_DIR/merged_files.log"
find "$OUTPUT_DIR" -path "*/output/basecalled.bam" > "$BAM_PATHS_LOG"

# 2. Merge all found BAM files into a single, valid BAM file in the results directory.
MERGED_BAM_FILE="$FINAL_RESULTS_DIR/merged_all_batches.bam"
echo "Merging $(wc -l < "$BAM_PATHS_LOG") BAM files into: $MERGED_BAM_FILE"
xargs -a "$BAM_PATHS_LOG" samtools merge -@ 8 "$MERGED_BAM_FILE"

# Verify that the merge was successful.
if [ ! -s "$MERGED_BAM_FILE" ]; then
    echo "FATAL ERROR: Merged BAM file is empty or was not created. Exiting."
    exit 1
fi
echo "Merge successful. Final merged file size:"
ls -lh "$MERGED_BAM_FILE"

echo "--- Pipeline Complete ---"
