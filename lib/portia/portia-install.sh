#!/bin/bash

# === Core Install Script for Portia ========================================

# --- add portia's bin and lib dirs to the path ---
export PATH=$BIN_ROOT/bin:$LIB_ROOT:$PATH

# --- import functions ---
source $LIB_ROOT/misc-functions.sh

# === Functions for Install Phase ===========================================

# --- fetch the binary tarballs ---
# fetches the binary tarballs if defined in BIN_URI
# Initial working directory: DOWNLOAD_DIR
bin_fetch() {
	# --- localize variables ---
	local _BINARY

	# --- only fetch if we havn't already done so ---
	if [ ! -e $DISTFILES_DIR/$PVR.tgz ]; then
		# --- die if we can't locate a binary tarball ---
		if [ -z $BIN_URI ]; then
			vecho -1
			vecho -1 "Unable to locate binary tarball(s)";
			vecho 0 "The package does not have a BIN_URI defined"
			vecho 0 "   and has not been locally built"
			exit 1
		fi

		# --- fetch each source file ---
		for _BINARY in $BIN_URI; do
			vecho 1 "      fetching $PVR.tgz"
			vecho 2 "         from $_BINARY"
			vecho 2 "         to $DOWNLOAD_DIR"
			acquire --noclobber -q $_BINARY $DOWNLOAD_DIR/$PVR.tgz
		done

	# --- just link the tarball if we already have it locally ---
	else
		vecho 1 "      found cached $PVR.tgz"
		vecho 2 "         symlinking to $DOWNLOAD_DIR"
		ln -s $DISTFILES_DIR/$PVR.tgz $DOWNLOAD_DIR/$PVR.tgz
	fi
}

# --- unpack the binary tarballs ---
# This function is used to unpack all the binaries in DOWNLOAD_DIR to STAGE_DIR.
# Initial working directory: STAGE_DIR
bin_unpack() {
	# --- localize variables ---
	local _FILE

	# --- unpack each binary tarball ---
	vecho 2 "         in" $( pwd )
	for _FILE in `ls $DOWNLOAD_DIR`; do
		#! TODO: implement unpack
		#unpack $_FILE
		vecho 1 "      unpacking $_FILE"
		tar xzf $DOWNLOAD_DIR/$_FILE
	done
}

# --- prepare binary files ---
# All preparation of the installed code should be done here.
# Initial working directory: STAGE_DIR
#bin_prepare() { return 0; }

# --- pre-install live filesystem modification script ---
# All modifications required on the live-filesystem before the
# package is merged should be placed here. Also commentary for the user  
# should be listed here as it will be displayed last.
#bin_preinstall() { return 0; }

# --- generate manifests ---
bin_manifest() {
	# --- make sure that INSTALL_ROOT exists ---	
	mkdir_safe $INSTALL_ROOT 'INSTALL_ROOT'

	# --- symlink INSTALL_ROOT to make commands cleaner ---
	ln -s $INSTALL_ROOT live

	# --- generate the live and stage manifests ---
	vecho 2 "         in" $( pwd )
	vecho 1 "      generating stage.mf"
	manifest generate -qrTb $STAGE_DIR -O stage.mf
	vecho 1 "      generating live.mf"
	manifest generate -qTb $INSTALL_ROOT @stage.mf -O live.mf

	# --- get the current manifest ---
	vecho 1 "      fetching current.mf"
	if [ -e $DB_DIR/current.mf ]; then
		cp $DB_DIR/current.mf current.mf
	else
		# --- use empty manifest if no current ---
		touch current.mf
	fi
}

# --- installation script ---
bin_install() {
	# --- make sure things are in order before doing anyting ---
	mkdir_safe $INSTALL_ROOT 'INSTALL_ROOT'
	mkdir_safe $DB_DIR 'DB_DIR'

	# -- copy changed files from live to stage ---
	vecho 1 "      saving changed files"
	for _FILE in `manifest diff --changed -F fl current.mf live.mf`; do
		if [ -e $STAGE_DIR/$_FILE ]; then
			vecho 2 "         file '$_FILE' changed"
			mv $STAGE_DIR/$_FILE $STAGE_DIR/$_FILE.new
			cp $INSTALL_ROOT/$_FILE $STAGE_DIR/$_FILE
		fi
	done

	# --- remove deleted files from live ---
	vecho 1 "      removing deleted files"
	for _FILE in `manifest diff -oF fl current.mf stage.mf`; do
		vecho 2 "         deleting '$_FILE'"
		rm -f $INSTALL_ROOT/$_FILE
	done

	# --- remove empty directories from live ---
	vecho 1 "      removing empty directories"
	for _DIR in `manifest list -F d current.mf`; do
		if [ -d $_DIR ] && [ -n "$( ls -A $_DIR )" ]; then
			vecho 2 "         deleting '$_DIR/'"
			rmdir $_DIR
		fi
	done
	
	# --- install files ---
	vecho 1 "      installing files"
	vecho 2 "         to $INSTALL_ROOT"
	rsync -a $STAGE_DIR/ $INSTALL_ROOT/
	
	# --- copy stage manifest to DB_DIR ---
	vecho 1 "      saving new manifest"
	vecho 2 "         in $DB_DIR"
	cp stage.mf $DB_DIR/$PVR.mf
	ln -f $DB_DIR/$PVR.mf $DB_DIR/current.mf
}

# --- post-install live filesystem modification script ---
# All modifications required on the live-filesystem after the
# package is merged should be placed here. Also commentary for the user  
# should be listed here as it will be displayed last.
#bin_postinstall() { return 0; }

# --- other pkg_ functions in portage ---
#bin_prerm()     { return 0; }
#bin_postrm()    { return 0; }
#bin_config()    { return 0; }
#bin_pretend()   { return 0; }
#bin_nofetch()   { return 0; }
#bin_setup()     { return 0; }

# === Master Install Function ===============================================

# --- install phase ---
portia_install() {
	vecho 0 "Installing $C/$PVR"

   # --- make sure we have a clean work root ---
	mkdir -p "$PWORK_DIR"; cd "$PWORK_DIR"
	rmr_safe "$PWORK_DIR" PWORK_DIR

	# --- fetch the binaries ---
	mkdir -p "$DOWNLOAD_DIR"; cd "$DOWNLOAD_DIR"
	vrun 0 "   fetching binaries" bin_fetch

	# --- unpack the binaries --- 
	mkdir -p "$STAGE_DIR"; cd "$STAGE_DIR"
	vrun 0 "   unpacking binaries" bin_unpack

	# --- prepare the binaries --- 
	cd "$STAGE_DIR"; vrun 0 "   preparing binaries" bin_prepare

	# --- installation scripts ---
	cd "$STAGE_DIR"; vrun 0 "   running pre-installation script" bin_preinstall
	cd "$PWORK_DIR"; vrun 0 "   generating manifests" bin_manifest
	cd "$PWORK_DIR"; vrun 0 "   running installation script" bin_install
	cd "$STAGE_DIR"; vrun 0 "   running post-installaion script" bin_postinstall

	vecho 0 "$PVR installed"
}
