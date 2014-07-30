#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/..");

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging only
use iTools::Core::Test;
use HashRef::Flat qw( flatten );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $obj, $hash, $dump1, $dump2 );

my @exhash = (
	k1 => 'v1',
	{ k2 => 'v2' },
	k3 => {
		1 => 'v3.1',
		2 => { 1 => 'v3.2.1' },
		3 => [ qw( v3.3:0 v3.3:1 v3.3:2 ) ],
	},
	'k4:0' => 'v4:0',
	'k4:1' => 'v4:1',
	'k5:0' => { 1 => 'v5:0.1' },
);

# === Tests =================================================================

print "\nObject Construction and Seeding:\n";
$obj = new HashRef::Flat;
tprint $obj, "object created via new()";
tprint $obj->isa('HashRef::Flat'), "object class 'HashRef::Flat'";
tprint $obj->VERSION eq $HashRef::Flat::VERSION, "class version $HashRef::Flat::VERSION";
tprint $obj->merge(@exhash), "adding values via merge()";
hcmp($obj);

print "\nAdding Data:\n";
tprint $obj = flatten, "generating new object via flatten()";
tprint $obj->{k1} = 'v1', "adding scalar";
tprint $obj->{k2}->{1} = 'v2.1', "adding hash, indirect";
tprint !($obj->{k3} = { 1 => 'v3.1' }), "adding hash, direct";
tprint !($obj->{k4} = {
		1 => 'v4.1',
		2 => 'v4.2',
		3 => { 1 => { 1 => 'v4.3.1.1' }},
	}), "adding hash structure";
tprint $obj->{k5}->[0] = 'v5:0', "adding array, indirect";
tprint !($obj->{k6} = [ 'v6:0', 'v6:1' ]), "adding array, indirect";
hcmp($obj);

print Dumper($obj);

print "\nUnflattening:\n";
tprint $dump1 = Dumper($obj), "storing hash";
tprint $hash = $obj->unflatten, "unflattening hash";
tprint $dump2 = Dumper(flatten $hash), "reflattening and storing hash";
tprint $dump1 eq $dump2, "comparing stored hashes";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === Utility Methods =======================================================

# --- compare hash key/values ---
sub hcmp {
	my $hash = shift;

	print "Testing Flattened Hash\n";
	my @errors = 0;
	foreach my $key (sort keys %$hash) {
		my $val = $key;
		$val =~ s/^k/v/;
		tprint $hash->{$key} eq $val, "$key => $val ($hash->{$key})";
	}
}
