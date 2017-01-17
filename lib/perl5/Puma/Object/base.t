#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Puma::Object::Base;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$base,
);

# === Constructor and Accessors =============================================
print "\nConstructor and Accessor Tests\n";
$base = new Puma::Object::Base;
tprint($base, "object construction");
tprint($base->objectType eq 'Base', "object identified as 'Base'");

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
