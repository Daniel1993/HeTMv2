#ifndef HETM_TYPES_H_GUARD_
#define HETM_TYPES_H_GUARD_

// TODO: this is Benchmark stuff 

/* ################################################################### *
* BANK ACCOUNTS
* ################################################################### */
typedef int /*__attribute__((aligned (64)))*/ account_t;

typedef struct bank {
  account_t *accounts;
  account_t *devAccounts;
  long size;
} bank_t;

// #define MEMCD_STATS 1

#ifdef MEMCD_STATS

#include "memman.hpp"

typedef struct memcd_stats_
{
  unsigned long long int nb_GETs;
  unsigned long long int nb_SETs;
  unsigned long long int cache_hits_GETs;
  unsigned long long int cache_hits_SETs;
} memcd_stats_s;

#define PRINT_STATS() ({ \
  memcd_stats_s *cpu = (memcd_stats_s*)memcd_stats_CPU.GetMemObj(0)->host; \
  memcd_stats_s gpu; \
  gpu.nb_GETs = 0; \
  gpu.nb_SETs = 0; \
  gpu.cache_hits_GETs = 0; \
  gpu.cache_hits_SETs = 0; \
  for (int j = 0; j < HETM_NB_DEVICES; ++j) { \
    memcd_stats_s *gpuJ = (memcd_stats_s*)memcd_stats_GPU.GetMemObj(j)->host; \
    memcd_stats_GPU.GetMemObj(j)->CpyDtH(); \
    gpu.nb_GETs += gpuJ->nb_GETs; \
    gpu.nb_SETs += gpuJ->nb_SETs; \
    gpu.cache_hits_GETs += gpuJ->cache_hits_GETs; \
    gpu.cache_hits_SETs += gpuJ->cache_hits_SETs; \
  } \
  printf("TODO\n"); \
})

#endif /* MEMCD_STATS */

typedef struct memcd {
	account_t *key;   /* keys in global memory --> 4B */
  account_t *extraKey; /* 3*4B */
	account_t *val;   /* values in global memory --> 4B */
	account_t *extraVal;   /* 7*4B */
	account_t *ts_CPU;    /* last access TS in global memory */
	account_t *ts_GPU;    /* last access TS in global memory */
	account_t *state; /* state in global memory */
	account_t *setUsage; /* state in global memory */
	unsigned *globalTs;
  long nbSets;
  int nbWays;
#ifdef MEMCD_STATS
	memcd_stats_s stats;
#endif
} memcd_t;

typedef struct packet {
	int vers;
	long key;
} packet_t;

#endif /* HETM_TYPES_H_GUARD_ */
