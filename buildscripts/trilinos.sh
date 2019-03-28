#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR

MAINDIR=${1:-${SCRATCH}/build/trilinos}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src}
BUILDDIR=${4:-${MAINDIR}/build}

[[ -f ${INSTALLDIR}/build.log ]] && exit 0

PETSC_DIR=${PETSC_DIR:-${SCRATCH}/build/petsc/install}

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}
mkdir -p ${INSTALLDIR}

BUILDSCRIPT_DIR=$(dirname $(realpath $0))

MARCH=${MARCH:-"-march=native"}
BUILD_TYPE=${BUILD_TYPE:-"release"}

pushd ${MAINDIR}
if [[ -f ${SRCDIR}/CMakeLists.txt ]]; then
  # it seems we have cloned it already
  pushd ${SRCDIR}
  git pull
else
  git clone https://github.com/trilinos/Trilinos.git ${SRCDIR}
  pushd ${SRCDIR}
fi

#~ export NVCC_WRAPPER_DEFAULT_COMPILER="$(which g++)"
#~ export OMPI_CXX="${BUILDSCRIPT_DIR}/nvcc_wrapper"

# if reverse apply succeeds, the patch has been applied already (we negate the check, i.e. we apply only if reverse apply does not succeed)
PATCHES=""
for p in $PATCHES ; do
  if ! patch --dry-run -f -R -p1 < ${BUILDSCRIPT_DIR}/${p} ; then
    patch -N -p1 < ${BUILDSCRIPT_DIR}/${p}
  fi
done

if [[ -n ${BUILD_WITH_CUDA_SUPPORT} ]] ; then
  CMAKE_CUDA_OPTS="-DKokkos_ENABLE_Cuda=ON -DKokkos_ENABLE_Cuda_UVM=ON -DKokkos_ENABLE_Cuda_Lambda=ON -DTPL_ENABLE_CUDA=ON -DTPL_ENABLE_CUSPARSE=ON " # -DKokkos_ENABLE_Cuda_Relocatable_Device_Code=ON -DKokkos_ENABLE_Cuda_RDC=ON"
  CUDA_BLAS_EXTRA=";cusparse"
  CXX_COMPILER="${BUILDSCRIPT_DIR}/nvcc_wrapper"
  CXX_CUDA_FLAGS="--expt-extended-lambda"
fi

EXAMPLES_TESTS="-DTrilinos_ENABLE_EXAMPLES=OFF -DTrilinos_ENABLE_TESTS=OFF"
if [[ -n ${BUILD_WITH_EXAMPLES} ]] ; then
  EXAMPLES_TESTS="-DTrilinos_ENABLE_EXAMPLES=ON -DTrilinos_ENABLE_TESTS=ON"
  #~ EXAMPLES_TESTS="${EXAMPLES_TESTS} -DKokkosExample_ENABLE_EXAMPLES=OFF"
fi

# -DAmesos2_ENABLE_ShyLU_NodeTacho=OFF \
# ML_ENABLE_SuperLU=OFF  Disable SuperLU because ML needs SuperLU < 5.0, but we have a newer version!

#  -DKOKKOS_ARCH="HSW,Pascal60" \

