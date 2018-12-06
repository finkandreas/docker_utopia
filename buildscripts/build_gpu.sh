set -e
set -x
set -o pipefail

BUILDBASE=${1:-${SCRATCH}/build/gpu}
INSTALLBASE=${2:-${PROJECT}/install/gpu}

SCRIPTBASE=$(dirname $(realpath $0))

unset PETSC_DIR
unset HYPRE_DIR
unset P4EST_DIR
unset BOOST_DIR
unset TRILINOS_DIR
unset MOOSE_DIR
unset LIBMESH_DIR
unset UTOPIA_DIR
unset EIGEN_DIR

mkdir -p "${INSTALLBASE}"
echo "module purge" > "${INSTALLBASE}/environment"
MODULES="modules craype daint-gpu PrgEnv-gnu cray-hdf5-parallel cray-netcdf-hdf5parallel CMake git cray-libsci VTK cudatoolkit/9.0.103_3.7-6.0.4.1_2.1__g72b395b"
for m in ${MODULES} ; do
  echo "module load ${m}" >> "${INSTALLBASE}/environment"
done
echo "module switch gcc/6.2.0" >> "${INSTALLBASE}/environment"
echo "export CRAYPE_LINK_TYPE=dynamic" >> "${INSTALLBASE}/environment"
echo "export CC=cc" >> "${INSTALLBASE}/environment"
echo "export CXX=CC" >> "${INSTALLBASE}/environment"
echo "export FC=ftn" >> "${INSTALLBASE}/environment"
echo "export F90=ftn" >> "${INSTALLBASE}/environment"
echo "export F77=ftn" >> "${INSTALLBASE}/environment"
echo "export CXXFLAGS=\"\${CXXFLAGS} -std=c++11\"" >> "${INSTALLBASE}/environment"
source "${INSTALLBASE}/environment"

#mkdir -p  ${BUILDBASE}/hypre
#"${SCRIPTBASE}/hypre.sh" "${BUILDBASE}/hypre" "${INSTALLBASE}/hypre" |& tee ${BUILDBASE}/hypre/logfile
#export HYPRE_DIR="${INSTALLBASE}/hypre"
#cp ${BUILDBASE}/hypre/logfile ${INSTALLBASE}/hypre/build.log

mkdir -p  ${BUILDBASE}/p4est
"${SCRIPTBASE}/p4est.sh" "${BUILDBASE}/p4est" "${INSTALLBASE}/p4est" |& tee ${BUILDBASE}/p4est/logfile
export P4EST_DIR="${INSTALLBASE}/p4est"
cp ${BUILDBASE}/p4est/logfile ${INSTALLBASE}/p4est/build.log
echo "export P4EST_DIR=\"${P4EST_DIR}\"" >> "${INSTALLBASE}/environment"

mkdir -p  ${BUILDBASE}/boost
"${SCRIPTBASE}/boost.sh" "${BUILDBASE}/boost" "${INSTALLBASE}/boost" |& tee ${BUILDBASE}/boost/logfile
export BOOST_DIR="${INSTALLBASE}/boost"
cp ${BUILDBASE}/boost/logfile ${INSTALLBASE}/boost/build.log
echo "export BOOST_DIR=\"${BOOST_DIR}\"" >> "${INSTALLBASE}/environment"

mkdir -p ${BUILDBASE}/eigen
"${SCRIPTBASE}/eigen.sh" "${BUILDBASE}/eigen" "${INSTALLBASE}/eigen" |& tee ${BUILDBASE}/eigen/logfile
export EIGEN_DIR="${INSTALLBASE}/eigen"
cp ${BUILDBASE}/eigen/logfile ${INSTALLBASE}/eigen/build.log
echo "export EIGEN_DIR=\"${EIGEN_DIR}\"" >> "${INSTALLBASE}/environment"

# first install petsc without trilinos support, then build trilinos with petsc support, then build petsc with trilinos support
mkdir -p  ${BUILDBASE}/petsc.bootstrap
BUILD_WITH_CUDA_SUPPORT="1" PETSC_BOOTSTRAP=1 "${SCRIPTBASE}/petsc.sh" "${BUILDBASE}/petsc.bootstrap" "${INSTALLBASE}/petsc" |& tee ${BUILDBASE}/petsc.bootstrap/logfile
cp "${BUILDBASE}/petsc.bootstrap/logfile" "${INSTALLBASE}/petsc/build_bootstrap.log"

