#!/bin/bash
#SBATCH --job-name=dorado_demux_stream
#SBATCH --partition=gpu
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=50G
#SBATCH --time=0-01:00:00
#SBATCH --output=slurm_logs/demux_stream-%j.out
#SBATCH --error=slurm_logs/demux_stream-%j.err

# --- ENVIRONMENT SETUP ---
module load biology dorado/1.1.0

# --- PATH SETUP ---
FINAL_RESULTS_DIR="$BASE_DIR/$RUN_TAG"
mkdir -p "$FINAL_RESULTS_DIR"
mkdir -p slurm_logs

echo "--- STAGE 2 (STREAM): Demux Job $SLURM_JOB_ID ---"
echo "This run's unique tag is: $RUN_TAG"
echo "Final results will be written to: $FINAL_RESULTS_DIR"
echo "Finding all intermediate FASTQ files to stream for demultiplexing."


# --- DORADO DEMUX LOGIC ---

# The `set -o pipefail` option ensures that if any command in the pipe fails,
# the entire line will return an error, causing the job to fail correctly.
# We execute it inside a subshell to not affect other commands.
(
    set -o pipefail
    # This is the single, correct pipeline to run.
    find "$BASE_DIR" -path "*/output/basecalled.fastq" -print0 | xargs -0 cat | \
    dorado demux --output-dir "$FINAL_RESULTS_DIR" \
        --no-trim \
        --no-classify \
        -
)

# Check the exit code of the pipeline
if [ $? -ne 0 ]; then
    echo "ERROR: The demultiplexing stream pipeline failed."
    exit 1
fi

# --- END OF LOGIC ---

echo "--- STAGE 2 (STREAM): Demultiplexing complete. Results are in $FINAL_RESULTS_DIR ---"