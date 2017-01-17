#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Puma;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $obj );

# === Constructor ===========================================================
print "\nConstruction and Core Accessors:\n";
$obj = new Puma;
tprint($obj, "object created");

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
