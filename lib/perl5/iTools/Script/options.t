#!/usr/bin/perl -w
use lib qw( ../.. );

use Data::Dumper; $Data::Dumper::Indent=0; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;
use iTools::Script::Options;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================

# === Tests =================================================================

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
