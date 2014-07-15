#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/..");

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::ModLoader;

use strict;
use warnings;

# === Module Loader Tests ===================================================
print "\nLoading Modules:\n";

# --- load a module ---
tprint(loadmodule('iTools::Acquire'), "loading module");
tprint($iTools::ModLoader::LASTMESSAGE =~ /successfully loaded/, "   first time load");

# --- reload the module ---
tprint(loadmodule('iTools::Acquire'), "reloading module");
tprint($iTools::ModLoader::LASTMESSAGE =~ /already loaded/, "   already loaded");

# --- try to load an invalid module (intentional failure) ---
tprint(!loadmodule('iTools::Acqwire'), "invalid module");
tprint($iTools::ModLoader::LASTMESSAGE =~ /Can't locate/, "   couldn't load");

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
