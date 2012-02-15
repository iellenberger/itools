#!/usr/bin/perl -w
use lib qw( .. );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;
use iTools::System qw(
	colored verbosity vbase fatal indent
	vprint vprintf
	die warn
	system
	mkdir chdir mkcd symlink
);

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================

# === Tests =================================================================

print "\nVerbosity Settings\n";
tprint verbosity() == 0, "default verbosity level";
tprint verbosity(-1) == -1, "verbosity level -1";
tprint verbosity(2) == 2, "verbosity level 2";
tprint verbosity(0) == 0, "resetting verbosity";

print "\nsystem() Tests\n";
tprint system("ls > /dev/null") == 0, "system('ls')";

print "\chdir() Tests\n";
tprint chdir('.'), "chdir('.')";

sysfoo('foobar');

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');


sub sysfoo { CORE::system @_ };
