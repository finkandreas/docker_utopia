#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR

MAINDIR=${1:-${SCRATCH}/build/moose}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src}
BUILDDIR=${4:-${SRCDIR}/framework}

[[ -f ${INSTALLDIR}/build.log ]] && exit 0

export PETSC_DIR=${PETSC_DIR:-${SCRATCH}/build/petsc/install}

mkdir -p ${SRCDIR}
mkdir -p ${INSTALLDIR}

BUILDSCRIPT_DIR=$(dirname $(realpath $0))

MARCH=${MARCH:-"-march=native"}
BUILD_TYPE=${BUILD_TYPE:-"Release"}
export MOOSE_JOBS=4
METHOD=opt
[[ ${BUILD_TYPE,,} == "debug" ]] && METHOD=dbg
export METHOD

export CFLAGS="$MARCH"
export CXXFLAGS="${CXXFLAGS} $MARCH"
export libmesh_CXXFLAGS="${CXXFLAGS}"
export LIBMESH_DIR="$(realpath -m ${INSTALLDIR}/../libmesh)"
export VTK_DIR="/usr"

pushd ${MAINDIR}
if [[ -d ${SRCDIR}/framework ]]; then
  # it seems we have cloned it already
  cd ${SRCDIR}
# git pull
else
  git clone https://github.com/idaholab/moose/ ${SRCDIR}
  cd ${SRCDIR}
  # git checkout eb3fa8ac14
fi
# For now we need a very specific version of moose!!!
#git checkout 235e064487b3911937ad6d1639fefdc171ba7ec3

git submodule init libmesh
git submodule update libmesh
pushd ${SRCDIR}/libmesh
PATCHES=""
for patch in $PATCHES ; do
  if ! patch --dry-run -f -R -p1 < ${BUILDSCRIPT_DIR}/${patch} ; then
    patch -N -p1 < ${BUILDSCRIPT_DIR}/${patch}
  fi
done
popd

PATCHES="libmesh_additional_config.patch"
for patch in $PATCHES ; do
  # if reverse apply succeeds, the patch has been applied already (we negate the check, i.e. we apply only if reverse apply does not succeed)
  if ! patch --dry-run -f -R -p1 < ${BUILDSCRIPT_DIR}/${patch} ; then
    patch -N -p1 < ${BUILDSCRIPT_DIR}/${patch}
  fi
done

# Build libmesh and install
if [[ -e /usr/lib64/libtirpc.so ]]; then
  false
  LDFLAGS="-ltirpc" CPPFLAGS="-I/usr/include/tirpc" CXXFLAGS="-I/usr/include/tirpc $CXXFLAGS" ./scripts/update_and_rebuild_libmesh.sh
else
  ./scripts/update_and_rebuild_libmesh.sh
fi

rsync -a --exclude=".git" --exclude="libmesh" "${SRCDIR}/" "${INSTALLDIR}"
pushd "${INSTALLDIR}/framework"
make -j2
