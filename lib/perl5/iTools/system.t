#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/..");

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;
use iTools::System qw(
	fatal
	die warn
	system
	mkdir chdir mkcd symlink
);

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================

# === Tests =================================================================

print "\nsystem() Tests\n";
tprint system("ls > /dev/null") == 0, "system('ls')";

print "\chdir() Tests\n";
tprint chdir('.'), "chdir('.')";

#sysfoo('foobar');

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');


sub sysfoo { CORE::system @_ };
