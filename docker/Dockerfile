##
# PASOE all-in-one, multi-stage build
##
# This rather lenthy docker file is a combination of several build files.
# There is plenty of room for improvement.
# As of this version, the resulting Docker image comes in ~ 935MB.
##
# The build expects two arguments which represent URLs for:
#   INSTRURI: OE batch install script - response.ini
#   PKGURI  : OE installation package - PROGRESS_OE_11.7.3_LNX_64_UPDATE.tar.gz
##
FROM debian:stretch-slim as oebase

ARG INSTALL_INI_SCRIPT
ARG TAR_PACKAGE

############################################################
# Speedup DPKG and don't use cache for packages
############################################################
# Taken from here: https://gist.github.com/kwk/55bb5b6a4b7457bef38d
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup; \
    #  we don't need and apt cache in a container
    echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache; \
    #  we don't need lanugage-related updates
    echo "Acquire::Languages \"none\";" > /etc/apt/apt.conf.d/no-langs \
    ;

#Default to UTF-8 file.encoding
ENV LANG C.UTF-8

# install dependencies needed for OE installation
# PSC PAS installer needs netstat commands: use busybox to keep it light
RUN set -e \
    && apt-get update \
    && apt-get install -y -q --no-install-recommends \
        busybox-static \
        curl \
        dumb-init \
        gettext-base \
    # 
    # just want the envsubst exec from gettext-base - throw the rest away.
    # this is isn't required for multi-stage builds
    && mv /usr/bin/envsubst /usr/local/bin/  \
    && apt-get purge gettext-base -y \
    #
    # setup busybox links
    && /bin/busybox --install -s \
    #
    # update alternatives fixes $DLC/servers/pasoe/bin/tcmanager.sh *issue*
    && { \
        update-alternatives --install /bin/sh sh /bin/bash 100; \
        update-alternatives --install /bin/sh sh /bin/dash 200; \
        update-alternatives --set sh /bin/bash; \
    } \
    # clean the apt residue : not entirely necessary
    #
    && apt-get autoclean \
    && apt-get autoremove \
    && apt-get clean \
    && rm -rfv /tmp/* \
    && rm -rfv /var/lib/apt \
    && rm -rfv /var/tmp/* \
    ## moar clean!
    && rm -rfv /etc/apt \
    && rm -rfv /etc/dpkg \
    && rm -rfv /usr/share/doc \
    && rm -rfv /var/cache/* \
    && rm -rfv /var/lib/dpkg \
    && rm -rfv /var/log/* \
    ;

# setup OE-specific paths and ports : required for initial creation
ENV OEVER="11.7.3" \
    DLC="/usr/dlc" \
    WRKDIR="/usr/wrk_dlc" \
    OEM="/usr/oemgmt" \
    OEMWRKDIR="/usr/wrk_oemgmt" \
    BPMSERVER_BIN="/usr/dlc/oebpm/server/bin" \
    PAS_PORT_HTTP="8080" \
    PAS_PORT_HTTPS="8443" \
    PAS_PORT_SHUT="-1" \
    PAS_PORT_AJP="8009"

COPY ${INSTALL_INI_SCRIPT} /tmp/.
ADD ${TAR_PACKAGE} /tmp/.


RUN set -e \
    && cd /tmp; mkdir -p oeinst \
    ##
    # Get Product Package
    ##    
    && ( echo "Extracting files ${TAR_PACKAGE} -> /tmp/oeinst ..."; \
            tar -xzf ${TAR_PACKAGE} -C oeinst \
       ) \
    && echo "Starting OE Install with: " \
	        "DLC=${DLC}" \
	        "WRKDIR=${WRKDIR}" \
	        "OEM=${OEM}" \
	        "OEMWRKDIR=${OEMWRKDIR}"; \
    # 
    # tailor the installer file
    #
    (   echo "Tailoring install file ... "; \
        envsubst < ${INSTALL_INI_SCRIPT} > instresponse.ini \
    ) \
    #
    # start install
    #
    && ( echo "Starting install ... "; \
         time ./oeinst/proinst -b instresponse.ini -l install_oe.log; \
         cat install_oe.log; \
       ); \
    ##
    # Clear OE License file
    #
    ( echo "Truncating license file: ${DLC}/progress.cfg"; \
      truncate --no-create -s 0 ${DLC}/progress.cfg \
    ); \
    ##
    # Clean-up
    ##
    echo "Processing Cleanup ..."; \
    ##
    # if this is a DEV license clear the oepas1 -- size reduction
    ##
    [ -d "$WRKDIR/oepas1" ] && ( \
       echo "Removing default 'oepas1' instance ..."; \
       $DLC/bin/pasman delete -y oepas1 1>/dev/null 2>&1; \
    ); \
    ##
    # ** DISABLED: the 11.7.3 Linux scripts are looking for .bat files ... :( 
    # Remove Windows cruft
    ##
    # find $DLC/servers/pasoe/bin -type f \( -name "*.bat" -o -name "*.ps1" \) -exec rm "{}" \; \
    ##
    rm -rf /tmp/*; \
    rm -rf /tmp/.pmtmp; \
    # ! Important to delete the $DLC/install folder
    rm -rf ${DLC}/install; \
    # Don't keep the archive/backup versions of files
    rm -rf ${DLC}/servers/pasoe/archive; \
    rm -rf ${DLC}/servers/redist; \
    ##
    # TODO: check for more cleaning that can be done
    ##
    echo "Completed OE install: " && cat $DLC/version;

  ##
  # TODO: download and install su-exec in oebase vs COPY.
  #       .sh scripts can be part of download package (eg. git clone)
  #       OR FROM owlab/alpine-su-exec as suexe
  ##
  COPY su-exec /usr/local/bin/
  COPY docker-entrypoint.sh /
  
  # setup permissions
  RUN set -e;  \
      chmod a+x /usr/local/bin/su-exec; \
      chmod a+x /docker-entrypoint.sh;
  
  #------------- Begin RUNTIME multi-stage build ---------------#
  # saves @ 10MB in size for OEPASPROD configuration vs mulit-dockerfile build
  
  FROM debian:stretch-slim
  
  COPY --from=oebase /usr/dlc/ /usr/dlc/
  COPY --from=oebase /bin/busybox /bin/busybox
  COPY --from=oebase /usr/bin/dumb-init /usr/bin/dumb-init
  COPY --from=oebase /usr/local/bin/su-exec /usr/local/bin/su-exec
  COPY --from=oebase /docker-entrypoint.sh /
  
  ##
  # NB: various compression techniques will clear environment variables
  #     from the prepared image.  It may be beneficial to define variables
  #     elsewhere downstream.
  ##
  
  # RUNTIME VARS : would be nice to be able to 'share' these between contexts
  ENV OEVER="11.7.3" \
      DLC="/usr/dlc" \
      WRKDIR="/usr/wrk_dlc" \
      OEM="/usr/oemgmt" \
      OEMWRKDIR="/usr/wrk_oemgmt" \
      BPMSERVER_BIN="/usr/dlc/oebpm/server/bin"
  
  # the PAS_PORT* do NOT have to match the install values.
  # the values here can be used to override the install defaults
  ENV PAS_PORT_HTTP="8080" \
      PAS_PORT_HTTPS="8443" \
      PAS_PORT_SHUT="-1" \
      PAS_PORT_AJP="8009" \
      PAS_ROOT="/opt/pas" \
      PAS_INST="pasoe" \
      OEUSER="oeuser" \
      OEUSER_UID="1000" \
      OEUSER_GID="1000"
  
  RUN set -e; \
      { echo '#!/bin/sh\nls -AlF --color=auto $@'; } >> /usr/local/bin/ll \
      && chmod a+x /usr/local/bin/ll \
      # update alternatives fixes $DLC/servers/pasoe/bin/tcmanager.sh *issue*
      && { \
          update-alternatives --install /bin/sh sh /bin/bash 100; \
          update-alternatives --install /bin/sh sh /bin/dash 200; \
          update-alternatives --set sh /bin/bash; \
      } \
      #
      # setup busybox links : need them ALL?
      # 
      && /bin/busybox --install -s \
      #
      # Add OE user
      && addgroup --gid ${OEUSER_GID} ${OEUSER} \
      && adduser --uid ${OEUSER_UID} --gid ${OEUSER_GID} --disabled-password \
                 --gecos GECOS --home /home/${OEUSER} --shell /bin/bash ${OEUSER} \
      ##
      # create PAS_ROOT
      ##
      && mkdir -p ${PAS_ROOT} && touch ${PAS_ROOT}/.placeholder \
      #
      # consider: chacl on PAS_ROOT
      #
      && chown -R ${OEUSER}:${OEUSER} /home/${OEUSER} \
      && chown -R ${OEUSER}:${OEUSER} ${PAS_ROOT} \
      ;    
  
  ## Setup Java environment: entrypoint could source $DLC/bin/java_env
  ENV JVMEXE="java" \
      THREADS_FLAG="native" \
      JREHOME="${DLC}/jdk/jre" \
      JDKHOME="${DLC}/jdk" \
      JAVAHOME="${DLC}/jdk" \
      JVM="${DLC}/jdk/jre/bin/java"
  
  ENV PASINSTPATH=${PAS_ROOT}/${PAS_INST}
  
  ENV LD_LIBRARY_PATH="${JREHOME}/lib/amd64:${JREHOME}/lib/amd64/native_threads:${JREHOME}/bin:${JREHOME}/lib/amd64/server:" \
      PROLIBPATH="${JREHOME}/lib/amd64:${JREHOME}/lib/amd64/native_threads:${JREHOME}/bin:${JREHOME}/lib/amd64/server:" \
      PATH="$DLC/bin:${BPMSERVER_BIN}:$DLC/perl/bin:$PATH"
  
  # Expose our known/default ports: these can be re-mapped or overridden later-on
  # !! DO NOT EXPOSE THE PAS_PORT_SHUT
  #      http             https              ajp
  EXPOSE ${PAS_PORT_HTTP} ${PAS_PORT_HTTPS}  ${PAS_PORT_AJP}
  
  # May want to define the PAS ROOT directory as a volume since there is 
  # mutable state therein
  # VOLUME ${PAS_ROOT}
  WORKDIR ${PAS_ROOT} 
  
  # provision PASOE 
  #   : import DLC TLS certs
  #   : create instance
  #   : import and update TC TLS certs
  # not performing during build would reduce image size, but increase container init overhead
  # for PROD PASOE (default):
  #    root must be used to run create
  #    11.7.3 -U option causes oeabl_tailor.sh to fail 
  #        -- chmod manually  OR
  #        -- use su-exec
  RUN set -e; \
      echo "Creating PAS Instance at: ${PASINSTPATH}"; \
      $DLC/bin/pasman create -v -N ${PAS_INST} ${PASINSTPATH}  \
      #find ${PASINSTPATH} -depth -type d -exec chown ${OEUSER}:${OEUSER} "{}" \; \
      #find ${PASINSTPATH} -depth -type f -exec chown ${OEUSER}:${OEUSER} "{}" \; \
      ;
  
  # Make the log folder a volume
  VOLUME [ ${PASINSTPATH}/logs ]
  
  # Run the container as a non-root user for sanity/safety
  # though: PROD PASOE needs root to do anything
  # if not setting non-ROOT user, be sure to use su-exec(or similar) to control
  # privilege execution in ENTRYPOINT
  # USER ${OEUSER}
  
  # allowing docker-entrypoint to use /bin/bash
  # ENTRYPOINT and CMD are only used during container start
  ENTRYPOINT [ "/usr/bin/dumb-init", "--", "/docker-entrypoint.sh" ]
  CMD [ "start" ]

#EOF
