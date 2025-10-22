# basecalling
Nanopore basecalling scripts for basecalling on Stanford's Sherlock system.

## How to use:  
```bash run_basecaller_sup_pipeline.sh \
  -o <output_directory> \
  -s <script_directory> \
  -p <pod5_directory> \
  -b <number_of_batches> \
  -m <max_number_of_jobs>```


Runs two scripts in sequence: basecaller_sup_array.sbatch and demuxer_merge.sbatch

This defaults to running super-high-accuracy DNA basecalling with dorado/1.1.0, as set in the basecaller_sup_array.sbatch script.

To update the version of dorado, change the "module load biology dorado/1.1.0" to the desired version. If Sherlock does not have that version installed (as evidenced by their software list), you will have to install it yourself and figure out how to update it.

To change any parameters around basecalling (kit, basecalling model, modified bases, etc), update the dorado command in basecaller_sup_array.sbatch. The current command is:

```dorado basecaller sup "$INPUT_DIR" \
    --kit-name EXP-PBC096 \
    --no-trim > "$BAM_OUTPUT_DIR/basecalled.bam"```

Basecalling outputs a bam file, which is then demultiplexed by barcode into a single bam file per barcode.
