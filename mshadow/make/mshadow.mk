#---------------------------------------------------------------------------------------
#  mshadow configuration script
#
#  include mshadow.mk after the variables are set
#
#  Add MSHADOW_CFLAGS to the compile flags
#  Add MSHADOW_LDFLAGS to the linker flags
#  Add MSHADOW_NVCCFLAGS to the nvcc compile flags
#----------------------------------------------------------------------------------------

MSHADOW_CFLAGS = -funroll-loops -Wno-unused-variable -Wno-unused-parameter -Wno-unknown-pragmas -Wno-unused-local-typedefs
MSHADOW_LDFLAGS = -lm
MSHADOW_CFLAGS += -DMSHADOW_USE_CUSOLVER=0 -DMXNET_USE_CUSOLVER=0
MSHADOW_NVCCFLAGS = -DMSHADOW_USE_CUSOLVER=0 -DMXNET_USE_CUSOLVER=0



# atlas blas library has different name on CentOS
OS := $(shell cat /etc/system-release 2>/dev/null)
ifeq ($(findstring CentOS,$(OS)), CentOS)
  ATLAS_LDFLAGS := -lsatlas -L/usr/lib64/atlas
else
  ATLAS_LDFLAGS := -lcblas
endif

ifndef USE_SSE
	USE_SSE=1
endif

ifeq ($(USE_SSE), 1)
	MSHADOW_CFLAGS += -msse3
else
	MSHADOW_CFLAGS += -DMSHADOW_USE_SSE=0
endif

ifeq ($(USE_CUDA), 0)
	MSHADOW_CFLAGS += -DMSHADOW_USE_CUDA=0
else
	MSHADOW_LDFLAGS += -lcudart -lcublas -lcurand -lcusolver
endif
ifneq ($(USE_CUDA_PATH), NONE)
	MSHADOW_CFLAGS += -I$(USE_CUDA_PATH)/include
	MSHADOW_LDFLAGS += -L$(USE_CUDA_PATH)/lib64 -L$(USE_CUDA_PATH)/lib
endif

ifeq ($(USE_BLAS), mkl)
ifneq ($(USE_INTEL_PATH), NONE)
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Darwin)
		MSHADOW_LDFLAGS += -L$(USE_INTEL_PATH)/mkl/lib
		MSHADOW_LDFLAGS += -L$(USE_INTEL_PATH)/lib
	else
		MSHADOW_LDFLAGS += -L$(USE_INTEL_PATH)/mkl/lib/intel64
		MSHADOW_LDFLAGS += -L$(USE_INTEL_PATH)/compiler/lib/intel64
		MSHADOW_LDFLAGS += -L$(USE_INTEL_PATH)/lib/intel64
	endif
	MSHADOW_CFLAGS += -I$(USE_INTEL_PATH)/mkl/include
endif
ifneq ($(USE_STATIC_MKL), NONE)
ifeq ($(USE_INTEL_PATH), NONE)
	MKLROOT = /opt/intel/mkl
else
	MKLROOT = $(USE_INTEL_PATH)/mkl
endif
	MSHADOW_LDFLAGS += -L${MKLROOT}/../compiler/lib/intel64 -Wl,--start-group ${MKLROOT}/lib/intel64/libmkl_intel_lp64.a ${MKLROOT}/lib/intel64/libmkl_core.a ${MKLROOT}/lib/intel64/libmkl_intel_thread.a -Wl,--end-group -liomp5 -ldl -lpthread -lm
else
ifneq ($(USE_MKLML), 1)
  MSHADOW_LDFLAGS += -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5
endif
endif
else
ifneq ($(USE_BLAS), NONE)
	MSHADOW_CFLAGS += -DMSHADOW_USE_CBLAS=1 -DMSHADOW_USE_MKL=0
endif
endif

ifeq ($(USE_MKLML), 1)
	MSHADOW_CFLAGS += -I$(MKLROOT)/include
	ifneq ($(shell uname),Darwin)
		MSHADOW_LDFLAGS += -Wl,--as-needed -lmklml_intel -lmklml_gnu
	else
		MSHADOW_LDFLAGS += -lmklml
	endif
	MSHADOW_LDFLAGS += -liomp5 -L$(MKLROOT)/lib/
endif

ifeq ($(USE_BLAS), openblas)
	MSHADOW_LDFLAGS += -lopenblas
else ifeq ($(USE_BLAS), perfblas)
	MSHADOW_LDFLAGS += -lperfblas
else ifeq ($(USE_BLAS), atlas)
	MSHADOW_LDFLAGS += $(ATLAS_LDFLAGS)
else ifeq ($(USE_BLAS), blas)
	MSHADOW_LDFLAGS += -lblas
else ifeq ($(USE_BLAS), apple)
	MSHADOW_CFLAGS += -I/System/Library/Frameworks/Accelerate.framework/Versions/Current/Frameworks/vecLib.framework/Versions/Current/Headers/
	MSHADOW_LDFLAGS += -framework Accelerate
endif

ifeq ($(PS_PATH), NONE)
	PS_PATH = ..
endif
ifeq ($(PS_THIRD_PATH), NONE)
	PS_THIRD_PATH = $(PS_PATH)/third_party
endif

ifndef RABIT_PATH
	RABIT_PATH = rabit
endif

ifeq ($(RABIT_PATH), NONE)
	RABIT_PATH = rabit
endif

ifeq ($(USE_RABIT_PS),1)
	MSHADOW_CFLAGS += -I$(RABIT_PATH)/include
	MSHADOW_LDFLAGS += -L$(RABIT_PATH)/lib -lrabit_base
	MSHADOW_CFLAGS += -DMSHADOW_RABIT_PS=1
else
	MSHADOW_CFLAGS += -DMSHADOW_RABIT_PS=0
endif

ifeq ($(USE_DIST_PS),1)
MSHADOW_CFLAGS += -DMSHADOW_DIST_PS=1 -std=c++11 \
	-I$(PS_PATH)/src -I$(PS_THIRD_PATH)/include
PS_LIB = $(addprefix $(PS_PATH)/build/, libps.a libps_main.a) \
	$(addprefix $(PS_THIRD_PATH)/lib/, libgflags.a libzmq.a libprotobuf.a \
	libglog.a libz.a libsnappy.a)
	# -L$(PS_THIRD_PATH)/lib -lgflags -lzmq -lprotobuf -lglog -lz -lsnappy
MSHADOW_NVCCFLAGS += --std=c++11
else
	MSHADOW_CFLAGS+= -DMSHADOW_DIST_PS=0
endif

# MSHADOW_USE_PASCAL=1 used to enable true-fp16 gemms.  Now, mshadow
# only uses pseudo-fp16 gemms, so this flag will be removed after
# dependent projects no longer reference it.
MSHADOW_CFLAGS += -DMSHADOW_USE_PASCAL=0
