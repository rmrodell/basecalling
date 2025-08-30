#!/bin/bash
#
# MASTER CONTROLLER SCRIPT
# Run this once from the login node to submit all test cases in a sequential chain.
# Do NOT submit this script with sbatch.
#

echo "--- Starting Master Controller ---"

# --- Prepare workflow scripts for chaining (if not already done) ---
prepare_workflow_script() {
    local script_path=$1
    if ! grep -q "DEP_FLAG" "$script_path"; then
        sed -i '/# Submit Stage 1:/a DEP_FLAG=""\nif [ ! -z "$1" ]; then\n  DEP_FLAG="--dependency=$1"\nfi' "$script_path"
        sed -i 's/--array/--parsable $DEP_FLAG --array/' "$script_path"
        sed -i 's/log_message "Workflow successfully submitted."/echo $JOB_ID_2/' "$script_path"
        echo "[INFO] Prepared for chaining: $script_path"
    fi
}
prepare_workflow_script /home/users/rodell/basecalling/run_dorado_workflow_round1.sh
prepare_workflow_script /home/users/rodell/basecalling/run_dorado_workflow_round2.sh

# --- Job Submission Chain ---

echo "--> Submitting Test Case 1 (original)..."
ORIGINAL_JOB_ID=$(sbatch --parsable /home/users/rodell/basecalling/original.sbatch)
if [ $? -ne 0 ]; then echo "ERROR: Failed to submit original.sbatch"; exit 1; fi
echo "    Job ID: $ORIGINAL_JOB_ID"

echo "--> Submitting Test Case 2 (round1), dependent on Job $ORIGINAL_JOB_ID..."
ROUND1_FINAL_JOB_ID=$(bash /home/users/rodell/basecalling/run_dorado_workflow_round1.sh "afterok:$ORIGINAL_JOB_ID")
if [ -z "$ROUND1_FINAL_JOB_ID" ]; then echo "ERROR: Failed to get final job ID from round1"; exit 1; fi
echo "    Final job in chain has ID: $ROUND1_FINAL_JOB_ID"

echo "--> Submitting Test Case 3 (round2), dependent on Job $ROUND1_FINAL_JOB_ID..."
ROUND2_FINAL_JOB_ID=$(bash /home/users/rodell/basecalling/run_dorado_workflow_round2.sh "afterok:$ROUND1_FINAL_JOB_ID")
if [ -z "$ROUND2_FINAL_JOB_ID" ]; then echo "ERROR: Failed to get final job ID from round2"; exit 1; fi
echo "    Final job in chain has ID: $ROUND2_FINAL_JOB_ID"

echo "--- All Test Cases Submitted Successfully ---"