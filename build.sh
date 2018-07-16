#!/bin/bash

##
# This script removes and builds the image according to label, and ver tag vars.
#
# The OE silent installation file is expected to have your PASOE license code
# and any other options already generated.  As well, the folders and PASOE ports
# can be tokenized and will be replaced at build-time using envsubst.
# See the example file: example_11.7.3_response.ini
##
# Change the variables below:
#   LABEL   : the repository label for the resulting image
#   VERS    : the tags that should be applied to the image
##
set -e

# Label and vers for project image
declare -a VERS

LABEL="pscservices/pasoeprod"
VERS=( 11.7.3 latest )
TARBALL_FILE="PROGRESS_OE_11.7.3_LNX_64_UPDATE.tar.gz"

################################################################################

# Stage files in /tmp for install in Dockerfile
cd docker
ln -s ${TARBALL_FILE} progress-linux.tar.gz

RMILIST=""
BUILDTAGS=""
for v in ${VERS[@]}; do
   RMILIST+=" ${LABEL}:${v}";
   BUILDTAGS+=" -t ${LABEL}:${v}";
done

docker rmi -f ${RMILIST} 1>/dev/null 2>&1

echo "BUILD TAGS: ${BUILDTAGS} -t app"
docker build \
   --rm \
   ${BUILDTAGS} -t app \
   .
