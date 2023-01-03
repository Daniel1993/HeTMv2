#include "bank.hpp"
#include "hetm-cmp-kernels.cuh"
#include "bank_aux.h"
#include "memman.hpp"
#include "memcd.h"
#include "unistd.h"
#include "CheckAllFlags.h"

#include "zipf_dist.h"

using namespace memman;

thread_data_t parsedData;
int isInterBatch = 0;
size_t accountsSize;
size_t sizePool;
void* gpuMempool[HETM_NB_DEVICES];

size_t currMaxCPUoutputBufferSize, currCPUoutputBufferPtr = 0;
size_t maxGPUoutputBufferSize;
size_t size_of_GPU_input_buffer, size_of_CPU_input_buffer;
int lockOutputBuffer = 0;

FILE *GPU_input_file = NULL;
FILE *CPU_input_file = NULL;

extern MemObjOnDev GPU_input_buffer_good;
extern MemObjOnDev GPU_input_buffer_bad;
extern MemObjOnDev GPU_input_buffer;
extern MemObjOnDev GPU_output_buffer;

extern int *GPUoutputBuffer[HETM_NB_DEVICES];
extern int *CPUoutputBuffer;
extern int *GPUInputBuffer[HETM_NB_DEVICES];
extern int *CPUInputBuffer;

void GPUbufferReadFromFile_NO_CONFLS()
{
  int buffer_last = size_of_GPU_input_buffer/sizeof(int);
  GPU_input_file = fopen(parsedData.GPUInputFile, "r");
  int nbGPUs = Config::GetInstance()->NbGPUs();

  for (int j = 0; j < nbGPUs; ++j)
  {
    int *cpu_ptr = (int*)GPU_input_buffer_good.GetMemObj(j)->host;

    // unsigned rnd = 12345723; //RAND_R_FNC(input_seed);
    unsigned rnd; // = (*zipf_dist)(generator);
    for (int i = 0; i < buffer_last; ++i) {
      if (fscanf(GPU_input_file, "%i\n", &rnd) == EOF) {
        printf("ERROR GPU reached end-of-file at %i / %i\n", i, buffer_last);
      }
      rnd = (rnd % parsedData.CONFL_SPACE);
      int mod = rnd % 3;
      cpu_ptr[i] = (rnd - mod) + 2; // gives always 2 (mod 3) //2*i;//
    }

    cpu_ptr = (int*)GPU_input_buffer_bad.GetMemObj(j)->host;
    for (int i = 0; i < buffer_last; ++i) {
      if (fscanf(GPU_input_file, "%i\n", &rnd) == EOF) {
        printf("ERROR GPU reached end-of-file at %i / %i\n", i, buffer_last);
      }
      rnd = (rnd % parsedData.CONFL_SPACE);
      int mod = rnd % 3;
      cpu_ptr[i] = (rnd - mod) + 1; // gives always 0 (mod 3) //2*i+1;//
    }
  }
}

void CPUbufferReadFromFile_NO_CONFLS() {
  int good_buffers_last = size_of_CPU_input_buffer/sizeof(int);
	int bad_buffers_last = 2*size_of_CPU_input_buffer/sizeof(int);
	CPU_input_file = fopen(parsedData.CPUInputFile, "r");

  for (int i = 0; i < good_buffers_last; ++i) {
		unsigned rnd;
		if (fscanf(CPU_input_file, "%i\n", &rnd) == EOF) {
			printf("ERROR CPU reached end-of-file at %i / %i\n", i, good_buffers_last);
		}
    rnd = (rnd % parsedData.CONFL_SPACE);
		int mod = rnd % 3;
		CPUInputBuffer[i] = (rnd - mod); // 2*i+1;//
	}
	for (int i = good_buffers_last; i < bad_buffers_last; ++i) {
		unsigned rnd;
		if (fscanf(CPU_input_file, "%i\n", &rnd) == EOF) {
			printf("ERROR CPU reached end-of-file at %i / %i\n", i, bad_buffers_last);
		}
    rnd = (rnd % parsedData.CONFL_SPACE);
		int mod = rnd % 3;
		CPUInputBuffer[i] = (rnd - mod) + 1; //2*i;//
	}
}

