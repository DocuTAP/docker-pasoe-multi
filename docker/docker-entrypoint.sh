#!/usr/bin/env bash

##
# NB: this file is a work-in-progress -- it is a good start, though
## 

set -e;

# Some commands MUST be run as ROOT, others as OEUSER

# environment

if [ "${PAS_START_DEBUG}" != "" ]; then
	echo "PARMS: $@"
	echo "PAS_ROOT: ${PAS_ROOT}"
	echo "PAS_INST: ${PAS_INST}"
	echo "PASINSTPATH: ${PASINSTPATH}"
	echo "UID: $(id -u)"
fi

TCMAN="${PASINSTPATH}/bin/tcman.sh";

function stoppas {
	#trap - HUP INT KILL TERM
	# trap - HUP INT KILL TERM QUIT STOP EXIT
	echo "Stop Detected: Stopping PASOE Service ...";

	#echo "issuing: ${TCMAN} stop -w 5 -F";
	#exec ${TCMAN} stop -w 5 -F; 

	exec ${PASINSTPATH}/bin/shutdown.sh

	exit 0;
}
trap stoppas HUP INT QUIT KILL TERM STOP
	
# check container init parameter:
case "$@" in

	"start" )
		# MAY NEED TO BE ROOT TO START
		#if [ ! "$(id -u)" == "0" ]; then
		#	echo "Container must be started as ROOT"
		#	exit 1;
		#fi

		# [ -f "${PAS_ROOT}/${PAS_ALIAS}.oeprops" ] && ./bin/oeprop.sh -f "${PAS_ROOT}/${PAS_ALIAS}.oeprops"
		
		# tcman config -f filehere

		# provision:
		#   OE CERTS - $DLC/bin/pkutils|certutils
		#   TLS CERT - ${catalina.root} certs

		# PROD PASOE doesn't auto-expand or auto-deply WAR files
		#  either:
		#     [temp] enable that facility
		#     OR
		#     expand WAR using task/[ant]script --watch for variable subst
		
		# ln -sf /dev/stdout ${PASINSTPATH}/logs/catalina.out

		su-exec "$OEUSER:0" ${TCMAN} start -v

		# hold container open: monitor TC instance
		while true; do
			echo "Waiting on PAS Start..."
			sleep 5;
			CATFILE=${PASINSTPATH}/logs/catalina.out
			echo Tailing ${CATFILE}

			# tailf uses inotify vs polling (like tail -f)
			#/bin/tailf ${CATFILE}
			#/bin/tailf /dev/null
			tail -f ${CATFILE} 
		done
		;;

	*)
		# when custom start command as ROOT, drop to oeuser with root group
		if [ "$(id -u)" = '0' ]; then
			exec su-exec "$OEUSER:0" $@
		else
			exec $@
		fi
		;;
esac
#EOF