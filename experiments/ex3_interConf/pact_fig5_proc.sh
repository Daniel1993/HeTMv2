#!/bin/bash

REMOTE_NODE=pascal
USER=dcastro

if [[ $# -gt 0 ]] ; then
	REMOTE_NODE=$1
fi

TARGET_FOLDER=/Users/daniel/Documents/Data/HeTM_2022_July_extention/2GPUS/inter_conf
REMOTE_FOLDER=/home/dcastro/projs/HeTM_V1/benches/bank/data/inter_conf
source ../aux_files/vars.sh
mkdir -p $DATA_FOLDER
scp $REMOTE_NODE:$REMOTE_FOLDER/* $DATA_FOLDER

source pact_fig5_proc_loc_mac.sh

