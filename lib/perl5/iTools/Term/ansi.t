#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::Term::ANSI qw(
	color colored cpush cpop
);

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my $obj;

# === Tests =================================================================

print "\nConstructor and Core Accessors:\n";
$obj = new iTools::Term::ANSI;
tprint $obj, "object created";
#tprint $obj->CLASS eq 'iTools::Term::ANSI', "object class 'iTools::Term::ANSI'";
tprint $obj->VERSION eq $iTools::Term::ANSI::VERSION, "class version $iTools::Term::ANSI::VERSION";

print "\nColor Management:\n";
tprint colored(), "colors enabled by default";

print "\nVisual Tests:\n";
print "    Normal: ". cpush('r') ."Red ". cpush('g') ."Green ". cpush('b') ."Blue ".
	cpop ."Green ". cpop ."Red ". cpop ."White". cpop ."\n";
print "    Bold:   ". cpush('*', 'R') ."Red ". cpush('G') ."Green ". cpush('B') ."Blue ".
	cpop ."Green ". cpop ."Red ". cpop ."White". cpop ."\n";

#print Dumper($iTools::Term::ANSI::colormap);

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');