void GPUbufferReadFromFile_CONFLS()
{
  int buffer_last = size_of_GPU_input_buffer/sizeof(int);
	GPU_input_file = fopen(parsedData.GPUInputFile, "r");

	// if (zipf_dist == NULL) {
	// 	generator.seed(input_seed);
	// 	zipf_dist = new zipf_distribution<int, double>(parsedData.nb_accounts * parsedData.num_ways);
	// }

  int nbGPUs = Config::GetInstance()->NbGPUs();
  for (int j = 0; j < nbGPUs; ++j)
  {
    int *cpu_ptr = (int*)GPU_input_buffer_good.GetMemObj(j)->host;
    unsigned rnd; // = (*zipf_dist)(generator);
    for (int i = 0; i < buffer_last; ++i) {
      if (fscanf(GPU_input_file, "%i\n", &rnd) == EOF) {
        printf("ERROR GPU reached end-of-file at %i / %i\n", i, buffer_last);
      }
      int mod = rnd % 2;
      cpu_ptr[i] = (rnd - mod);//2*i;//
    }

    cpu_ptr = (int*)GPU_input_buffer_bad.GetMemObj(j)->host;

    for (int i = 0; i < buffer_last; ++i) {
      if (fscanf(GPU_input_file, "%i\n", &rnd) == EOF) {
        printf("ERROR GPU reached end-of-file at %i / %i\n", i, buffer_last);
      }
      int mod = rnd % 2;
      cpu_ptr[i] = (rnd - mod) + 1; // gets input from the CPU //2*i+1;//
    }
  }
}

void GPUbufferReadFromFile_UNIF_RAND()
{
  int buffer_last = size_of_GPU_input_buffer/sizeof(int);
	GPU_input_file = fopen(parsedData.GPUInputFile, "r");

	// if (zipf_dist == NULL) {
	// 	generator.seed(input_seed);
	// 	zipf_dist = new zipf_distribution<int, double>(parsedData.nb_accounts * parsedData.num_ways);
	// }

  int nbGPUs = Config::GetInstance()->NbGPUs();
  for (int j = 0; j < nbGPUs; ++j)
  {
    int *cpu_ptr = (int*)GPU_input_buffer_good.GetMemObj(j)->host;
    unsigned rnd; // = (*zipf_dist)(generator);
    for (int i = 0; i < buffer_last; ++i) {
      rnd = rand();
      int mod = rnd % 2;
      cpu_ptr[i] = (rnd - mod);//2*i;//
    }

    cpu_ptr = (int*)GPU_input_buffer_bad.GetMemObj(j)->host;

    for (int i = 0; i < buffer_last; ++i) {
      rnd = rand();
      int mod = rnd % 2;
      cpu_ptr[i] = (rnd - mod) + 1; // gets input from the CPU //2*i+1;//
    }
  }
}

void CPUbufferReadFromFile_CONFLS()
{
  int good_buffers_last = size_of_CPU_input_buffer/sizeof(int);
	int bad_buffers_last = 2*size_of_CPU_input_buffer/sizeof(int);
	CPU_input_file = fopen(parsedData.CPUInputFile, "r");

  for (int i = 0; i < good_buffers_last; ++i) {
		unsigned rnd;
		if (fscanf(CPU_input_file, "%i\n", &rnd) == EOF) {
			printf("ERROR CPU reached end-of-file at %i / %i\n", i, good_buffers_last);
		}
		int mod = rnd % 2;
		CPUInputBuffer[i] = (rnd - mod) + 1; //2*i+1;//
	}
	for (int i = good_buffers_last; i < bad_buffers_last; ++i) {
		unsigned rnd;
		if (fscanf(CPU_input_file, "%i\n", &rnd) == EOF) {
			printf("ERROR CPU reached end-of-file at %i / %i\n", i, bad_buffers_last);
		}
		int mod = rnd % 2;
		CPUInputBuffer[i] = (rnd - mod); // gets input from the GPU //2*i;//
	}
}

void CPUbufferReadFromFile_UNIF_RAND() {
  int good_buffers_last = size_of_CPU_input_buffer/sizeof(int);
	int bad_buffers_last = 2*size_of_CPU_input_buffer/sizeof(int);
	CPU_input_file = fopen(parsedData.CPUInputFile, "r");

  unsigned rnd;
	for (int i = 0; i < good_buffers_last; ++i) {
		rnd = rand();
		int mod = rnd % 2;
		CPUInputBuffer[i] = (rnd - mod) + 1; //2*i+1;//
	}
	for (int i = good_buffers_last; i < bad_buffers_last; ++i) {
		rnd = rand();
		int mod = rnd % 2;
		CPUInputBuffer[i] = (rnd - mod); // gets input from the GPU //2*i;//
	}
}

