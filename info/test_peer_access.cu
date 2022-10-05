#include <cstdlib>
#include <cstdio>
#include <cuda.h>
#include <numa.h>
#include <cassert>

using namespace std;

#define NB_DEVICES 4
#define CUDA_CHECK_ERROR(func, msg) ({ \
	cudaError_t cudaError; \
	if (cudaSuccess != (cudaError = func)) { \
		fprintf(stderr, #func ": in " __FILE__ ":%i : " msg "\n   > %s\n", \
		__LINE__, cudaGetErrorString(cudaError)); \
    *((int*)0x0) = 0; /* exit(-1); */ \
	} \
  cudaError; \
})
#define FOR_EACH_DEVI(...) do { for (size_t devi = 0; devi < NB_DEVICES; devi++) { \
  CUDA_CHECK_ERROR(cudaSetDevice(devi), ""); \
  __VA_ARGS__; \
} } while(false)
#define FOR_EACH_DEVI_PAIR(...) do { for (size_t dev1 = 0; dev1 < NB_DEVICES; dev1++) { \
  CUDA_CHECK_ERROR(cudaSetDevice(dev1), ""); \
  for (size_t dev2 = 0; dev2 < NB_DEVICES; dev2++) { \
    if (dev1 != dev2) { __VA_ARGS__; } \
} } } while(false)
#define CUDA_UNIF_MEM_ALLOC(ptr, size) \
	CUDA_CHECK_ERROR(cudaMallocManaged((void**)&(ptr), size), \
		"[cudaMallocManaged]: failed for " #ptr);
#define CUDA_DEV_ALLOC(ptr, size) \
	CUDA_CHECK_ERROR(cudaMalloc((void**)&(ptr), size), \
		"[cudaMalloc]: failed for " #ptr);
#define CUDA_HOST_ALLOC(ptr, size) \
	CUDA_CHECK_ERROR(cudaMallocHost((void**)&(ptr), size), \
		"[cudaMallocHost]: failed for " #ptr);
// In different GPUs
#define CUDA_CPY_PtP_ASYNC(dst, dev1, src, dev2, size, stream) \
	CUDA_CHECK_ERROR(cudaMemcpyPeerAsync((void*)(dst), (int)(dev1), (void*)(src), (int)(dev2), size, \
	(cudaStream_t)stream), "[cudaMemcpyPeer]: failed for " \
		#dev2 " --> " #dev1)
// In different GPUs
#define CUDA_CPY_PtP(dst, dev1, src, dev2, size) \
	CUDA_CHECK_ERROR(cudaMemcpyPeer((void*)(dst), (int)(dev1), (void*)(src), (int)(dev2), \
	size), "[cudaMemcpyPeer]: failed for " \
		#dev2 " --> " #dev1)
#define CUDA_EVENT_RECORD(ev, stream)        if (ev) { CUDA_CHECK_ERROR(cudaEventRecord(ev, stream), ""); }
#define CUDA_EVENT_ELAPSED_TIME(reg, e1, e2) if (e1 && e2) { CUDA_CHECK_ERROR(cudaEventElapsedTime(reg, e1, e2), ""); } else { *(reg) = 0; }
#define CUDA_EVENT_SYNCHRONIZE(ev)           if (ev) { CUDA_CHECK_ERROR(cudaEventSynchronize(ev), ""); }

static int peerCpyAvailable[NB_DEVICES*NB_DEVICES];

static void initGPUPeerCpy()
{
  int nGPUs = NB_DEVICES;
  int nbOfGPUs = NB_DEVICES;
  CUDA_CHECK_ERROR(cudaGetDeviceCount(&nbOfGPUs), "");
  for (int j = 0; j < nGPUs; ++j) {
    peerCpyAvailable[j*nGPUs + j] = 1;
    for (int k = j+1; k < nGPUs; ++k) {
      int coord1 = j*nGPUs + k, coord2 = k*nGPUs + j;
      int coord1Real = (j%nbOfGPUs)*nGPUs + (k%nbOfGPUs);
      int coord2Real = (k%nbOfGPUs)*nGPUs + (j%nbOfGPUs);
      if (coord1 == coord1Real && coord2 == coord2Real) {
        CUDA_CHECK_ERROR(cudaDeviceCanAccessPeer(&(peerCpyAvailable[coord1]), j, k), "");
        CUDA_CHECK_ERROR(cudaDeviceCanAccessPeer(&(peerCpyAvailable[coord2]), k, j), "");
        if (peerCpyAvailable[coord1]) {
          CUDA_CHECK_ERROR(cudaSetDevice(j), "");
          CUDA_CHECK_ERROR(cudaDeviceEnablePeerAccess(k, 0), "");
        }
        if (peerCpyAvailable[coord2]) {
          CUDA_CHECK_ERROR(cudaSetDevice(k), "");
          CUDA_CHECK_ERROR(cudaDeviceEnablePeerAccess(j, 0), "");
        }
      } else {
        peerCpyAvailable[coord1] = peerCpyAvailable[coord1Real];
        peerCpyAvailable[coord2] = peerCpyAvailable[coord2Real];
      }
    }
  }
}

static void destroyGPUPeerCpy()
{
  int nGPUs = NB_DEVICES;
  int nbOfGPUs = NB_DEVICES;
  
  for (int j = 0; j < nGPUs; ++j)
  {
    peerCpyAvailable[j*nGPUs + j] = 1;
    for (int k = j+1; k < nGPUs; ++k)
    {
      int coord1 = j*nGPUs + k, coord2 = k*nGPUs + j;
      int coord1Real = (j%nbOfGPUs)*nGPUs + (k%nbOfGPUs);
      int coord2Real = (k%nbOfGPUs)*nGPUs + (j%nbOfGPUs);
      if (coord1 == coord1Real && coord2 == coord2Real)
      {
        if (peerCpyAvailable[coord1])
        {
          CUDA_CHECK_ERROR(cudaSetDevice(j), "");
          CUDA_CHECK_ERROR(cudaDeviceDisablePeerAccess(k), "");
        }
        if (peerCpyAvailable[coord2])
        {
          CUDA_CHECK_ERROR(cudaSetDevice(k), "");
          CUDA_CHECK_ERROR(cudaDeviceDisablePeerAccess(j), "");
        }
      }
    }
  }
}

int main()
{
  assert(sizeof(unsigned char) == 1 && "cannot work with this wsize");
  unsigned char *devSrcMem[NB_DEVICES];
  unsigned char *devDstMem[NB_DEVICES];
  const size_t SIZE_MEM = 1L<<30;
  cudaEvent_t ev1[NB_DEVICES];
  cudaEvent_t ev2[NB_DEVICES];
  cudaStream_t strm[NB_DEVICES];
  float reg;

  initGPUPeerCpy();

  FOR_EACH_DEVI(
    CUDA_CHECK_ERROR(cudaStreamCreate(&strm[devi]), "");
    CUDA_CHECK_ERROR(cudaEventCreate(&ev1[devi]), "");
    CUDA_CHECK_ERROR(cudaEventCreate(&ev2[devi]), "");
    CUDA_DEV_ALLOC(devSrcMem[devi], SIZE_MEM);
    CUDA_DEV_ALLOC(devDstMem[devi], SIZE_MEM*NB_DEVICES);
  );
  
  FOR_EACH_DEVI_PAIR(
    CUDA_EVENT_RECORD(ev1[dev1], strm[dev1]);
    CUDA_CPY_PtP_ASYNC(devDstMem[dev1]+dev2*SIZE_MEM, dev1, devSrcMem[dev2], dev2, SIZE_MEM, strm[dev1]);
    CUDA_EVENT_RECORD(ev2[dev1], strm[dev1]);
    CUDA_EVENT_SYNCHRONIZE(ev1[dev1]);
    CUDA_EVENT_SYNCHRONIZE(ev2[dev1]);
    CUDA_EVENT_ELAPSED_TIME(&reg, ev1[dev1], ev2[dev1]);
    printf("elapsed time = %fms\n", reg);
  );
  
  FOR_EACH_DEVI(
    cudaStreamDestroy(strm[devi]);
    cudaFree(devSrcMem[devi]);
    cudaFree(devDstMem[devi]);
  );
  destroyGPUPeerCpy();
  return EXIT_SUCCESS;
}
