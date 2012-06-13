#!/bin/bash

# === Core Build script for Portia ==========================================

# --- add portia's bin and lib dirs to the path ---
export PATH=$BIN_ROOT/bin:$LIB_ROOT:$PATH

# --- import functions ---
source $LIB_ROOT/misc-functions.sh

# === Functions for Build Phase =============================================

# --- fetch the source tarballs ---
# fetches the source tarballs if defined in SRCFILES
# Initial working directory: DOWNLOAD_DIR
src_fetch() {
	# --- Add the default filename if SRCFILES is unset ---
	if [ -z ${SRCFILES+unset} ]; then SRCFILES=$PVR-src.tgz; fi

	# --- break out if still no SRCFILES ---
	if [ -z $SRCFILES ]; then return 0; fi

	# --- fetch each distfile ---
	local _SRCFILE
	for _SRCFILE in $SRCFILES; do

		local _SOURCE

		# --- figure out whether _SRCFILE is a URI ---
		if [[ $_SRCFILE =~ // ]]; then
			_SOURCE=$_SRCFILE
		else
			_SOURCE=$DISTFILES_URI/$_SRCFILE
		fi

		# --- fetch the source file ---
		vecho 1 "      fetching $_SRCFILE"
		vecho 2 "         from $_SOURCE"
		vecho 2 "         to $DOWNLOAD_DIR"
		acquire --noclobber -v $_SOURCE $DOWNLOAD_DIR

		# --- die on error ---
		if [ $? -gt 0 ]; then
			vecho -1
			vecho -1 "Unable to download $_SOURCE"
			vecho 0 "aborting install"
			exit 1
		fi
	done
}

# --- unpack the source tarballs ---
# This function is used to unpack all the sources in DOWNLOAD_DIR to WORK_DIR.
# Initial working directory: WORK_DIR
src_unpack() {
	# --- localize variables ---
	local _FILE

	# --- unpack each source tarball ---
	for _FILE in `ls $DOWNLOAD_DIR`; do
		#! TODO: implement unpack
		#unpack $_FILE
		tar xzf $DOWNLOAD_DIR/$_FILE
	done
}

# --- prepare source files ---
# All preparation of source code, such as application of patches, should be done here.
# Initial working directory: WORK_DIR
#src_prepare()    { return 0; }

# --- configure the source ---
# All necessary steps for configuration should be done here
# Initial working directory: WORK_DIR
# ex: ./configure
#src_configure()  { return 0; }

# --- compile the source ---
# compilation steps should be done here
# Initial working directory: WORK_DIR
# ex. make clean; make all
#src_compile()    { return 0; }

# --- run compilation tests ---
# Run all package specific test cases.
# The default is to run 'make check; make test'.
# Initial working directory: WORK_DIR
#src_test()       { return 0; }

# --- install to staging location ---
# Should contain everything required to install the package into STAGE_DIR
# Initial working directory: WORK_DIR
#src_install()    { return 0; }

# --- package up the installation ---
# Initial working directory: STAGE_DIR
# results should land in DISTFILES_DIR
src_pack() {
	vecho 1 "      creating tarball $PVR.tgz"
	vecho 2 "         from files in $PWD"
	vecho 2 "         placing tarball in $DISTFILES_DIR"
	tar czf $DISTFILES_DIR/$PVR.tgz .
}

# === Master Build Function =================================================

# --- build phase ---
portia_build() {
	vecho 0 "Building $CATEGORY/$PVR"

	# --- fetch the source ---
	mkdir -p "$DOWNLOAD_DIR"; cd "$DOWNLOAD_DIR"
	rmr_safe "$DOWNLOAD_DIR" DOWNLOAD_DIR
	vrun 0 "   fetching source" src_fetch

	# --- unpack the sources --- 
	mkdir -p "$WORK_DIR"; cd "$WORK_DIR"
	rmr_safe "$WORK_DIR" WORK_DIR
	vrun 0 "   unpacking source" src_unpack

	# --- prepare the sources --- 
	cd "$WORK_DIR"; vrun 0 "   preparing source" src_prepare

	# --- standard phases of a source build ---
	cd "$WORK_DIR"; vrun 0 "   configuring" src_configure
	cd "$WORK_DIR"; vrun 0 "   compiling" src_compile
	cd "$WORK_DIR"; vrun 0 "   testing" src_test

	# --- install to staging area ---
	mkdir -p "$STAGE_DIR"; cd "$STAGE_DIR"
	rmr_safe "$STAGE_DIR" PREINSTALL_DIR
	cd "$WORK_DIR";
	vrun 0 "   installing to staging area" src_install

	# --- pack up sources and drop the tarball in distfiles ---
	mkdir -p "$DISTFILES_DIR"
	cd "$STAGE_DIR"; vrun 0 "   generating portia distfile" src_pack

	vecho 0 "build complete"
}