# We have to trick the build system a little bit, BLAS/LAPACK libraries are by default added by CC/cc/ftn, but trilinos tries to be smart and must add something to the linking, so we just add libc, which is linked anyways.
pushd ${BUILDDIR}
cmake -DCMAKE_INSTALL_PREFIX=${INSTALLDIR} -DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
      -DCMAKE_C_FLAGS="-fopenmp" -DCMAKE_Fortran_FLAGS="-fopenmp" -DCMAKE_CXX_FLAGS="-std=c++11 -O3 ${MARCH} ${CXX_CUDA_FLAGS}" \
      -DCMAKE_CXX_COMPILER="$(which mpic++)" -DCMAKE_C_COMPILER="$(which mpicc)" -DCMAKE_Fortran_COMPILER="$(which mpifort)" \
      -DCMAKE_SKIP_RPATH=OFF -DCMAKE_SKIP_INSTALL_RPATH=TRUE -DTrilinos_SET_INSTALL_RPATH=OFF \
      -DTPL_ENABLE_Boost=OFF \
      -DHYPRE_INCLUDE_DIRS="${PETSC_DIR}/include" -DHYPRE_LIBRARY_DIRS="${PETSC_DIR}/lib" \
      -DPETSC_INCLUDE_DIRS=${PETSC_DIR}/include -DPETSC_LIBRARY_DIRS="${PETSC_DIR}/lib;/usr/lib64" -DPETSC_LIBRARY_NAMES="petsc;X11" \
      -DTPL_ENABLE_HDF5=ON -DHDF5_INCLUDE_DIRS=${PETSC_DIR}/include -DHDF5_LIBRARY_DIRS="${PETSC_DIR}/lib" \
      -DTPL_ENABLE_BLAS=ON -DTPL_ENABLE_LAPACK=ON \
      -DTPL_ENABLE_METIS=ON -DMETIS_INCLUDE_DIRS=${PETSC_DIR}/include -DMETIS_LIBRARY_DIRS=${PETSC_DIR}/lib \
      -DTPL_ENABLE_MUMPS=ON -DMUMPS_INCLUDE_DIRS=${PETSC_DIR}/include -DMUMPS_LIBRARY_DIRS=${PETSC_DIR}/lib \
      -DTPL_ENABLE_Netcdf=ON -DNetcdf_INCLUDE_DIRS=${PETSC_DIR}/include -DNetcdf_LIBRARY_DIRS=${PETSC_DIR}/lib \
      -DTPL_ENABLE_ParMETIS=ON -DParMETIS_INCLUDE_DIRS=${PETSC_DIR}/include -DParMETIS_LIBRARY_DIRS=${PETSC_DIR}/lib \
      -DTPL_ENABLE_SCALAPACK=ON -DSCALAPACK_INCLUDE_DIRS=${PETSC_DIR}/include -DSCALAPACK_LIBRARY_DIRS=${PETSC_DIR}/lib \
      -DTPL_ENABLE_SuperLU=ON -DSuperLU_INCLUDE_DIRS=${PETSC_DIR}/include -DSuperLU_LIBRARY_DIRS=${PETSC_DIR}/lib \
      -DTPL_ENABLE_SuperLUDist=ON -DSuperLUDist_INCLUDE_DIRS=${PETSC_DIR}/include -DSuperLUDist_LIBRARY_DIRS=${PETSC_DIR}/lib \
      -DBUILD_SHARED_LIBS=ON \
      -DTrilinos_ENABLE_EXPLICIT_INSTANTIATION=ON \
      -DTrilinos_ENABLE_OpenMP=ON \
      -DTrilinos_ENABLE_SERIAL=ON \
      -DTrilinos_ENABLE_Amesos=ON -DAmesos_ENABLE_SuperLUDist=OFF -DTrilinos_ENABLE_Amesos2=ON -DAmesos2_ENABLE_Basker=ON -DAmesos2_ENABLE_SuperLUDist=OFF -DAmesos2_ENABLE_SuperLU=OFF -DAmesos2_ENABLE_TIMERS=ON -DAmesos2_ENABLE_VERBOSE_DEBUG=ON -DAmesos2_ENABLE_MUMPS=ON \
      -DTrilinos_ENABLE_Anasazi=OFF \
      -DTrilinos_ENABLE_AztecOO=ON -DAztecOO_ENABLE_AZLU=OFF -DAztecOO_ENABLE_TEUCHOS_TIME_MONITOR=ON \
      -DTrilinos_ENABLE_Belos=ON -DBelos_Tpetra_Timers=ON -DBelos_HIDE_DEPRECATED_CODE=ON -DBelos_ENABLE_TSQR=ON \
      -DTrilinos_ENABLE_Epetra=ON -DEpetraExt_USING_HDF5=ON -DEpetra_ENABLE_Fortran=OFF -DEpetra_ENABLE_THREADS=ON -DEpetra_ENABLE_WARNING_MESSAGES=ON -DEpetra_HIDE_DEPRECATED_CODE=ON -DEpetraExt_HIDE_DEPRECATED_CODE=ON \
      -DTrilinos_ENABLE_Ifpack=ON -DTrilinos_ENABLE_Ifpack2=ON -DIfpack2_ENABLE_Experimental_KokkosKernels_Features=OFF -DIfpack2_ENABLE_IFPACK2_TIMER_BARRIER=ON -DIfpack2_HIDE_DEPRECATED_CODE=ON -DIfpack_HIDE_DEPRECATED_CODE=ON \
      -DTrilinos_ENABLE_Intrepid=ON -DTrilinos_ENABLE_Intrepid2=ON \
      -DTrilinos_ENABLE_Kokkos=ON -DKokkos_ENABLE_DEBUG=OFF -DKokkos_ENABLE_Debug_Bounds_Check=OFF -DKokkos_ENABLE_MPI=ON \
      -DTrilinos_ENABLE_KokkosAlgorithms=ON\
      -DTrilinos_ENABLE_KokkosContainers=ON \
      -DTrilinos_ENABLE_KokkosCore=ON \
      -DTrilinos_ENABLE_KokkosExample=OFF \
      -DTrilinos_ENABLE_KokkosKernels=ON \
      -DTrilinos_ENABLE_LINEAR_SOLVER_FACTORY_REGISTRATION=OFF \
      -DTrilinos_ENABLE_ML=ON -DML_ENABLE_Flops=ON -DML_ENABLE_Timing=ON -DML_ENABLE_SuperLU=OFF \
      -DTrilinos_ENABLE_MueLu=ON \
      -DTrilinos_ENABLE_NOX=ON \
      -DRTOp_HIDE_DEPRECATED_CODE=ON \
      -DTrilinos_ENABLE_Sacado=ON \
      -DTrilinos_ENABLE_ShyLU=OFF -DTrilinos_ENABLE_ShyLUHTS=OFF -DTrilinos_ENABLE_ShyLU_Node=OFF \
      -DTrilinos_ENABLE_Stratimikos=ON \
      -DTrilinos_ENABLE_TeuchosParser=ON -DTeuchos_ENABLE_MPI=ON \
      -DTrilinos_ENABLE_Tpetra=ON -DTrilinos_ENABLE_TpetraCore=ON -DTpetra_THROW_Efficiency_Warnings=ON -DTpetra_HIDE_DEPRECATED_CODE=ON -DTpetra_INST_OPENMP=ON -DTpetra_INST_SERIAL=ON \
      -DTrilinos_ENABLE_TriKota=OFF \
      -DTrilinos_ENABLE_Zoltan=ON -DTrilinos_ENABLE_Zoltan2=ON -DZoltan_ENABLE_CPPDRIVER=OFF \
      -DUSE_XSDK_DEFAULTS=OFF -DXpetra_ENABLE_Kokkos_Refactor=ON \
      -DTPL_ENABLE_Dakota=OFF -DTPL_ENABLE_Eigen=OFF -DTPL_ENABLE_HYPRE=ON -DTPL_ENABLE_MPI=ON -DTPL_ENABLE_PETSC=ON -DTPL_ENABLE_y12m=OFF -DTPL_FIND_SHARED_LIBS=ON \
      ${EXAMPLES_TESTS} \
      ${CMAKE_CUDA_OPTS} \
      ${SRCDIR}

make -j2
make -j2 install

