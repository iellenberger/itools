#!/usr/bin/perl -w
use lib qw ( .. );

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use HashRef::NoCase qw( nchash );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $hash );

# === Tests =================================================================
print "\nHash Creation/Seeding\n";
$hash = nchash( Foo => 'bar', bar => 'Foo' );
tprint $hash, "hash created";
tprint $hash->{Foo} eq 'bar' && $hash->{bar} eq 'Foo', "found seeded values, case-sensitive";
tprint $hash->{foo} eq 'bar' && $hash->{Bar} eq 'Foo', "found seeded values, case-insensitive";

print "\nHash Manipulation\n";
tprint !exists $hash->{foofoo},  "exists,  negative test";
tprint !defined $hash->{foofoo}, "defined, negative test";
tprint !delete $hash->{foofoo},  "delete,  negative test";
$hash->{FOOFOO} = 'barbar';
tprint exists $hash->{foofoo},  "exists,  positive test";
tprint defined $hash->{foofoo}, "defined, positive test";
tprint delete $hash->{foofoo},  "delete,  positive test";

print "\nHash Clear and Reuse\n";
$hash->clear;
tprint ! keys %$hash, "hash cleared";
$hash->{FOOFOO} = 'barbar';
tprint $hash->{foofoo} eq 'barbar', "hash reused";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
