#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR


MAINDIR=${1:-${SCRATCH}/build/utopia}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src}
BUILDDIR=${4:-${MAINDIR}/build}
BUILDDIR_FE=${5:-${MAINDIR}/build_fe}

[[ -f ${INSTALLDIR}/build.log ]] && exit 0

MARCH=${MARCH:-"-march=native"}
BUILD_TYPE=${BUILD_TYPE:-"Release"}

BUILDSCRIPT_DIR=$(dirname $(realpath $0))

PETSC_DIR=${PETSC_DIR:-${SCRATCH}/build/petsc/install}
TRILINOS_DIR=${TRILINOS_DIR:-${SCRATCH}/build/trilinos/install}
EIGEN_DIR=${EIGEN_DIR:-${SCRATCH}/build/eigen/install}
LIBMESH_DIR=${LIBMESH_DIR:-${SCRATCH}/build/libmesh/install}

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}
mkdir -p ${BUILDDIR_FE}
mkdir -p ${INSTALLDIR}

pushd ${MAINDIR}
pushd ${MAINDIR}
if [[ -f ${SRCDIR}/utopia/CMakeLists.txt ]]; then
  # it seems we have cloned it already
  pushd ${SRCDIR}
  git pull
else
  git clone -b development --recurse-submodules https://bitbucket.org/zulianp/utopia.git ${SRCDIR}
  pushd ${SRCDIR}
fi


if [[ $BUILD_WITH_CUDA_SUPPORT == 1 ]]; then
  export CXX=$(which nvcc_wrapper
  PATCHES="utopia_no_tests.patch"
fi

PATCHES="$PATCHES utopia_hpcpredict.patch"
for patch in $PATCHES ; do
  # if reverse apply succeeds, the patch has been applied already (we negate the check, i.e. we apply only if reverse apply does not succeed)
  if ! patch --dry-run -f -R -p1 < ${BUILDSCRIPT_DIR}/${patch} ; then
    patch -N -p1 < ${BUILDSCRIPT_DIR}/${patch}
  fi
done

pushd ${BUILDDIR}
cmake -DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_INSTALL_PREFIX=${INSTALLDIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_CXX_FLAGS="-fopenmp $MARCH -Wall -std=c++11" \
      -DTRY_WITH_PETSC=ON -DPETSC_DIR=${PETSC_DIR} \
      -DTRY_WITH_TRILINOS=ON -DTRILINOS_DIR=${TRILINOS_DIR} \
      -DTRY_WITH_EIGEN_3=ON -DEIGEN3_INCLUDE_DIR=${EIGEN_DIR}/include/eigen3 \
      -DBLAS_FOUND=ON \
      -DENABLE_PASSO_EXTENSIONS=ON \
      -DTRY_WITH_CUDA=OFF \
      ${SRCDIR}/utopia
make -j2
make -j2 install

pushd ${BUILDDIR_FE}
cmake -DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DUTOPIA_DIR=${INSTALLDIR} -DLIBMESH_DIR=${LIBMESH_DIR} -DCMAKE_INSTALL_PREFIX=${INSTALLDIR} -DCMAKE_CXX_FLAGS="-fopenmp $MARCH -Wall -std=c++11" ${SRCDIR}/utopia_fe
make -j2
make -j2 install
