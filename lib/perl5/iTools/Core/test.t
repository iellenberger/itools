#!/usr/bin/perl -w
use lib qw( ../.. );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $accessor, $value );

print "\nColored Tests:\n";
tprint 1, 'forced success test (this message should be green)';
tprint tvar('errors') == 0, 'error count at 0';
tprint tvar('warnings') == 0, 'warning count at 0';
tprint 0, 'forced failure test (this message should be red)';
tprint tvar('errors') == 1, 'error count at 1';
tprint tvar('warnings') == 0, 'warning count at 0';
tprint 1;
tprint tvar('errors') == 1, 'error count at 1';
tprint tvar('warnings') == 1, 'warning count at 1';
tprint tvar(errors => tvar('errors') - 1) == 0, 'error count reset';
tprint tvar(warnings => tvar('warnings') - 1) == 0, 'warning count reset';

print "\nMonochrome Tests:\n";
tprint tvar(color => 0) == 0, 'color disabled';
tprint 1, 'forced success test (this message should not be green)';
tprint tvar('errors') == 0, 'error count at 0';
tprint tvar('warnings') == 0, 'warning count at 0';
tprint 0, 'forced failure test (this message should not be red)';
tprint tvar('errors') == 1, 'error count at 1';
tprint tvar('warnings') == 0, 'warning count at 0';
tprint 1;
tprint tvar('errors') == 1, 'error count at 1';
tprint tvar('warnings') == 1, 'warning count at 1';
tprint tvar(errors => tvar('errors') - 1) == 0, 'error count reset';
tprint tvar(warnings => tvar('warnings') - 1) == 0, 'warning count reset';

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
