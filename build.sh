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
#   BASEURI : URI for where installation script and package are available
#   PKGDELIVERY_PATH : path URI to the OE installation package: progress_<ver>_tar.gz
#   INSTFILE_PATH    : path URI to the OE silent installation file
##
set -e

# Label and vers for project image
declare -a VERS

LABEL="pscservices/pasoeprod"
VERS=( 11.7.3 latest )
BASEURI="http://172.17.0.1"

# path to the installation file: lnx64.tar.gz
PKGDELIVERY_PATH=PROGRESS_OE_11.7.3_LNX_64_UPDATE.tar.gz
INSTFILE_PATH=prod_11.7.3_response.ini

################################################################################

RMILIST=""
BUILDTAGS=""
for v in ${VERS[@]}; do
   RMILIST+=" ${LABEL}:${v}";
   BUILDTAGS+=" -t ${LABEL}:${v}";
done

export PKGURI="${BASEURI}:8000";
export INSTURI="${BASEURI}:8001";

# ncat - part of nmap
ncat -lp 8000 < ${PKGDELIVERY_PATH} &
nc_pid1=$!

ncat -lp 8001 < ${INSTFILE_PATH} &
nc_pid2=$!

( docker rmi -f ${RMILIST} 1>/dev/null 2>&1 );

pushd docker; 
docker build \
   --rm \
   --build-arg INSTURI="${INSTURI}" \
   --build-arg PKGURI="${PKGURI}" \
   ${BUILDTAGS} \
   .
popd;

# use this for build testing
# docker run --rm -ti --name oepastest -e INSTURI -e PKGURI ${LABEL}:latest


if [ ! -z $nc_pid1 ]; then
        ( kill $nc_pid1 2>/dev/null || true )
fi

if [ ! -z $nc_pid2 ]; then
        ( kill $nc_pid2 2>/dev/null || true )
fi

#EOF
