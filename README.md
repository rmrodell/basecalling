# basecalling
Nanopore basecalling scripts for basecalling on Stanford's Sherlock system.

## How to use:  
```bash
bash run_basecaller_sup_pipeline.sh \
  -o <output_directory> \
  -s <script_directory> \
  -p <pod5_directory> \
  -b <number_of_batches> \
  -m <max_number_of_jobs>
```


Runs two scripts in sequence: basecaller_sup_array.sbatch and demuxer_merge.sbatch

This defaults to running super-high-accuracy DNA basecalling with dorado/1.1.0, as set in the basecaller_sup_array.sbatch script.

To specifiy the GPU to basecall on, modify the SBATCH part of the basecaller_sup_array.sbatch. Default is as so:

#SBATCH -C '[GPU_GEN:HPR|GPU_GEN:LOV|GPU_GEN:VLT]'

Which allows basecalling on any GPU in the Hopper, Lovelace, or Voltage generation. These are the top three generations available on Sherlock as of Fall 2025 and should perform basecalling in a speedy manner. Further restricting this list could increase the time it takes for your job to run (as there are less options of GPUs for the job to run on), but there are rumors that the GPU architecture can impact basecalling. If you are doing something highly sensitive to the specific mutations you are reading (direct RNA mismatches), it is likely worth it to restrict to a single GPU (Hopper's are the fastest). If you just need some sequencing reads that are good enough (SHAPE, BID), keeping these settings should be sufficient.

To update the version of dorado, change the "module load biology dorado/1.1.0" to the desired version. If Sherlock does not have that version installed (as evidenced by their software list), you will have to install it yourself and figure out how to update it.

To change any parameters around basecalling (kit, basecalling model, modified bases, etc), update the dorado command in basecaller_sup_array.sbatch. The current command is:

```bash
dorado basecaller sup "$INPUT_DIR" \
    --kit-name EXP-PBC096 \
    --no-trim > "$BAM_OUTPUT_DIR/basecalled.bam"
```

Basecalling outputs a bam file, which is then demultiplexed by barcode into a single bam file per barcode.

## Basecalling Job Fails

Sometimes, a GPU can go kaput halfway through your job. Never fear, you do not have to re-run the full script from above. Instead, you need to look at resume_failed_pipeline.sh.

Identify the tasks numbers that failed and update the user configuration settings accordingly. This will re-submit basecalling jobs only for the batches that intitially failed. It will then carry through to demultiplexing of both the basecalled batches that completed on the first attempt and those that did not. You will end up at the same spot: one bam file per barcode in a given directory.
