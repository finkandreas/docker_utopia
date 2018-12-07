set -e
set -x
set -o pipefail

BUILDBASE=${1:-${SCRATCH}/build/cpu}
INSTALLBASE=${2:-${PROJECT}/install/cpu}
STAGE=${3:-ALL}

SCRIPTBASE=$(dirname $(realpath $0))

unset P4EST_DIR
unset BOOST_DIR
unset EIGEN_DIR
unset TRILINOS_DIR
unset PETSC_DIR
unset MOOSE_DIR
unset LIBMESH_DIR
unset UTOPIA_DIR

if [[ $STAGE == 1 || $STAGE == ALL ]] ; then
    mkdir -p "${INSTALLBASE}"
    echo "export CXXFLAGS=\"-std=c++11\"" > "${INSTALLBASE}/environment"
    source "${INSTALLBASE}/environment"

    mkdir -p ${BUILDBASE}/p4est
    "${SCRIPTBASE}/p4est.sh" "${BUILDBASE}/p4est" "${INSTALLBASE}/p4est" |& tee ${BUILDBASE}/p4est/logfile
    export P4EST_DIR="${INSTALLBASE}/p4est"
    cp ${BUILDBASE}/p4est/logfile ${INSTALLBASE}/p4est/build.log
    echo "export P4EST_DIR=\"${P4EST_DIR}\"" >> "${INSTALLBASE}/environment"

    mkdir -p ${BUILDBASE}/eigen
    "${SCRIPTBASE}/eigen.sh" "${BUILDBASE}/eigen" "${INSTALLBASE}/eigen" |& tee ${BUILDBASE}/eigen/logfile
    export EIGEN_DIR="${INSTALLBASE}/eigen"
    cp ${BUILDBASE}/eigen/logfile ${INSTALLBASE}/eigen/build.log
    echo "export EIGEN_DIR=\"${EIGEN_DIR}\"" >> "${INSTALLBASE}/environment"
else
    source "${INSTALLBASE}/environment"
fi

if [[ $STAGE == 2 || $STAGE == ALL ]] ; then
    # first install petsc without trilinos support, then build trilinos with petsc support, then build petsc with trilinos support
    mkdir -p ${BUILDBASE}/petsc.bootstrap
    PETSC_BOOTSTRAP=1 "${SCRIPTBASE}/petsc.sh" "${BUILDBASE}/petsc.bootstrap" "${INSTALLBASE}/petsc" |& tee ${BUILDBASE}/petsc.bootstrap/logfile
    cp "${BUILDBASE}/petsc.bootstrap/logfile" "${INSTALLBASE}/petsc/build_bootstrap.log"
fi

if [[ $STAGE == 3 || $STAGE == ALL ]] ; then
    mkdir -p ${BUILDBASE}/trilinos
    PETSC_DIR="${INSTALLBASE}/petsc" "${SCRIPTBASE}/trilinos.sh" "${BUILDBASE}/trilinos" "${INSTALLBASE}/trilinos" |& tee ${BUILDBASE}/trilinos/logfile
    export TRILINOS_DIR="${INSTALLBASE}/trilinos"
    cp ${BUILDBASE}/trilinos/logfile ${INSTALLBASE}/trilinos/build.log
    echo "export TRILINOS_DIR=\"${TRILINOS_DIR}\"" >> "${INSTALLBASE}/environment"
fi

if [[  $STAGE == 4 || $STAGE == ALL ]] ; then
    # now build petsc with trilinos support
    mkdir -p ${BUILDBASE}/petsc
    "${SCRIPTBASE}/petsc.sh" "${BUILDBASE}/petsc" "${INSTALLBASE}/petsc" |& tee ${BUILDBASE}/petsc/logfile
    export PETSC_DIR="${INSTALLBASE}/petsc"
    cp ${BUILDBASE}/petsc/logfile ${INSTALLBASE}/petsc/build.log
    echo "export PETSC_DIR=\"${PETSC_DIR}\"" >> "${INSTALLBASE}/environment"
    echo "export HDF5_DIR=\"${PETSC_DIR}\"" >> "${INSTALLBASE}/environment"
fi


#mkdir -p ${BUILDBASE}/dealii
#DEALII_BUILD_TRILINOS=1 "${SCRIPTBASE}/dealii.sh" "${BUILDBASE}/dealii" "${INSTALLBASE}/dealii.trilinos" "" "${BUILDBASE}/dealii/build.trilinos" |& tee ${BUILDBASE}/dealii/logfile.trilinos
#cp ${BUILDBASE}/dealii/logfile.trilinos ${INSTALLBASE}/dealii.trilinos/build.log
#DEALII_BUILD_PETSC=1 "${SCRIPTBASE}/dealii.sh" "${BUILDBASE}/dealii" "${INSTALLBASE}/dealii.petsc" "" "${BUILDBASE}/dealii/build.petsc" |& tee ${BUILDBASE}/dealii/logfile.petsc
#cp ${BUILDBASE}/dealii/logfile.petsc ${INSTALLBASE}/dealii.petsc/build.log

#mkdir -p ${BUILDBASE}/sprng
#"${SCRIPTBASE}/sprng.sh" "${BUILDBASE}/sprng" "${INSTALLBASE}/sprng" |& tee ${BUILDBASE}/sprng/logfile
#export SPRNG_DIR="${INSTALLBASE}/sprng"
#cp ${BUILDBASE}/sprng/logfile ${INSTALLBASE}/sprng/build.log
#echo "export SPRNG_DIR=\"${SPRNG_DIR}\"" >> "${INSTALLBASE}/environment"

if [[ $STAGE == 5 || $STAGE == ALL ]] ; then
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
fi

if [[ $STAGE == 6 || $STAGE == ALL ]] ; then
    mkdir -p ${BUILDBASE}/moonolith
    "${SCRIPTBASE}/moonolith.sh" "${BUILDBASE}/moonolith" "${INSTALLBASE}/moonolith" |& tee "${BUILDBASE}/moonolith/logfile"
    export MOONOLITH_DIR="${INSTALLBASE}/moonolith"
    cp "${BUILDBASE}/moonolith/logfile" "${INSTALLBASE}/moonolith/build.log"
    echo "export MOONOLITH_DIR=\"${MOONOLITH_DIR}\"" >> "${INSTALLBASE}/environment"

    mkdir -p ${BUILDBASE}/utopia
    "${SCRIPTBASE}/utopia.sh" "${BUILDBASE}/utopia" "${INSTALLBASE}/utopia" |& tee ${BUILDBASE}/utopia/logfile
    export UTOPIA_DIR="${INSTALLBASE}/utopia"
    cp ${BUILDBASE}/utopia/logfile ${INSTALLBASE}/utopia/build.log
    echo "export UTOPIA_DIR=\"${UTOPIA_DIR}\"" >> "${INSTALLBASE}/environment"
fi

