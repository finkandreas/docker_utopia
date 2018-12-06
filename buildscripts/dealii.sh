#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR

MAINDIR=${1:-${SCRATCH}/build/dealii}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src}
BUILDDIR=${4:-${MAINDIR}/build}

[[ -f ${INSTALLDIR}/build.log ]] && exit 0

HYPRE_DIR=${HYPRE_DIR:-${SCRATCH}/build/hypre/install}
PETSC_DIR=${PETSC_DIR:-${SCRATCH}/build/petsc/install}
TRILINOS_DIR=${TRILINOS_DIR:-${SCRATCH}/build/trilinos/install}
P4EST_DIR=${P4EST_DIR:-${SCRATCH}/build/p4est/install}

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}
mkdir -p ${INSTALLDIR}

BUILDSCRIPT_DIR=$(dirname $(realpath $0))

MARCH=${MARCH:-"-march=native"}
BUILD_TYPE=${BUILD_TYPE:-"Release"}

pushd ${MAINDIR}
if [[ -f ${SRCDIR}/CMakeLists.txt ]]; then
  # it seems we have cloned it already
  cd ${SRCDIR}
else
  git clone https://github.com/dealii/dealii.git ${SRCDIR}
  cd ${SRCDIR}
fi

# if reverse apply succeeds, the patch has been applied already (we negate the check, i.e. we apply only if reverse apply does not succeed)
PATCHES="dealii_trilinos_hyper_pc.patch dealii_step55.patch dealii_sparse_matrix.patch dealii_cmake_modules.patch"
for p in $PATCHES ; do
  if ! patch --dry-run -f -R -p1 < "${BUILDSCRIPT_DIR}/${p}" ; then
    patch -N -p1 < "${BUILDSCRIPT_DIR}/${p}"
  fi
done

pushd ${BUILDDIR}
if [[ -n ${DEALII_BUILD_TRILINOS} ]]; then
# LAPACK_FOUND is explicitly set to TRUE since the wrapper compilers will do all the job for us!
# MPI_FOUND is explicitly set to TRUE since the wrapper compilers will do all the job for us!

  PETSC_OR_TRILINOS="-DDEAL_II_WITH_TRILINOS=ON -DTRILINOS_DIR=${TRILINOS_DIR}"
elif [[ -n ${DEALII_BUILD_PETSC} ]]; then
  PETSC_OR_TRILINOS="-DDEAL_II_WITH_PETSC=ON -DPETSC_DIR=${PETSC_DIR}"
else
  echo "You must define the environment variable DEALII_BUILD_TRILINOS or DEALII_BUILD_PETSC"
fi

  cmake \
    -DCMAKE_INSTALL_PREFIX=${INSTALLDIR} \
    -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DDEAL_II_PREFER_STATIC_LIBS=OFF \
    -DDEAL_II_CXX_FLAGS="-fopenmp ${MARCH} -std=c++11" \
    -DDEAL_II_LINKER_FLAGS="-fopenmp ${MARCH}" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_COMPILER=$(which cc) \
    -DCMAKE_CXX_COMPILER=$(which CC) \
    -DCMAKE_Fortran_COMPILER=$(which ftn) \
    -DDEAL_II_WITH_CXX11=ON \
    -DDEAL_II_WITH_CXX14=OFF \
    -DDEAL_II_WITH_CXX17=OFF \
    -DDEAL_II_WITH_LAPACK=ON -DLAPACK_FOUND=TRUE \
    -DDEAL_II_WITH_MPI=ON \
    -DDEAL_II_WITH_HDF5=ON \
    -DDEAL_II_WITH_P4EST=ON \
    -DP4EST_DIR=${P4EST_DIR} \
    ${PETSC_OR_TRILINOS} \
    ${SRCDIR}


make -j2
make -j2 install
setfacl -R -m m::rwx "${INSTALLDIR}"
