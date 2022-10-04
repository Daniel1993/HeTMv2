include ../../cuda_location.mak

INCLUDES := -I ./include \
	-I $(CUDA_PATH)/include
#
DEFINES  :=
#
LIBS     := -L $(CUDA_PATH)/lib64 -lcudart -lcuda -lnuma
NVCC     := $(CUDA_PATH)/bin/nvcc
EXEC     := test_peer_access

$(EXEC) : $(EXEC).o
	$(NVCC) $(LIBS) $(INCLUDES) -std=c++11 -o $@ $<

%.o : %.cu
	$(NVCC) $(NVFLAGS) -o $@ $<