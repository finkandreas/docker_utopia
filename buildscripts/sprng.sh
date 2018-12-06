#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR


MAINDIR=${1:-${SCRATCH}/build/sprng}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src}
BUILDDIR=${4:-${MAINDIR}/src}  # out of source build does not work...

MARCH=${MARCH:-"-march=native"}

[[ -f ${INSTALLDIR}/build.log ]] && exit 0

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}
mkdir -p ${INSTALLDIR}

FILE="sprng5.tar.bz2"

pushd ${MAINDIR}
wget -c http://www.sprng.org/Version5.0/${FILE}
tar -xf ${FILE} -C ${SRCDIR} --strip 1

pushd ${BUILDDIR}
CXXFLAGS="-O3 -march=native" CFLAGS="-O3 -march=native" CXX="CC" MPICXX="CC" CC="cc" F77="ftn" ${SRCDIR}/configure --prefix=${INSTALLDIR} --with-mpi

make
# make install does not install the include directory, so we "install" manually
cp -a ${BUILDDIR}/include ${BUILDDIR}/lib ${INSTALLDIR}
