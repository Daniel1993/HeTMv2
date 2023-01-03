#!/bin/bash

DURATION=30000
SAMPLES=1
#./makeTM.sh

rm -f Bank.csv GPUload CPUload GPUsteal

# LARGE_DATASET=1000000
# L_CONFL_SPACE=500000
# SMALL_DATASET=100000
# S_CONFL_SPACE=50000
LARGE_DATASET=65536
L_CONFL_SPACE=32768
SMALL_DATASET=10000	
S_CONFL_SPACE=20000

GPU_BLOCKS=200
GPU_THREADS=128
CPU_THREADS=50

CPU_BACKOFF=1
GPU_BACKOFF=1

SIZE_ZIPF=2000000
GPU_INPUT="GPU_input_${SIZE_ZIPF}_099_25165824.txt"
CPU_INPUT="CPU_input_${SIZE_ZIPF}_099_1310720.txt"

if [ ! -f $GPU_INPUT ]
then
	cd java_zipf
	java Main $SIZE_ZIPF 0.99 25165824 > ../$GPU_INPUT
	cd ..
fi
if [ ! -f $CPU_INPUT ]
then
	cd java_zipf
	java Main $SIZE_ZIPF 0.99 1310720 > ../$CPU_INPUT
	cd ..
fi
#
# SIZE_ZIPF=80000000
# GPU_INPUT="GPU_input_${SIZE_ZIPF}_099_25165824.txt"
# CPU_INPUT="CPU_input_${SIZE_ZIPF}_099_1310720.txt"
#
# if [ ! -f $GPU_INPUT ]
# then
# 	cd java_zipf
# 	java Main $SIZE_ZIPF 0.99 25165824 > ../$GPU_INPUT
# 	cd ..
# fi
# if [ ! -f $CPU_INPUT ]
# then
# 	cd java_zipf
# 	java Main $SIZE_ZIPF 0.99 1310720 > ../$CPU_INPUT
# 	cd ..
# fi

# memcached read only

NB_CONFL_GPU_BUFFER=100

### TODO: use shared 0, 30, 50

function actualRun {
	timeout 90s ./memcd -n $CPU_THREADS -l 8 -b $GPU_BLOCKS -x $GPU_THREADS -T 1 -a $DATASET \
		-d $DURATION -N 0.1 -S 0 -G $GPU_INPUT -C $CPU_INPUT -f ${1} CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF \
		GPU_STEAL_PROB=${2} CPU_STEAL_PROB=${3} NB_CONFL_GPU_BUFFER=$NB_CONFL_GPU_BUFFER \
		CONFL_SPACE=$CONFL_SPACE -X $CPU_TIME
	if [ $? -ne 0 ]
	then
		echo "ERROR!!!! retrying 1"
		timeout 90s ./memcd -n $CPU_THREADS -l 8 -b $GPU_BLOCKS -x $GPU_THREADS -T 1 -a $DATASET \
		-d $DURATION -N 0.1 -S 0 -G $GPU_INPUT -C $CPU_INPUT -f ${1} CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF \
		GPU_STEAL_PROB=${2} CPU_STEAL_PROB=${3} NB_CONFL_GPU_BUFFER=$NB_CONFL_GPU_BUFFER \
		CONFL_SPACE=$CONFL_SPACE -X $CPU_TIME
	fi
	if [ $? -ne 0 ]
	then
		echo "ERROR!!!! retrying 2"
		timeout 90s ./memcd -n $CPU_THREADS -l 8 -b $GPU_BLOCKS -x $GPU_THREADS -T 1 -a $DATASET \
		-d $DURATION -N 0.1 -S 0 -G $GPU_INPUT -C $CPU_INPUT -f ${1} CPU_BACKOFF=$CPU_BACKOFF GPU_BACKOFF=$GPU_BACKOFF \
		GPU_STEAL_PROB=${2} CPU_STEAL_PROB=${3} NB_CONFL_GPU_BUFFER=$NB_CONFL_GPU_BUFFER \
		CONFL_SPACE=$CONFL_SPACE -X $CPU_TIME
	fi
	if [ $? -ne 0 ]
	then
		echo "ERROR!!!! no line produced"
	fi
}

function runForTimeBudget {
	rm -f cache_*
	# CPU_TIME=0.001
	# actualRun GPUsteal 0.0 ${1}
	# CPU_TIME=0.003
	# actualRun GPUsteal 0.0 ${1}
	CPU_TIME=0.005
	actualRun GPUsteal 0.0 ${1}
	CPU_TIME=0.008
	actualRun GPUsteal 0.0 ${1}
	### 128 k
	CPU_TIME=0.012
	actualRun GPUsteal 0.0 ${1}
	CPU_TIME=0.016
	actualRun GPUsteal 0.0 ${1}
	### 256 k
	CPU_TIME=0.02
	actualRun GPUsteal 0.0 ${1}
	CPU_TIME=0.025
	actualRun GPUsteal 0.0 ${1}
	### 512 k
	CPU_TIME=0.03
	actualRun GPUsteal 0.0 ${1}
	### 1M
	CPU_TIME=0.05
	actualRun GPUsteal 0.0 ${1}
	CPU_TIME=0.08
	actualRun GPUsteal 0.0 ${1}
	# CPU_TIME=0.05
	# actualRun GPUsteal ${1} 0.0
}

