#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR


MAINDIR=${1:-${SCRATCH}/build/p4est}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src}
BUILDDIR=${4:-${MAINDIR}/build}

[[ -f ${INSTALLDIR}/build.log ]] && exit 0

FILE=p4est-2.0.tar.gz

MARCH=${MARCH:-"-march=native"}
DEBUG_FLAGS=""
[[ ${BUILD_TYPE,,} == "debug" ]] && DEBUG_FLAGS="--enable-debug"

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}
mkdir -p ${INSTALLDIR}

pushd ${MAINDIR}
wget -c http://p4est.github.io/release/${FILE}
tar -xf ${FILE} -C ${SRCDIR} --strip 1

pushd ${BUILDDIR}
CFLAGS="-O3 ${MARCH}" CXXFLAGS="${CXXFLAGS} -O3 ${MARCH}" ${SRCDIR}/configure --prefix=${INSTALLDIR} --enable-p6est --enable-mpi ${DEBUG_FLAGS}


make -j2
make -j2 install

