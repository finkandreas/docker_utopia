#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR


MAINDIR=${1:-${SCRATCH}/build/moonolith}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src}
BUILDDIR=${4:-${MAINDIR}/build}

[[ -f ${INSTALLDIR}/build.log ]] && exit 0

MARCH=${MARCH:-"-march=native"}
BUILD_TYPE=${BUILD_TYPE:-"Release"}

BUILDSCRIPT_DIR=$(dirname $(realpath $0))

LIBMESH_DIR=${LIBMESH_DIR:-${SCRATCH}/build/libmesh/install}

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}
mkdir -p ${INSTALLDIR}

pushd ${MAINDIR}
if [[ -f ${SRCDIR}/CMakeLists.txt ]]; then
  # it seems we have cloned it already
  pushd ${SRCDIR}
  git pull
else
  git clone https://bitbucket.org/zulianp/par_moonolith.git ${SRCDIR}
  pushd ${SRCDIR}
fi

PATCHES=""
for patch in $PATCHES ; do
  # if reverse apply succeeds, the patch has been applied already (we negate the check, i.e. we apply only if reverse apply does not succeed)
  if ! patch --dry-run -f -R -p1 < ${BUILDSCRIPT_DIR}/${patch} ; then
    patch -N -p1 < ${BUILDSCRIPT_DIR}/${patch}
  fi
done

pushd ${BUILDDIR}
cmake -DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_INSTALL_PREFIX=${INSTALLDIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_CXX_FLAGS="-fopenmp $MARCH -Wall -std=c++11" ${SRCDIR}
make -j2
make -j2 install