### TODO: no longer use REQUEST_GRANULARITY
# --> prob of stealing (at the begining of the batch)
#    CPU steal 10% of batches, 20%, 30%, 50%, 80% 100%
#    GPU steal 10% of batches, 20%, 30%, 50%, 80% 100%

# SETs (0.1%)/GETs(99.9%) (DELETEs next paper)
# -------------------
# CPU --> do round-robin
# GPU --> do the same --> the change is complecated

# reduces the load in one device, it goes into the shared queue
function doRun_HeTM_SHARED_steal {
	# # BANK_PART=3 --> unif rand
	# make clean ; make CMP_TYPE=COMPRESSED BANK_PART=7 \
	# 	PR_MAX_RWSET_SIZE=20 LOG_TYPE=VERS USE_TSX_IMPL=1 PROFILE=1 -j 14 \
	# 	BENCH=MEMCD CPU_STEAL_ONLY_GETS=0 DISABLE_NON_BLOCKING=1 \
	# 	LOG_SIZE=4096 STM_LOG_BUFFER_SIZE=256 \
	# 	BMAP_GRAN_BITS=13 OVERLAP_CPY_BACK=0 >/dev/null
	# # make clean ; make CMP_TYPE=COMPRESSED BANK_PART=3 \
	# # 	PR_MAX_RWSET_SIZE=20 LOG_TYPE=${2} USE_TSX_IMPL=1 PROFILE=1 -j 14 \
	# # 	BENCH=MEMCD CPU_STEAL_ONLY_GETS=0 >/dev/null
	# for s in `seq 1 $SAMPLES`
	# do
	# 	runForTimeBudget 0.0
	# 	###
	# 	mv GPUsteal ${1}_VERS_blocking_no_confl_s${s}
	# 	###
	# 	###
	# 	runForTimeBudget 1.0
	# 	###
	# 	mv GPUsteal ${1}_VERS_blocking_confl_s${s}
	# 	###
	# 	###
	# 	runForTimeBudget 0.1
	# 	###
	# 	mv GPUsteal ${1}_VERS_blocking_01_confl_s${s}
	# 	###
	# 	###
	# 	runForTimeBudget 0.5
	# 	###
	# 	mv GPUsteal ${1}_VERS_blocking_05_confl_s${s}
	# done
	./compile.sh opt \
		CMP_TYPE=COMPRESSED \
		BANK_PART=7 \
		PR_MAX_RWSET_SIZE=200 \
		USE_TSX_IMPL=0 \
		PROFILE=1 -j 14 \
		BENCH=MEMCD \
		CPU_STEAL_ONLY_GETS=0 \
		DISABLE_NON_BLOCKING=0 \
		DISABLE_EARLY_VALIDATION=1 \
		LOG_SIZE=4096 \
		STM_LOG_BUFFER_SIZE=256 \
		BMAP_GRAN_BITS=13 \
		BMAP_ENC_1BIT=1 \
		HETM_NB_DEVICES=${2} \
		>/dev/null
	# make clean ; make CMP_TYPE=COMPRESSED BANK_PART=3 \
	# 	PR_MAX_RWSET_SIZE=20 LOG_TYPE=${2} USE_TSX_IMPL=1 PROFILE=1 -j 14 \
	# 	BENCH=MEMCD CPU_STEAL_ONLY_GETS=0 >/dev/null
	for s in `seq 1 $SAMPLES`
	do
		runForTimeBudget 0.0
		###
		mv GPUsteal ${1}_${2}GPU_no_confl_s${s}
		###
		###
		runForTimeBudget 0.2
		###
		mv GPUsteal ${1}_${2}GPU_02_confl_s${s}
		###
		###
		runForTimeBudget 0.8
		###
		mv GPUsteal ${1}_${2}GPU_08_confl_s${s}
		###
		###
		runForTimeBudget 1.0
		###
		mv GPUsteal ${1}_${2}GPU_confl_s${s}
	done
}

function doRun_GPUonly {
	./compile.sh opt \
		CMP_TYPE=COMPRESSED \
		BANK_PART=7 \
		PR_MAX_RWSET_SIZE=200 \
		USE_TSX_IMPL=0 \
		PROFILE=1 -j 14 \
		BENCH=MEMCD \
		DISABLE_RS=1 \
		DISABLE_WS=1 \
		CPU_STEAL_ONLY_GETS=0 \
		DISABLE_NON_BLOCKING=0 \
		LOG_SIZE=4096 \
		STM_LOG_BUFFER_SIZE=256 \
		DISABLE_EARLY_VALIDATION=1 \
		BMAP_ENC_1BIT=1 \
		HETM_CPU_EN=0 \
		BMAP_GRAN_BITS=13 \
		HETM_NB_DEVICES=1 >/dev/null

		for s in `seq 1 $SAMPLES`
		do
			runForTimeBudget 0.0 
			mv GPUsteal ${1}_GPUonly_s${s}
		done
		# for s in `seq 1 $SAMPLES`
		# do
		# 	CPU_TIME=0.03
		# 	actualRun GPUload 0.0 0.0
		# 	mv GPUload ${1}_GPUonly_s${s}

		# 	tail -n1 ${1}_GPUonly_s${s} > /tmp/line
		# 	for i in $(seq 8)
		# 	do
		# 		cat /tmp/line >> ${1}_GPUonly_s${s}
		# 	done
		# done
}

