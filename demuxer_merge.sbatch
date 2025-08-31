#!/bin/bash
#SBATCH --job-name=dorado_demuxer
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=50G
#SBATCH --time=0-12:00:00
#SBATCH --output=slurm_logs/demuxer-%j.out
#SBATCH --error=slurm_logs/demuxer-%j.err
#SBATCH --mail-user=rodell@stanford.edu
#SBATCH --mail-type=BEGIN,END,FAIL

# Load both dorado AND samtools, as both are needed in this stage.
module load biology dorado/1.1.0 samtools/1.16.1

# --- Path Setup ---
# The OUTPUT_DIR is inherited from the main controller script.
# All final demultiplexed files will be placed in a 'final_results' directory.
FINAL_RESULTS_DIR="$OUTPUT_DIR/final_results"
mkdir -p "$FINAL_RESULTS_DIR"
mkdir -p slurm_logs

echo "--- Stage 2: Merge and Demultiplex Job $SLURM_JOB_ID ---"
echo "Final results will be written to: $FINAL_RESULTS_DIR"

# --- Merge Intermediate BAM Files ---

# 1. Locate all the 'basecalled.bam' files produced by the Stage 1 jobs.
echo "Finding all intermediate BAM files from Stage 1..."
BAM_PATHS_LOG="$FINAL_RESULTS_DIR/merged_files.log"
find "$OUTPUT_DIR" -path "*/output/basecalled.bam" > "$BAM_PATHS_LOG"

# 2. Merge all found BAM files into a single, temporary, valid BAM file.
MERGED_BAM_FILE="$OUTPUT_DIR/merged_all_batches.bam"
echo "Merging $(wc -l < "$BAM_PATHS_LOG") BAM files into: $MERGED_BAM_FILE"
xargs -a "$BAM_PATHS_LOG" samtools merge "$MERGED_BAM_FILE"

# Verify that the merge was successful.
if [ ! -s "$MERGED_BAM_FILE" ]; then
    echo "FATAL ERROR: Merged BAM file is empty or was not created. Exiting."
    exit 1
fi
echo "Merge successful. Final merged file size:"
ls -lh "$MERGED_BAM_FILE"

# --- Demultiplex the Final Merged File ---

echo "Running dorado demux on the final merged BAM file..."
dorado demux --output-dir "$FINAL_RESULTS_DIR" \
    --no-trim \
    --no-classify \
    "$MERGED_BAM_FILE"

if [ $? -ne 0 ]; then
    echo "FATAL ERROR: Dorado demux failed. The merged BAM file will be kept for inspection."
    exit 1
fi

# --- Cleanup ---
echo "Demultiplexing complete. Removing temporary merged BAM file."
rm -f "$MERGED_BAM_FILE"

echo "--- Pipeline Complete ---"