void GPUbuffer_NO_CONFLS()
{
  int buffer_last = size_of_GPU_input_buffer/sizeof(int);

	// if (zipf_dist == NULL) {
	// 	generator.seed(input_seed);
	// 	zipf_dist = new zipf_distribution<int, double>(parsedData.nb_accounts * parsedData.num_ways);
	// }

  int nbGPUs = Config::GetInstance()->NbGPUs();
  for (int j = 0; j < nbGPUs; ++j)
  {
    int *cpu_ptr = (int*)GPU_input_buffer_good.GetMemObj(j)->host;
    unsigned rnd; // = (*zipf_dist)(generator);
    for (int i = 0; i < buffer_last; ++i) {
      rnd = (rand() % parsedData.CONFL_SPACE) + parsedData.CONFL_SPACE;
      int mod = rnd % 2;
      cpu_ptr[i] = (rnd - mod);//2*i;//
    }

    cpu_ptr = (int*)GPU_input_buffer_bad.GetMemObj(j)->host;

    for (int i = 0; i < buffer_last; ++i) {
      if (i < parsedData.NB_CONFL_GPU_BUFFER) {
        rnd = rand() % parsedData.CONFL_SPACE;
      } else {
        rnd = (rand() % parsedData.CONFL_SPACE) + parsedData.CONFL_SPACE;
      }
      int mod = rnd % 2;
      cpu_ptr[i] = (rnd - mod) + 1; // gets input from the CPU //2*i+1;//
    }
  }
}

void CPUbuffer_NO_CONFLS()
{
  int good_buffers_last = size_of_CPU_input_buffer/sizeof(int);
  int bad_buffers_last = 2*size_of_CPU_input_buffer/sizeof(int);
  int sizePerThread;

  if (parsedData.NB_CONFL_CPU_BUFFER < 1) {
    sizePerThread = size_of_CPU_input_buffer;
  } else {
    sizePerThread = size_of_CPU_input_buffer / parsedData.nb_threads / parsedData.NB_CONFL_CPU_BUFFER;
  }
  unsigned rnd;
  for (int i = 0; i < good_buffers_last; ++i) {
    rnd = rand() % parsedData.CONFL_SPACE;
    int mod = rnd % 2;
    CPUInputBuffer[i] = (rnd - mod) + 1; //2*i+1;//
  }
  for (int i = good_buffers_last; i < bad_buffers_last; ++i) {
    if (((i - good_buffers_last) % sizePerThread) == 0) {
      rnd = (rand() % parsedData.CONFL_SPACE) + parsedData.CONFL_SPACE;
    } else {
      rnd = rand() % parsedData.CONFL_SPACE;
    }
    int mod = rnd % 2;
    CPUInputBuffer[i] = (rnd - mod); // gets input from the GPU //2*i;//
  }
}

void GPUbuffer_UNIF_2()
{
  int buffer_last = size_of_GPU_input_buffer/sizeof(int);

	// if (zipf_dist == NULL) {
	// 	generator.seed(input_seed);
	// 	zipf_dist = new zipf_distribution<int, double>(parsedData.nb_accounts * parsedData.num_ways);
	// }

  int nbGPUs = Config::GetInstance()->NbGPUs();
  for (int j = 0; j < nbGPUs; ++j)
  {
    int *cpu_ptr = (int*)GPU_input_buffer_good.GetMemObj(j)->host;
    unsigned rnd; // = (*zipf_dist)(generator);
    for (int i = 0; i < buffer_last; ++i) {
      rnd = (rand() % parsedData.CONFL_SPACE) + parsedData.CONFL_SPACE;
      cpu_ptr[i] = rnd;
    }

    cpu_ptr = (int*)GPU_input_buffer_bad.GetMemObj(j)->host;

    for (int i = 0; i < buffer_last; ++i) {
      rnd = rand() % parsedData.CONFL_SPACE; // different from NO_CONFL --> fills the buffer
      cpu_ptr[i] = rnd;
    }
  }
}

void CPUbuffer_UNIF_2()
{
  int good_buffers_last = size_of_CPU_input_buffer/sizeof(int);
  int bad_buffers_last = 2*size_of_CPU_input_buffer/sizeof(int);

  unsigned rnd;
  for (int i = 0; i < good_buffers_last; ++i) {
    rnd = rand() % parsedData.CONFL_SPACE;
    CPUInputBuffer[i] = rnd;
  }
  for (int i = good_buffers_last; i < bad_buffers_last; ++i) {
      rnd = (rand() % parsedData.CONFL_SPACE) + parsedData.CONFL_SPACE;
    CPUInputBuffer[i] = rnd; // gets input from the GPU //2*i;//
  }
}

