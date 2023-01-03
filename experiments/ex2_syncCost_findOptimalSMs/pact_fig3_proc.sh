#!/bin/bash

REMOTE_NODE=pascal
USER=dcastro

if [[ $# -gt 0 ]] ; then
	REMOTE_NODE=$1
fi

TARGET_FOLDER=/Users/daniel/Documents/Data/HeTM_2022_July_extention/4GPUS/no_conf_SMs
OLD_FOLDER=/Users/daniel/Documents/Data/HeTM_2022_July_extention/2GPUS/2022Sep_no_conf_OLD
#REMOTE_FOLDER=/home/dcastro/projs/HeTM_V2/benches/bank/data/no_inter_confl_SMs
REMOTE_FOLDER=/home/dcastro/projs/HeTM_V2/experiments/ex2_syncCost_findOptimalSMs/data/no_inter_confl_SMs
REMOTE_FOLDER_OLD=/home/dcastro/projs/HeTM_V0/bank/data/no_conf
source ../aux_files/vars.sh
mkdir -p $DATA_FOLDER
# mkdir -p $OLD_FOLDER/$EXPERIMENT_FOLDER
scp $REMOTE_NODE:$REMOTE_FOLDER/* $DATA_FOLDER
# scp $REMOTE_NODE:$REMOTE_FOLDER_OLD/* $OLD_FOLDER/$EXPERIMENT_FOLDER

source pact_fig3_proc_loc_mac.sh

