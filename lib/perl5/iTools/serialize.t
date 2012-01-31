#!/usr/bin/perl -w
use lib qw( .. );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::Serialize;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$serial, $data
);
my $file = "serial.$$";

# === Export Tests ==========================================================
print "\nExport Tests:\n";
tprint !-e $file, "clean file test";
tprint serialize({ foo => 'bar' }, $file), "data serialized";
tprint -e $file, "file exists";
tprint $serial = unserialize($file), "data unserialized";
tprint $serial->{foo} eq 'bar', "data integrity test";
unlink $file;
tprint !-e $file, "file removed";

# === Object Serialization ==================================================
print "\nObject Serialization Tests:\n";
tprint $serial = new Test::Class1, "object created";
tprint $serial->serialize($file), "object serialized";
tprint -e $file, "file exists";
tprint $data = $serial->unserialize($file), "object unserialized";
tprint ref $data eq 'Test::Class1', "object integrity test";
unlink $file;
tprint !-e $file, "file removed";

# === Object Data Serialization =============================================
print "\nObject Data Serialization Tests:\n";
tprint $serial = new Test::Class2, "object created";
tprint $serial->serial({ foo => 'bar' }), "object populated";
tprint $serial->serialize($file), "data serialized";
tprint -e $file, "file exists";
tprint $data = $serial->unserialize($file), "data unserialized";
tprint $data->{foo} eq 'bar', "data integrity test";
unlink $file;
tprint !-e $file, "file removed";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === Test Objects ==========================================================
package Test::Class1;
use base 'iTools::Serialize';

package Test::Class2;
use base 'iTools::Serialize';
sub serial { defined $_[1] ? $_[0]->{_data} = $_[1] : $_[0]->{_data} }
