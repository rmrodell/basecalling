#!/usr/bin/bash
#SBATCH --job-name=org_basecalling_%j
#SBATCH --output=org_basecalling_%j.out
#SBATCH --error=org_basecalling_%j.err
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --partition=gpu
#SBATCH --mem=5G
#SBATCH --gres=gpu:1
#SBATCH --mail-user=rodell@stanford.edu
#SBATCH --mail-type=BEGIN,END,FAIL

ml biology dorado/1.1.0 samtools/1.16.1

dorado basecaller sup /scratch/users/rodell/basecalling/pod5_test/ --kit-name EXP-PBC096 --no-trim > /scratch/users/rodell/basecalling/fastq_test_single/all_basecalled_single.fastq

dorado demux --output-dir /scratch/users/rodell/basecalling/bam_test_original --no-trim --no-classify /scratch/users/rodell/basecalling/fastq_test_single/all_basecalled_single.fastq