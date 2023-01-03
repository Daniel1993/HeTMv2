#!/bin/bash

DATA_FOLDER=$(pwd)/data/no_inter_confl
mkdir -p $DATA_FOLDER

cd ../../benches/bank

SAMPLES=3
DURATION_ORG=20000
DURATION_GPU=8000
#./makeTM.sh
DURATION=$DURATION_ORG

rm -f Bank_LOG.csv

L_DATASET=150000000
S_DATASET=15000000
# CPU_BACKOFF=250

CPU_THREADS=50
GPU_THREADS=128
GPU_BLOCKS=600
TRANSACTION_SIZE=4
CPU_BACKOFF=0
# GPU_BACKOFF=800000
GPU_BACKOFF=0
PROB_WRITE=100

function compile_fn {
	# arg list
	# 1st -> USE_TSX
	# 2nd -> probability of intersect
	# 3rd -> number of devices
	USE_TSX=$1
	P_INTERSECT=$2
	HETM_NB_DEVICES=$3
	./compile.sh opt \
		CMP_TYPE=COMPRESSED \
		LOG_TYPE=BMAP \
		USE_TSX_IMPL=$USE_TSX \
		PR_MAX_RWSET_SIZE=50 \
		BANK_PART=9 \
		BANK_INTRA_CONFL=0 \
		GPU_PART=0.52 \
		CPU_PART=0.52 \
		P_INTERSECT=$P_INTERSECT \
		PROFILE=1 \
		BMAP_GRAN_BITS=14 \
		DISABLE_NON_BLOCKING=1 \
		OVERLAP_CPY_BACK=0 \
		LOG_SIZE=4096 \
		BMAP_ENC_1BIT=1 \
		STM_LOG_BUFFER_SIZE=256 \
		BANK_PART_SCALE=1 \
		DISABLE_EARLY_VALIDATION=1 \
		HETM_NB_DEVICES=$HETM_NB_DEVICES \
		-j 14 >/dev/null
}

function doRunLargeDTST {
	# Seq. access, 18 items, prob. write {5..95}, writes 1%
	for s in `seq 1 $SAMPLES`
	do
		# 100M 500M 1G 1.5G
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.02
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.04
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.08
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.12
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.20
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.30
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.40
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.50
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.60
		### TODO: larger batches
		###
		mv Bank_LOG.csv $DATA_FOLDER/${1}_w${PROB_WRITE}_s${s}
	done
}

function doRunLargeDTST_CPU {
	# Seq. access, 18 items, prob. write {5..95}, writes 1%
	for s in `seq 1 $SAMPLES`
	do
		# 100M 500M 1G 1.5G
		timeout 60s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X 0.60
		tail -n 1 Bank_LOG.csv > /tmp/BankLastLine.csv
		# for i in `seq 1 7`
		for i in `seq 1 8`
		do
			cat /tmp/BankLastLine.csv >> Bank_LOG.csv
		done
		mv Bank_LOG.csv $DATA_FOLDER/${1}_w${PROB_WRITE}_s${s}
	done
}

DATASET=$L_DATASET
# GPU_BACKOFF=800000

###########################################################################
############### GPU-only
./compile.sh opt                     \
	CMP_TYPE=0                         \
	HETM_CPU_EN=0                      \
	HETM_GPU_EN=1                      \
	LOG_TYPE=BMAP                      \
	USE_TSX_IMPL=0                     \
	PR_MAX_RWSET_SIZE=200              \
	BANK_PART=9                        \
	GPU_PART=0.52                      \
	CPU_PART=0.52                      \
	P_INTERSECT=0.00                   \
	PROFILE=1                          \
	BMAP_GRAN_BITS=14 \
	HETM_NB_DEVICES=1
#
for PROB_WRITE in 10 100
do
	doRunLargeDTST GPUonly_rand_sep_DISABLED_large
done

# ############# CPU-only
./compile.sh opt                     \
	CMP_TYPE=0                         \
	HETM_CPU_EN=1                      \
	HETM_GPU_EN=0                      \
	LOG_TYPE=BMAP                      \
	USE_TSX_IMPL=0                     \
	PR_MAX_RWSET_SIZE=200              \
	BANK_PART=9                        \
	GPU_PART=0.52                      \
	CPU_PART=0.52                      \
	P_INTERSECT=0.00                   \
	PROFILE=1                          \
	BMAP_GRAN_BITS=14                  \
	HETM_NB_DEVICES=1
#
for PROB_WRITE in 10 100
do
	doRunLargeDTST_CPU CPUonly_rand_sep_DISABLED_large
done

compile_fn 0 0.0 1
for PROB_WRITE in 10 100
do
	doRunLargeDTST BMAP_rand_sep_1GPU
done

compile_fn 0 0.0 2
for PROB_WRITE in 10 100
do
	doRunLargeDTST BMAP_rand_sep_2GPU
done

compile_fn 0 0.0 3
for PROB_WRITE in 10 100
do
	doRunLargeDTST BMAP_rand_sep_3GPU
done

compile_fn 0 0.0 4
for PROB_WRITE in 10 100
do
	doRunLargeDTST BMAP_rand_sep_4GPU
done

# compile_fn 0 0.0 8
# for PROB_WRITE in 10 100
# do
# 	doRunLargeDTST BMAP_rand_sep_8GPU
# done

# compile_fn 0 0.0 12
# for PROB_WRITE in 10 100
# do
# 	doRunLargeDTST BMAP_rand_sep_12GPU
# done

# compile_fn 0 0.0 16
# for PROB_WRITE in 10 100
# do
# 	doRunLargeDTST BMAP_rand_sep_16GPU
# done

# mkdir -p $DATA_FOLDER/array_batch_duration_TSX
# mv $DATA_FOLDER/*_s* $DATA_FOLDER/array_batch_duration_TSX/
#
