#!/bin/bash

##
# This script removes and builds the image according to label, and ver tag vars.
# The installation files are expected to be provided to the build via URL.
#
# This example uses "ncat" to provide local files. The host system must have 
#  ncat available to provide the files.
#
# The OE silent installation file is expected to have your PASOE license code
# and any other options already generated.  As well, the folders and PASOE ports
# can be tokenized and will be replaced at build-time using envsubst.
# See the example file: example_11.7.3_response.ini
##
# Change the variables below:
#   LABEL   : the repository label for the resulting image
#   VERS    : the tags that should be applied to the image
#   PKGDELIVERY_PATH : path URI to the OE installation package: progress_<ver>_tar.gz
#   INSTFILE_PATH    : path URI to the OE silent installation file
##
set -e

# Label and vers for project image
declare -a VERS

LABEL="pscservices/pasoeprod"
VERS=( 11.7.3 latest )

# path to the installation file: lnx64.tar.gz
PKGDELIVERY_PATH='https://s3.amazonaws.com/release-phi-docutap/progress-artifacts/PROGRESS_OE_11.7.3_LNX_64_UPDATE.tar.gz'
INSTFILE_PATH=prod_11.7.3_response.ini

################################################################################

RMILIST=""
BUILDTAGS=""
for v in ${VERS[@]}; do
   RMILIST+=" ${LABEL}:${v}";
   BUILDTAGS+=" -t ${LABEL}:${v}";
done

export TAR_PACKAGE=${PKGDELIVERY_PATH};
export INSTALL_INI_SCRIPT=${INSTFILE_PATH};

( docker rmi -f ${RMILIST} 1>/dev/null 2>&1 );

pushd docker; 
docker build \
   --rm \
   --build-arg INSTALL_INI_SCRIPT="${INSTALL_INI_SCRIPT}" \
   --build-arg TAR_PACKAGE="${TAR_PACKAGE}" \
   ${BUILDTAGS} \
   .
popd;

