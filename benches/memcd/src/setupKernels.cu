#include "hetm-log.h"

#include "setupKernels.cuh"
#include "cmp_kernels.cuh"
#include "bankKernel.cuh"
#include "bank.hpp"

#include "memman.hpp"

using namespace memman;
using namespace knlman;

KnlObj *HeTM_finalTxLog2;
KnlObj *HeTM_bankTx;
KnlObj *HeTM_memcdWriteTx;
KnlObj *HeTM_memcdReadTx;
MemObjOnDev HeTM_bankTxEntryObj;
MemObjOnDev HeTM_bankTxInput;
MemObjOnDev HeTM_memcdTx_input;
MemObjOnDev memcd_global_ts;

static void run_memcdReadTx(knlman_callback_params_s params);
static void run_memcdWriteTx(knlman_callback_params_s params);
static void run_finalTxLog2(knlman_callback_params_s params);

int HeTM_setup_memcdWriteTx(int nbBlocks, int nbThreads, int ways, int sets)
{
  PR_global_data_s *d;

  for (int j = 0; j < Config::GetInstance()->NbGPUs(); j++)
  {
    MemObjBuilder b;
    MemObj *m;
    Config::GetInstance()->SelDev(j);
    PR_curr_dev = j;
    d = &(PR_global[PR_curr_dev]);
    d->PR_blockNum = nbBlocks;
    d->PR_threadNum = nbThreads;
    m = new MemObj(b
      .SetOptions(0)
      ->SetSize(sizeof(HeTM_memcdTx_input_s))
      ->AllocDevPtr()
      ->AllocHostPtr(),
      j
    );
    HeTM_memcdTx_input.AddMemObj(m);
    ((HeTM_memcdTx_input_s*)(m->host))->nbWays = ways;
    ((HeTM_memcdTx_input_s*)(m->host))->nbSets = sets;
  }
  KnlObjBuilder b;
  HeTM_memcdWriteTx = new KnlObj(b
    .SetCallback(run_memcdWriteTx)
    ->SetEntryObj(&HeTM_memcdTx_input));
  return 0;
}

int HeTM_setup_memcdReadTx(int nbBlocks, int nbThreads, int ways, int sets)
{
  PR_global_data_s *d;
  for (int j = 0; j < HETM_NB_DEVICES; j++) {
    PR_curr_dev = j;
    d = &(PR_global[PR_curr_dev]);
    d->PR_blockNum = nbBlocks;
    d->PR_threadNum = nbThreads;
  }
  KnlObjBuilder b;
  HeTM_memcdReadTx = new KnlObj(b
    .SetCallback(run_memcdReadTx)
    ->SetEntryObj(&HeTM_memcdTx_input));

  // already set-up HeTM_memcdTx_input

  return 0;
}

int HeTM_bankTx_cpy_IO() // TODO: not used
{
  for (int j = 0; j < Config::GetInstance()->NbGPUs(); ++j)
  {
    Config::GetInstance()->SelDev(j);
    PR_curr_dev = j;
    pr_tx_args_s *pr_args = getPrSTMmetaData(j);
    PR_retrieveIO(pr_args);
  }
  return 0;
}

int HeTM_teardown_bankTx()
{
  delete HeTM_bankTx;
  return 0;
}

int HeTM_teardown_memcdWriteTx()
{
  delete HeTM_memcdWriteTx;
  return 0;
}

int HeTM_teardown_memcdReadTx()
{
  delete HeTM_memcdReadTx;
  return 0; 
}

int HeTM_setup_finalTxLog2()
{
  KnlObjBuilder b;
  HeTM_finalTxLog2 = new KnlObj(b
    .SetCallback(run_finalTxLog2));
  return 0;
}

int HeTM_teardown_finalTxLog2()
{
  // TODO: delete entryObj
  delete HeTM_finalTxLog2;
  return 0;
}

static void run_finalTxLog2(knlman_callback_params_s params)
{
  dim3 blocks(params.blocks.x, params.blocks.y, params.blocks.z);
  dim3 threads(params.threads.x, params.threads.y, params.threads.z);
  HeTM_knl_finalTxLog2_s *data = (HeTM_knl_finalTxLog2_s*)params.entryObj;

  /* Kernel Launch */
  HeTM_knl_finalTxLog2 <<< blocks, threads >>> (*data);

  // HeTM_knl_finalTxLog2<<<blocks, threads>>>(data->knlArgs);
}

