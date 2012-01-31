#!/usr/bin/perl -w
use lib qw( .. /opt/iTools/lib );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging

use iTools::Core::Test;
use HashRef::Maskable qw( mhash );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$obj, $pub, $priv, $untied,
);

# === Constructor Tests =====================================================
print "\nObject Construction:\n";

print "  via new():\n";
$obj = new HashRef::Maskable;
tprint $obj, "object created via new()";
tprint ref $obj eq 'HashRef::Maskable', "object class 'HashRef::Maskable'";
tprint $obj->VERSION eq $HashRef::Maskable::VERSION, "class version $HashRef::Maskable::VERSION";

print "  via mhash() with seed:\n";
$obj = mhash(seed => 'mhash seed');
tprint $obj, "object created via mhash()";
tprint ref $obj eq 'HashRef::Maskable', "object class 'HashRef::Maskable'";
tprint $obj->VERSION eq $HashRef::Maskable::VERSION, "class version $HashRef::Maskable::VERSION";
tprint $obj->{seed} eq 'mhash seed', "hash seeded";

print "  via subclass:\n";
$obj = new myHash;
tprint $obj, "subclass object created";
tprint ref $obj eq 'myHash', "object class 'myHash'";

# === Public and Private Keys ===============================================
print "\nPublic and Private Keys:\n";

$obj = mhash();
tprint $obj->{public} = 1,    "public value stored";
tprint $obj->{public} == 1,   "public value fetched";
tprint $obj->{_private} = 2,  "private value stored";
tprint $obj->{_private} == 2, "private value fetched";

($pub, $priv) = (0, 0);
map {
	$pub  = 1 if $_ eq 'public'   && $obj->{$_} == 1;
	$priv = 1 if $_ eq '_private' && $obj->{$_} == 2;
} keys %$obj;
tprint $pub,   "public key exposed";
tprint !$priv, "private key hidden";

($pub, $priv) = (0, 0);
map {
	$pub  = 1 if $_ eq 'public'   && $obj->{$_} == 1;
	$priv = 1 if $_ eq '_private' && $obj->{$_} == 2;
} keys %{untied $obj};
tprint $pub,   "public key exposed via untied()";
tprint $priv, "private key exposed via untied()";

# === Untied Hash ===========================================================
print "\nUntied Hash:\n";

$untied = untied $obj;
tprint !($untied->{'unfetch'}),         "FETCH not trapped";
tprint !($untied->{'unstore'} = ''),    "STORE not trapped";
tprint !(exists $untied->{'unexists'}), "EXISTS not trapped";
tprint !(delete $untied->{'undelete'}), "DELETE not trapped";

# === Subclass Tests ========================================================
print "\nSubclass Traps:\n";

print "  Tied Hash:\n";
$obj = new myHash;
tprint $obj->{'fetch'},         "FETCH trapped";
tprint $obj->{'store'} = '',    "STORE trapped";
tprint exists $obj->{'exists'}, "EXISTS trapped";
tprint delete $obj->{'delete'}, "DELETE trapped";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === Test Class ============================================================
package myHash;
use base 'HashRef::Maskable';

sub new { shift->mhash(@_) }

sub _fetch  {
	return 1 if $_[1] eq 'store';  # STORE calls FETCH, avoid extra message
	::tprint $_[1] eq 'fetch',  "FETCH called";
	return 1
}

sub _store  { ::tprint $_[1] eq 'store',  "STORE called";  1 }
sub _exists { ::tprint $_[1] eq 'exists', "EXISTS called"; 1 }
sub _delete { ::tprint $_[1] eq 'delete', "DELETE called"; 1 }

1;