function doRun_CPUonly {
	./compile.sh opt \
		CMP_TYPE=COMPRESSED \
		BANK_PART=7 \
		PR_MAX_RWSET_SIZE=200 \
		USE_TSX_IMPL=0 \
		PROFILE=1 -j 14 \
		BENCH=MEMCD \
		INST_CPU=0 \
		CPU_STEAL_ONLY_GETS=0 \
		DISABLE_NON_BLOCKING=0 \
		LOG_SIZE=4096 \
		STM_LOG_BUFFER_SIZE=256 \
		HETM_GPU_EN=0 \
		DISABLE_EARLY_VALIDATION=1 \
		BMAP_ENC_1BIT=1 \
		BMAP_GRAN_BITS=13 \
		HETM_NB_DEVICES=1 >/dev/null
	for s in `seq 1 $SAMPLES`
	do
		runForTimeBudget 0.0 
		mv GPUsteal ${1}_CPUonly_s${s}
	done
	# for s in `seq 1 $SAMPLES`
	# do
	# 	### 64 k
	# 	CPU_TIME=0.03
	# 	actualRun CPUload 0.0 0.0
	# 	mv CPUload ${1}_CPUonly_s${s}

	# 	tail -n1 ${1}_CPUonly_s${s} > /tmp/line
	# 	for i in $(seq 8)
	# 	do
	# 		cat /tmp/line >> ${1}_CPUonly_s${s}
	# 	done
	# done
}

# DATASET=$LARGE_DATASET
# CONFL_SPACE=$L_CONFL_SPACE
DATASET=$SMALL_DATASET
CONFL_SPACE=$S_CONFL_SPACE

doRun_HeTM_SHARED_steal memcd_LARGE 1
doRun_HeTM_SHARED_steal memcd_LARGE 2
doRun_HeTM_SHARED_steal memcd_LARGE 3
doRun_HeTM_SHARED_steal memcd_LARGE 4

doRun_GPUonly memcd_LARGE
doRun_CPUonly memcd_LARGE

################################
# DATASET=$SMALL_DATASET
# CONFL_SPACE=$S_CONFL_SPACE
#
# doRun_HeTM_SHARED_steal memcd_SMALL
#
# doRun_GPUonly memcd_SMALL
# doRun_CPUonly memcd_SMALL
################################

mkdir -p DATA_memcdBatchDuration
mv memcd_SMALL*_s* DATA_memcdBatchDuration
mv memcd_LARGE*_s* DATA_memcdBatchDuration

# ./compile.sh opt \
# 		CMP_TYPE=COMPRESSED \
# 		BANK_PART=7 \
# 		PR_MAX_RWSET_SIZE=40 \
# 		USE_TSX_IMPL=0 \
# 		PROFILE=1 -j 14 \
# 		BENCH=MEMCD \
# 		CPU_STEAL_ONLY_GETS=0 \
# 		DISABLE_NON_BLOCKING=0 \
# 		LOG_SIZE=4096 \
# 		STM_LOG_BUFFER_SIZE=256 \
# 		BMAP_GRAN_BITS=13 \
# 		DISABLE_EARLY_VALIDATION=0 \
# 		HETM_NB_DEVICES=1 \
# 		>/dev/null

# CPU_TIME=0.001
# actualRun GPUsteal_1GPU 0.0 0.0
# CPU_TIME=0.1
# actualRun GPUsteal_1GPU 0.0 0.0

# ./compile.sh opt \
# 		CMP_TYPE=COMPRESSED \
# 		BANK_PART=7 \
# 		PR_MAX_RWSET_SIZE=40 \
# 		USE_TSX_IMPL=0 \
# 		PROFILE=1 -j 14 \
# 		BENCH=MEMCD \
# 		CPU_STEAL_ONLY_GETS=0 \
# 		DISABLE_NON_BLOCKING=0 \
# 		LOG_SIZE=4096 \
# 		STM_LOG_BUFFER_SIZE=256 \
# 		BMAP_GRAN_BITS=13 \
# 		DISABLE_EARLY_VALIDATION=0 \
# 		HETM_NB_DEVICES=2 \
# 		>/dev/null

# CPU_TIME=0.001
# actualRun GPUsteal_2GPU 0.0 0.0
# CPU_TIME=0.1
# actualRun GPUsteal_2GPU 0.0 0.0