void GPUbuffer_ZIPF_2()
{
  int buffer_last = size_of_GPU_input_buffer/sizeof(int);

  // 1st item is generated 10% of the times
  int nbGPUs = Config::GetInstance()->NbGPUs();
  unsigned maxGen = parsedData.CONFL_SPACE * parsedData.num_ways * (1+nbGPUs);
  zipf_setup(maxGen, 0.5);

  for (int j = 0; j < nbGPUs; ++j)
  {
    // Setup the buffer without conflicts
    int *cpu_ptr = (int*)GPU_input_buffer_good.GetMemObj(j)->host;
    unsigned rnd, zipfRnd; // = (*zipf_dist)(generator);
    for (int i = 0; i < buffer_last; ++i) {
      zipfRnd = zipf_gen();
      rnd = ((zipfRnd / parsedData.CONFL_SPACE) * 2 + i) * parsedData.CONFL_SPACE
        + (zipfRnd % parsedData.CONFL_SPACE);
      cpu_ptr[i] = rnd;
    }

    // Setup the buffer with conflicts
    cpu_ptr = (int*)GPU_input_buffer_bad.GetMemObj(j)->host;
    for (int i = 0; i < buffer_last; ++i) {
      zipfRnd = zipf_gen();
      // cpu_ptr[i] = i % 100;// maxGen - zipfRnd;
      rnd = ((zipfRnd / parsedData.CONFL_SPACE) * 2 + nbGPUs) * parsedData.CONFL_SPACE
        + (zipfRnd % parsedData.CONFL_SPACE);
      cpu_ptr[i] = rnd;
    }
  }
}

void CPUbuffer_ZIPF_2()
{
  int good_buffers_last = size_of_CPU_input_buffer/sizeof(int);
  int bad_buffers_last = 2*size_of_CPU_input_buffer/sizeof(int);
  int nbGPUs = Config::GetInstance()->NbGPUs();

  unsigned maxGen = parsedData.CONFL_SPACE * parsedData.num_ways * (1+nbGPUs);

  printf("CPUbuffer_ZIPF_2 maxGen=%u\n", maxGen);

  // 1st item is generated 10% of the times
  zipf_setup(maxGen, 0.5);

  unsigned rnd, zipfRnd;
  // Setup the buffer without conflicts
  for (int i = 0; i < good_buffers_last; ++i) {
    zipfRnd = zipf_gen();
    rnd = ((zipfRnd / parsedData.CONFL_SPACE) * 2 + nbGPUs) * parsedData.CONFL_SPACE
      + (zipfRnd % parsedData.CONFL_SPACE);
    CPUInputBuffer[i] = rnd;
  }

  // Setup the buffer with conflicts
  for (int i = good_buffers_last; i < bad_buffers_last; ++i) {
    zipfRnd = zipf_gen();
    // CPUInputBuffer[i] = i % 100; //maxGen - zipfRnd;
    rnd = ((zipfRnd / parsedData.CONFL_SPACE) * 2) * parsedData.CONFL_SPACE
      + (zipfRnd % (parsedData.CONFL_SPACE * nbGPUs));
    CPUInputBuffer[i] = rnd; // gets input from the GPU //2*i;//
  }
}

static int handleFile(char *filename, FILE **f)
{
  if (access(filename, F_OK) == 0) {
    *f = fopen(filename, "r");
    return 1;
  } else {
    *f = fopen(filename, "w+");
    return 0;
  }
}

