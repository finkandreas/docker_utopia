#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR

MAINDIR=${1:-${SCRATCH}/build/petsc}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src_build}
BUILDDIR=${4:-${MAINDIR}/src_build} # petsc does not support out of source builds (but it creates a build directory inside the source tree)

[[ -z ${PETSC_BOOTSTRAP} && -f ${INSTALLDIR}/build.log ]] && exit 0
[[ -n ${PETSC_BOOTSTRAP} && -f ${INSTALLDIR}/build_bootstrap.log ]] && exit 0

TRILINOS_DIR=${TRILINOS_DIR:-${SCRATCH}/build/trilinos/install}

BUILDSCRIPT_DIR=$(dirname $(realpath $0))
PETSC_BRANCH=${PETSC_BRANCH:-maint}

MARCH=${MARCH:-"-march=native"}
DEBUG_FLAGS="--with-debugging=0"
[[ ${BUILD_TYPE,,} == "debug" ]] && DEBUG_FLAGS="--with-debugging=1"

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}
mkdir -p ${INSTALLDIR}

pushd ${MAINDIR}
if [[ -f ${SRCDIR}/configure ]]; then
  # it seems we have cloned it already
  cd ${SRCDIR}
  git pull
else
  git clone -b ${PETSC_BRANCH} https://gitlab.com/petsc/petsc.git ${SRCDIR}
  cd ${SRCDIR}
fi

# if reverse apply succeeds, the patch has been applied already (we negate the check, i.e. we apply only if reverse apply does not succeed)
PATCHES=""
for p in ${PATCHES} ; do
  if ! patch --dry-run -f -R -p1 < ${BUILDSCRIPT_DIR}/${p} ; then
    patch -N -p1 < ${BUILDSCRIPT_DIR}/${p}
  fi
done

if [[ -n ${BUILD_WITH_CUDA_SUPPORT} ]] ; then
  CUDA_OPTS="--with-cuda=1 --with-cudac=$(which nvcc) --with-cuda-arch=sm_60 --CUDAFLAGS=-Wno-deprecated-gpu-targets CUDAC=nvcc "
fi

pushd ${BUILDDIR}
if [[ -z ${PETSC_BOOTSTRAP} ]]; then
  python2 ${SRCDIR}/configure --prefix=${INSTALLDIR} \
    --with-shared-libraries=1 --with-cxx-dialect=C++14 --with-zlib=1 --with-mpi=1 \
    --with-trilinos=1 --with-trilinos-dir=${TRILINOS_DIR} \
    --with-netcdf=1 --with-netcdf-dir=${INSTALLDIR} \
    --with-hdf5=1 --with-hdf5-dir=${INSTALLDIR} \
    --with-metis=1 --with-metis-dir=${INSTALLDIR} \
    --with-parmetis=1 --with-parmetis-dir=${INSTALLDIR} \
    --with-superlu_dist=1 --with-superlu_dist-dir=${INSTALLDIR} \
    --with-superlu=1 --with-superlu-dir=${INSTALLDIR} \
    --with-mumps=1 --with-mumps-dir=${INSTALLDIR} \
    --with-scalapack=1 --with-scalapack-dir=${INSTALLDIR} \
    --with-hypre --with-hypre-dir=${INSTALLDIR} \
    --with-ptscotch=1 --with-ptscotch-dir=${INSTALLDIR} \
    --with-sundials=1 --with-sundials-dir=${INSTALLDIR} \
    ${DEBUG_FLAGS} $CUDAOPTS COPTFLAGS="-O3 ${MARCH} -fopenmp" CXXOPTFLAGS="-std=c++14 -O3 ${MARCH} -fopenmp"
else
  ${SRCDIR}/configure --prefix=${INSTALLDIR} \
    --with-shared-libraries=1 --with-clean=0 --with-cxx-dialect=C++14 --with-zlib=1 --with-mpi=1 \
    --download-netcdf=1 \
    --download-hdf5=1 \
    --download-metis=1 \
    --download-parmetis=1 \
    --download-superlu_dist=1 \
    --download-superlu=1 \
    --download-mumps=1 \
    --download-scalapack=1 \
    --download-hypre=1 \
    --download-ptscotch=1 \
    --download-sundials=1 --download-sundials-configure-arguments="--enable-cvodes --enable-ida --enable-idas --enable-kinsol" \
    --download-suitesparse=1 \
    ${DEBUG_FLAGS} $CUDAOPTS COPTFLAGS="-O3 ${MARCH} -fopenmp" CXXOPTFLAGS="-std=c++14 -O3 ${MARCH} -fopenmp"
fi

PETSC_ARCH="arch-linux-c-opt"
[[ ! -d ${PETSC_ARCH} ]] && PETSC_ARCH="arch-linux2-c-opt"
[[ ${BUILD_TYPE,,} == "debug" ]] && PETSC_ARCH="arch-linux2-c-debug"
[[ ${BUILD_TYPE,,} == "debug" && ! -d ${PETSC_ARCH} ]] && PETSC_ARCH="arch-linux-c-debug"

make PETSC_DIR=${BUILDDIR} PETSC_ARCH=${PETSC_ARCH} MAKE_NP=2 all
make PETSC_DIR=${BUILDDIR} PETSC_ARCH=${PETSC_ARCH} install
