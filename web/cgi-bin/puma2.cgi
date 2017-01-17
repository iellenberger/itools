#!/usr/bin/perl -w

# --- modify thie path to point to your Puma libraries ---
use lib '/ITOOLS_ROOT/lib/perl5';

use Puma;

use strict;

my $puma = new Puma;
my $retval = $puma->render;
print $puma->html;

exit $retval ? 1 : 0;
