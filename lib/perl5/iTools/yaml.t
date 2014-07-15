#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/..");

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::YAML;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $obj );

my $refhash = {
	k1 => {
		k11 => "v11",
		k12 => {
			k121 => "v121",
			k122 => "v122",
		},
		k13 => "v13\ttab",
	},
	k2 => {
		k21 => "v21",
		k22 => {
			k221 => "v221",
			k222 => "v222",
		},
		k23 => "v23\ttab",
	}
};

my $refyaml = <<YAML;
k1:
	k11: v11
	k12:
		k121: v121
		k122: v122
	k13: v13	tab
k2:
   k21: v21
   k22:
      k221: v221
      k222: v222
   k23: v23	tab
YAML

# === Constructor Tests =====================================================
print "\nObject Construction:\n";

$obj = new iTools::YAML;
tprint $obj, "object created via new()";
tprint ref $obj eq 'iTools::YAML', "object class 'iTools::YAML'";
tprint $obj->VERSION eq $iTools::YAML::VERSION, "class version $iTools::YAML::VERSION";

print "\nVarious Simple Tests:\n";
tprint $obj->parse($refyaml), "parsed YAML with tabs";
$refyaml =~ s/\t(?!tab)/   /g;  # replace tabs wth spaces in reference YAML
$obj->indent(3);                # set indernt to 3
tprint $obj->render eq $refyaml, "rendered YAML from self with indent(3)";
tprint $obj->parse($refyaml), "rendered YAML from hash";

#! TODO: write more tests

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
