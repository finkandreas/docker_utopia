#!/bin/bash

set -x
set -e

# $1=MAINDIR
# $2=INSTALLDIR
# $3=SRCDIR
# $4=BUILDDIR


MAINDIR=${1:-${SCRATCH}/build/boost}
INSTALLDIR=${2:-${MAINDIR}/install}
SRCDIR=${3:-${MAINDIR}/src}
BUILDDIR=${4:-${MAINDIR}/build}

[[ -f ${INSTALLDIR}/build.log ]] && exit 0

TOOLSET=unknown
if CC --version | grep -q clang ; then
    TOOLSET=clang
elif CC --version | grep -q GCC ; then
    TOOLSET=gcc
fi

FILE=boost_1_71_0.tar.bz2

mkdir -p ${SRCDIR}
mkdir -p ${BUILDDIR}
mkdir -p ${INSTALLDIR}

pushd ${MAINDIR}
wget -c https://dl.bintray.com/boostorg/release/1.71.0/source/${FILE}
tar -xf ${FILE} -C ${SRCDIR} --strip 1

pushd ${SRCDIR}
./bootstrap.sh
./b2 --prefix=${INSTALLDIR} toolset=${TOOLSET} cxxflags="${CXXFLAGS}" variant=release link=static threading=multi --build-dir=${BUILDDIR} --stagedir=${BUILDDIR}/stagedir --without-python -d+2 -j16 install