static void run_memcdReadTx(knlman_callback_params_s params)
{
  HeTM_memcdTx_input_s *data = (HeTM_memcdTx_input_s*)(HeTM_memcdTx_input.GetMemObj(params.devId)->host); // TODO
  // cuda_t *d = data->knlArgs.d;
  int nbSets, nbWays;
  pr_buffer_s inBuf, outBuf;
  HeTM_memcdTx_input_s *input, *inputDev;
  nbSets = parsedData.num_sets;
  nbWays = parsedData.num_ways;
  size_t cacheSize = nbSets*nbWays;

  assert(nbWays > 0);

  // thread_local static unsigned short seed = 1234;

  for (int j = 0; j < HETM_NB_DEVICES; ++j)
  {
    Config::GetInstance()->SelDev(j);
    PR_curr_dev = j;

    // memman_ad_hoc_free(NULL); // empties the previous parameters
    // cudaFuncSetCacheConfig(memcdReadTx, cudaFuncCachePreferL1);

    memman::MemObj *m_input = HeTM_memcdTx_input.GetMemObj(j);
    input = (HeTM_memcdTx_input_s*)m_input->host;
    inputDev = (HeTM_memcdTx_input_s*)m_input->dev;

    input->key        = (int*)HeTM_mempool.GetMemObj(j)->dev;
    // TODO: /sizeof(...)
    input->extraKey   = input->key + cacheSize;
    input->val        = input->extraKey + 3*cacheSize;
    input->extraVal   = input->val + cacheSize;
    input->ts_CPU     = input->extraVal + 7*cacheSize;
    input->ts_GPU     = input->ts_CPU + cacheSize;
    input->state      = input->ts_GPU + cacheSize;
    input->setUsage   = input->state + cacheSize;
    input->nbSets     = nbSets;
    input->nbWays     = nbWays;
    input->input_keys = GPUInputBuffer[j];
    input->input_vals = GPUInputBuffer[j];
    input->output     = (memcd_get_output_t*)GPUoutputBuffer[j];

    input->curr_clock = (int*)memcd_global_ts.GetMemObj(j)->dev;
    m_input->CpyHtD(HeTM_memStream2[j]);

    // TODO:
    // inputDev = (HeTM_memcdTx_input_s*)memman_ad_hoc_alloc(NULL, &input, sizeof(HeTM_memcdTx_input_s));
    // memman_ad_hoc_cpy(NULL);

    PR_curr_dev = j;
    // printf("memcdReadTx\n");
    // TODO: change PR-STM to use knlman
    inBuf.buf = (void*)inputDev;
    inBuf.size = sizeof(HeTM_memcdTx_input_s);
    outBuf.buf = NULL;
    outBuf.size = 0;
    pr_tx_args_s *pr_args = getPrSTMmetaData(j);
    PR_prepareIO(pr_args, inBuf, outBuf);
    // CUDA_CHECK_ERROR(cudaDeviceSynchronize(), ""); // sync the previous run
    PR_run(memcdReadTx, pr_args);
  }
  for (int j = 0; j < HETM_NB_DEVICES; ++j)
  {
    Config::GetInstance()->SelDev(j);
    CUDA_CHECK_ERROR(cudaDeviceSynchronize(), "");
  }
}

static void run_memcdWriteTx(knlman_callback_params_s params)
{
  HeTM_memcdTx_input_s *data = (HeTM_memcdTx_input_s*)(HeTM_memcdTx_input.GetMemObj(params.devId)->host); // TODO
  int nbSets, nbWays;
  pr_buffer_s inBuf, outBuf;
  HeTM_memcdTx_input_s *input, *inputDev;
  nbSets = data->nbSets;
  nbWays = data->nbWays;
  size_t cacheSize = nbSets*nbWays;

  assert(nbWays > 0);

  for (int j = 0; j < HETM_NB_DEVICES; ++j)
  {
    // cudaFuncSetCacheConfig(memcdWriteTx, cudaFuncCachePreferL1);

    memman::MemObj *m_input = HeTM_memcdTx_input.GetMemObj(j);
    input = (HeTM_memcdTx_input_s*)m_input->host;
    inputDev = (HeTM_memcdTx_input_s*)m_input->dev;

    input->key        = (int*)HeTM_mempool.GetMemObj(j)->dev;
    input->extraKey   = input->key + cacheSize;
    input->val        = input->extraKey + 3*cacheSize;
    input->extraVal   = input->val + cacheSize;
    input->ts_CPU     = input->extraVal + 7*cacheSize;
    input->ts_GPU     = input->ts_CPU + cacheSize;
    input->state      = input->ts_GPU + cacheSize;
    input->setUsage   = input->state + cacheSize;
    input->nbSets     = nbSets;
    input->nbWays     = nbWays;
    input->input_keys = GPUInputBuffer[j];
    input->input_vals = GPUInputBuffer[j];
    input->output     = (memcd_get_output_t*)GPUoutputBuffer[j];

    input->curr_clock = (int*)memcd_global_ts.GetMemObj(j)->dev;
    m_input->CpyHtD(HeTM_memStream2[j]);

    // TODO: change PR-STM to use knlman
    PR_curr_dev = j;
    // printf("memcdWriteTx %i\n", j);
    inBuf.buf = (void*)inputDev;
    inBuf.size = sizeof(HeTM_memcdTx_input_s);
    outBuf.buf = NULL;
    outBuf.size = 0;
    pr_tx_args_s *pr_args = getPrSTMmetaData(j);
    PR_prepareIO(pr_args, inBuf, outBuf);
    // CUDA_CHECK_ERROR(cudaDeviceSynchronize(), "");
    PR_run(memcdWriteTx, pr_args);
    // printf("END_memcdWriteTx %i\n", j);
  }
  for (int j = 0; j < HETM_NB_DEVICES; ++j)
  {
    Config::GetInstance()->SelDev(j);
    CUDA_CHECK_ERROR(cudaDeviceSynchronize(), "");
  }
}
