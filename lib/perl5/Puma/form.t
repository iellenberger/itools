#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Puma::Form;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$form,
);

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