void GPUbuffer_ZIPF_3()
{
  int buffer_last = (size_of_GPU_input_buffer/sizeof(int))*NB_OF_GPU_BUFFERS;
  const unsigned PRINT_LAG = 1048575;
  const char *CACHE_GPU_FILE = "./cache_GPU%i_%i_%s";
  char filename[1024];
  FILE *f;
  int isCached = 0;

  // 1st item is generated 10% of the times
  int nbGPUs = Config::GetInstance()->NbGPUs();
  unsigned maxGen = parsedData.CONFL_SPACE * parsedData.num_ways * (1+nbGPUs);
  zipf_setup(maxGen, 0.5);

  for (int j = 0; j < nbGPUs; ++j)
  {
    unsigned *good_buffer = (unsigned*)GPU_input_buffer_good.GetMemObj(j)->host;
    unsigned *bad_buffer = (unsigned*)GPU_input_buffer_bad.GetMemObj(j)->host;
    sprintf(filename, CACHE_GPU_FILE, j, buffer_last, "good");
    isCached = handleFile(filename, &f);
    long k = 0;

    // Setup the buffer without conflicts
    unsigned rnd, zipfRnd; // = (*zipf_dist)(generator);
    // sprintf(debugFile, "./GPU%i_input_good.txt", j);
    // f = fopen(debugFile, "w+");
    for (int i = 0; i < buffer_last; ++i)
    {
      if (isCached)
        fscanf(f, "%u\n", &good_buffer[i]);
      else
      {
        do {
          zipfRnd = zipf_gen();
          if ((k++ & PRINT_LAG) == PRINT_LAG) { printf("."); fflush(stdout); }
        } while (nbGPUs > 0 && zipfRnd % (nbGPUs+1) != j);
        good_buffer[i] = zipfRnd;
        fprintf(f, "%u\n", zipfRnd);
      }
    }
    // fclose(f);

    // Setup the buffer with conflicts
    // sprintf(debugFile, "./GPU%i_input_bad.txt", j);
    // f = fopen(debugFile, "w+");
    sprintf(filename, CACHE_GPU_FILE, j, buffer_last, "bad");
    isCached = handleFile(filename, &f);

    // bad_buffer[0] = 0; // deterministic conflict
    for (int i = 0; i < buffer_last; ++i)
    {
      if (isCached)
        fscanf(f, "%u\n", &bad_buffer[i]);
      else
      {
        zipfRnd = zipf_gen();
        if (nbGPUs > 0 && zipfRnd % (nbGPUs+1) == j)
          zipfRnd = zipf_gen(); // bias towards the conflict
        if (nbGPUs > 0 && zipfRnd % (nbGPUs+1) == j)
          zipfRnd = zipf_gen();
        if (nbGPUs > 0 && zipfRnd % (nbGPUs+1) == j)
          zipfRnd = zipf_gen();
          
        bad_buffer[i] = zipfRnd;
        fprintf(f, "%u\n", zipfRnd);
      }
      if ((k++ & PRINT_LAG) == PRINT_LAG) { printf("."); fflush(stdout); }
    }
    // fclose(f);
  }
}

void CPUbuffer_ZIPF_3()
{
  int good_buffers_last = size_of_CPU_input_buffer/sizeof(int);
  int bad_buffers_last = 2*size_of_CPU_input_buffer/sizeof(int);
  int nbGPUs = Config::GetInstance()->NbGPUs();
  const unsigned PRINT_LAG = 1048575;
  const char *CACHE_CPU_FILE = "./cache_CPU_%i_%s";
  char filename[1024];
  FILE *f;
  int isCached = 0;
  unsigned rnd, zipfRnd;
  long k = 0;

  unsigned maxGen = parsedData.CONFL_SPACE * parsedData.num_ways * (1+nbGPUs);

  // printf("CPUbuffer_ZIPF_2 maxGen=%u\n", maxGen);

  // 1st item is generated 10% of the times
  zipf_setup(maxGen, 0.5);

  sprintf(filename, CACHE_CPU_FILE, good_buffers_last, "good");
  isCached = handleFile(filename, &f);

  // Setup the buffer without conflicts
  for (int i = 0; i < good_buffers_last; ++i)
  {
    if (isCached)
      fscanf(f, "%u\n", &CPUInputBuffer[i]);
    else
    {
      do {
        zipfRnd = zipf_gen();
        if ((k++ & PRINT_LAG) == PRINT_LAG) { printf("."); fflush(stdout); }
      } while (nbGPUs > 0 && zipfRnd % (nbGPUs+1) != nbGPUs);
      CPUInputBuffer[i] = zipfRnd;
      fprintf(f, "%u\n", zipfRnd);
    }
  }

  // Setup the buffer with conflicts
  // fclose(f);
  // sprintf(debugFile, "./CPU_input_bad.txt");
  // f = fopen(debugFile, "w+");
  sprintf(filename, CACHE_CPU_FILE, bad_buffers_last-good_buffers_last, "bad");
  isCached = handleFile(filename, &f);

  // CPUInputBuffer[good_buffers_last] = 0; // deterministic conflict
  for (int i = good_buffers_last; i < bad_buffers_last; ++i)
  {
    if (isCached)
      fscanf(f, "%u\n", &CPUInputBuffer[i]);
    else
    {
      zipfRnd = zipf_gen();
      if (nbGPUs > 0 && zipfRnd % (nbGPUs+1) == nbGPUs)
          zipfRnd = zipf_gen(); // bias towards the conflict
      if (nbGPUs > 0 && zipfRnd % (nbGPUs+1) == nbGPUs)
          zipfRnd = zipf_gen();
      if (nbGPUs > 0 && zipfRnd % (nbGPUs+1) == nbGPUs)
          zipfRnd = zipf_gen(); 
      CPUInputBuffer[i] = zipfRnd;
      fprintf(f, "%u\n", zipfRnd);
    }
    if ((k++ & PRINT_LAG) == PRINT_LAG) { printf("."); fflush(stdout); }
  }
  // fclose(f);
}

