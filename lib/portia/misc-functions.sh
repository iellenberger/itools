#!/bin/bash

# --- move without overwrite ---
# The BSD 'mv' command has a '-n' option not available in the GNU/FSF version.
# This function emulates that behaviour across all systems
mv_n() {
	SRC=$1; DEST=$2
	# --- don't overwrite DEST ---
	if [ -e $DEST ]; then return 0; fi
	vecho 2 "      moving $SRC -> $DEST"
	mv $SRC $DEST
}

# --- mkdir replacement ---
mkdir_safe() {
	local _DIR=$1; local _LABEL=$2

	# --- make sure we have at least a fake label name ---
	if [ -z $_LABEL ]; then $_LABEL='directory'; fi

	# --- create the dir and its parents ---
	if [ ! -e $_DIR ]; then
		vecho 1 "      creating $_LABEL '$_DIR'"
		mkdir -p $_DIR
		# --- unable to create dir ---
		if [ ! -d $_DIR ]; then
			vecho -1
			vecho -1 "Unable to create '$_DIR'"
			vecho 0 "Please ensure that that the parent directory exists"
			vecho 0 "   and is writable by $USER, or run the program as another user"
			exit 1
		fi

	# --- another file is in the way ---
	elif [ ! -d $_DIR ]; then
		vecho -1
		vecho -1 "'$_DIR' is not a directory"
		vecho 0 "Another file is in the way.  Please remove it"
		exit 1

	# --- directory not writable ---
	elif [ ! -w $_DIR ]; then
		vecho -1
		vecho -1 "'$_DIR' is not writable"
		vecho 0 "Change permissions so that it writable by $USER"
      vecho 0 "   or run the program as another user"
		exit 1
	fi
}

# --- a safeer version of mkdir + pushd + rm -r ---
rmr_safe() {
	local _DIR=$1; local _LABEL=$2

	# --- PWD must be at least 10 characters long ---
	if [ ${#PWD} -lt 10 ]; then

		# --- make sure we have at least a fake label name ---
		if [ -z $_LABEL ]; then $_LABEL='directory'; fi

		# --- spit out an error message ---
		echo "Unsafe operation: $_LABEL (PWD) is less then 10 characters long"
		echo "   $_LABEL = '$_DIR', length ${#_DIR}"
		echo "   PWD = '$PWD', length ${#PWD}"
		echo "Cowardly refusing to perform an rm -rf *"
		echo "   rmr_safe() exiting"

		# --- exit with error code ---
		exit 1
	fi

	# --- if we got here, we should be safe ---
	vecho 2 "      deleting $PWD/*"
	rm -rf $PWD/*
}

# --- echo based on verbosity level ---
vecho() {
	local _VERBOSITY=$1; shift

	if [ $VERBOSITY -ge $_VERBOSITY ]; then
		echo "$*"
	fi
}

# --- run a function with a message ---
vrun() {
	local _VERBOSITY=$1; shift
	local _MESSAGE=$1;   shift
	local _FUNCTION=$1

	if [ "$( type -t $_FUNCTION )" == 'function' ]; then
		vecho $_VERBOSITY "$_MESSAGE"
		$*
	fi
}

# --- run a function if it exists ---
run_fn() {
	local _FUNCTION=$1
	if [ "$( type -t $_FUNCTION )" == 'function' ]; then
		$*
	fi
}
