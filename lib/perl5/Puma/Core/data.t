#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Puma::Core::Data;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$data,
);

# === Constructor and Accessors =============================================
print "\nConstructor and Accessors:\n";
$data = new Puma::Core::Data;
tprint($data, "constructor");
print Dumper($data);

print "foo1\n";
$data->fetch(config => 'foo1');
print "foo2\n";
fetch Puma::Core::Data(server => 'foo2');

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
