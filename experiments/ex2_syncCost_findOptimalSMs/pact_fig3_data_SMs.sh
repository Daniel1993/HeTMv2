#!/bin/bash

DATA_FOLDER=$(pwd)/data/no_inter_confl_SMs
mkdir -p $DATA_FOLDER

cd ../../benches/bank

SAMPLES=3
#./makeTM.sh
DURATION=100000

rm -f Bank_LOG.csv

L_DATASET=150000000
S_DATASET=15000000
# CPU_BACKOFF=250

CPU_THREADS=90
GPU_THREADS=128
GPU_BLOCKS=110
TRANSACTION_SIZE=4
CPU_BACKOFF=0
# GPU_BACKOFF=800000
GPU_BACKOFF=0
PROB_WRITE=100
TIMEBATCH=10.0

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
		GPU_PART=0.55 \
		CPU_PART=0.55 \
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
		for GPU_BLOCKS in 1 10 30 50 70 100 120 150 175 200 250 300 350 400 500 600 700 800 900
		do
			# 100M 500M 1G 1.5G
			timeout 120s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
				-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X $TIMEBATCH
			### TODO: larger batches
			###
		done
		mv Bank_LOG.csv $DATA_FOLDER/${1}_w${PROB_WRITE}_s${s}
	done
}

function doRunLargeDTST_CPU {
	# Seq. access, 18 items, prob. write {5..95}, writes 1%
	for s in `seq 1 $SAMPLES`
	do
		# 100M 500M 1G 1.5G
		timeout 120s ./bank -n $CPU_THREADS -b $GPU_BLOCKS -x $GPU_THREADS -a $DATASET -d $DURATION -R 0 \
			-S $TRANSACTION_SIZE -l $PROB_WRITE -N 1 -T 1 CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF -X $TIMEBATCH
		tail -n 1 Bank_LOG.csv > /tmp/BankLastLine.csv
		# for i in `seq 1 7`
		for i in `seq 1 14`
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
	GPU_PART=0.55                      \
	CPU_PART=0.55                      \
	P_INTERSECT=0.00                   \
	PROFILE=1                          \
	BMAP_GRAN_BITS=14 \
	HETM_NB_DEVICES=1
#
for PROB_WRITE in 100
do
	doRunLargeDTST GPUonly
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
	GPU_PART=0.55                      \
	CPU_PART=0.55                      \
	P_INTERSECT=0.00                   \
	PROFILE=1                          \
	BMAP_GRAN_BITS=14                  \
	HETM_NB_DEVICES=1
#
for PROB_WRITE in 100
do
	doRunLargeDTST_CPU CPUonly
done

compile_fn 0 0.0 1
for PROB_WRITE in 100
do
	doRunLargeDTST BMAP_1GPU
done

