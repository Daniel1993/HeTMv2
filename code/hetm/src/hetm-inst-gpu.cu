// to generate the executable add the object hetm-internal.o
// it includes intrumentation implementation for Tiny and PR-STM
#include "hetm-log.h"
#include "pr-stm-wrapper.cuh"

// TODO: check if needed 
// #include "pr-stm-track-rwset.cuh"

PR_DEVICE void PR_beforeKernel_EXT(PR_txCallDefArgs) { }
PR_DEVICE void PR_afterKernel_EXT (PR_txCallDefArgs) { }
PR_DEVICE void PR_beforeBegin_EXT (PR_txCallDefArgs) { }
PR_DEVICE void PR_afterCommit_EXT (PR_txCallDefArgs) { }

PR_DEVICE void PR_after_val_locks_EXT (PR_args_s *args)
{
#if HETM_CMP_TYPE == HETM_CMP_DISABLED
/* empty */
#else /* HETM_CMP_TYPE != HETM_CMP_DISABLED */
	int i;
	HeTM_GPU_log_s *GPU_log = (HeTM_GPU_log_s*)args->pr_args_ext;
	// printf("[%i] size RS = %zu size WS = %zu\n", args->tid, args->rset.size, args->wset.size);
#ifndef HETM_DISABLE_RS
	PR_AFTER_VAL_LOCKS_GATHER_READ_SET(i, GPU_log); // TODO: only with more than 1 device
#endif
	// expands to:
	// for (i = 0; i < args->rset.size; i++) {
	// 	// SET_ON_RS_BMAP(args->rset.addrs[i], GPU_log);
	// 	unsigned long pos = ((uintptr_t)(args->rset.addrs[i]) - (uintptr_t)((GPU_log)->devMemPoolBasePtr)) >> (PR_LOCK_GRAN_BITS+HETM_REDUCED_RS);
	// 	unsigned long posCache = pos >> BMAP_GRAN_BITS;
	// 	/* printf("set on READ SET pos %li posCache %li in %p\n", pos, posCache, (_GPU_log)->bmap_rset_devptr); */
	// 	SET_ON_RS_BMAP_AUX(pos, GPU_log);
	// 	SET_ON_RS_BMAP_CACHE_AUX(posCache, GPU_log)
	// }

	#ifndef HETM_DISABLE_WS
	PR_AFTER_VAL_LOCKS_GATHER_WRITE_SET(i, GPU_log);
	#endif
	// expands to:
	// for (i = 0; i < args->wset.size; i++) {
	// 	SET_ON_RS_BMAP(args->wset.addrs[i]);
	// 	SET_ON_WS_BMAP(args->wset.addrs[i]);
	// }
#endif /* HETM_CMP_TYPE == HETM_CMP_DISABLED */
}

PR_DEVICE void PR_after_writeback_EXT (PR_args_s *args, int i, PR_GRANULE_T *addr, PR_GRANULE_T val) { }