mkdir -p  ${BUILDBASE}/trilinos
BUILD_WITH_CUDA_SUPPORT="1" PETSC_DIR="${INSTALLBASE}/petsc" "${SCRIPTBASE}/trilinos.sh" "${BUILDBASE}/trilinos" "${INSTALLBASE}/trilinos" |& tee ${BUILDBASE}/trilinos/logfile
export TRILINOS_DIR="${INSTALLBASE}/trilinos"
cp ${BUILDBASE}/trilinos/logfile ${INSTALLBASE}/trilinos/build.log
echo "export TRILINOS_DIR=\"${TRILINOS_DIR}\"" >> "${INSTALLBASE}/environment"

# now build petsc with trilinos support
mkdir -p  ${BUILDBASE}/petsc
BUILD_WITH_CUDA_SUPPORT="1" "${SCRIPTBASE}/petsc.sh" "${BUILDBASE}/petsc" "${INSTALLBASE}/petsc" |& tee ${BUILDBASE}/petsc/logfile
export PETSC_DIR="${INSTALLBASE}/petsc"
cp ${BUILDBASE}/petsc/logfile ${INSTALLBASE}/petsc/build.log
echo "export PETSC_DIR=\"${PETSC_DIR}\"" >> "${INSTALLBASE}/environment"

#mkdir -p ${BUILDBASE}/sprng
#"${SCRIPTBASE}/sprng.sh" "${BUILDBASE}/sprng" "${INSTALLBASE}/sprng" |& tee ${BUILDBASE}/sprng/logfile
#export SPRNG_DIR="${INSTALLBASE}/sprng"
#cp ${BUILDBASE}/sprng/logfile ${INSTALLBASE}/sprng/build.log
#echo "export SPRNG_DIR=\"${SPRNG_DIR}\"" >> "${INSTALLBASE}/environment"

mkdir -p ${BUILDBASE}/moose
"${SCRIPTBASE}/moose.sh" "${BUILDBASE}/moose" "${INSTALLBASE}/moose" |& tee ${BUILDBASE}/moose/logfile
export MOOSE_DIR="${INSTALLBASE}/moose"
export LIBMESH_DIR="${INSTALLBASE}/libmesh"
[[ ${BUILD_TYPE,,} == "debug" ]] && METHOD=dbg || METHOD=opt
export METHOD="${METHOD}"
cp ${BUILDBASE}/moose/logfile "${INSTALLBASE}/moose/build.log"
echo "export LIBMESH_DIR=\"${LIBMESH_DIR}\"" >> "${INSTALLBASE}/environment"
echo "export MOOSE_DIR=\"${MOOSE_DIR}\"" >> "${INSTALLBASE}/environment"
echo "export METHOD=\"${METHOD}\"" >> "${INSTALLBASE}/environment"

mkdir -p ${BUILDBASE}/moonolith
"${SCRIPTBASE}/moonolith.sh" "${BUILDBASE}/moonolith" "${INSTALLBASE}/moonolith" |& tee "${BUILDBASE}/moonolith/logfile"
export MOONOLITH_DIR="${INSTALLBASE}/moonolith"
cp "${BUILDBASE}/moonolith/logfile" "${INSTALLBASE}/moonolith/build.log"
echo "export MOONOLITH_DIR=\"${MOONOLITH_DIR}\"" >> "${INSTALLBASE}/environment"

mkdir -p ${BUILDBASE}/utopia
BUILD_WITH_CUDA_SUPPORT="1" "${SCRIPTBASE}/utopia.sh" "${BUILDBASE}/utopia" "${INSTALLBASE}/utopia" |& tee ${BUILDBASE}/utopia/logfile
export UTOPIA_DIR="${INSTALLBASE}/utopia"
cp ${BUILDBASE}/utopia/logfile ${INSTALLBASE}/utopia/build.log
echo "export UTOPIA_DIR=\"${UTOPIA_DIR}\"" >> "${INSTALLBASE}/environment"
