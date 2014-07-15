#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=0; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;
use iTools::Script::Options;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $obj, $uri );

# === Tests =================================================================
print "\nConstruction:\n";
$obj = new iTools::Script::Options;
tprint $obj, "object created";
tprint $obj->CLASS eq 'iTools::Script::Options', "object class 'iTools::Script::Options'";
tprint $obj->VERSION eq $iTools::Script::Options::VERSION, "class version $iTools::Script::Options::VERSION";

print "\nCore Accessors:\n";
tprint $obj->verbosity(1) eq '1', "Verbosity set to 1";


# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
