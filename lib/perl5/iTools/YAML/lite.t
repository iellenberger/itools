#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::YAML::Lite qw( yaml2hash hash2yaml );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $obj );

my $FILE = 'lite.yaml';

# --- modified sample from http://www.yaml.org/start.html ---
my $YAML = <<YAML;
--- !clarkevans.com/^invoice
invoice: 34843
date   : 2001-01-23
# comment no indent
bill-to:
    given  : Chris
    family : Dumars
    # comment, indented
    address:
        lines: |
            458 Walkman Dr.
            Suite #292
        city    : Royal Oak
        state   : MI
        postal  : 48046
array:
	- one
	- two
product:
    - sku         : BL394D
      quantity    : 4
      description : Basketball
      price       : 450.00
    - sku         : BL4438H
      quantity    : 1
      description : Super Hoop
      price       : 2392.00
tax  : 251.42
total: 4443.52
comments: >
\tLate afternoon is best.
\tBackup contact is Nancy
\tBillsmer @ 338-4338.
YAML

# === Constructor and Accessor Tests ========================================
print "\nConstruction and Accessors:\n";

# --- no parameters ---
print "  without parameters:\n";
$obj = new iTools::YAML::Lite;
tprint $obj, "object created";
tprint ref $obj eq 'iTools::YAML::Lite', "object class 'iTools::YAML::Lite'";
tprint $obj->VERSION eq $iTools::YAML::Lite::VERSION, "class version $iTools::YAML::Lite::VERSION";
tprint !defined $obj->file,  "   ->file(undef)";
tprint !defined $obj->hash,  "   ->hash(undef)";
tprint !defined $obj->text,  "   ->text(undef)";
tprint !defined $obj->tab,   "   ->tab(undef)";
tprint $obj->indent eq ' ' x $iTools::YAML::Lite::INDENT,  "   ->indent($iTools::YAML::Lite::INDENT)";

# --- with parameters ---
print "  with parameters:\n";
$obj = new iTools::YAML::Lite(
	File => $FILE,
	Hash => { test => 1 },
	YAML => $YAML,  # a.k.a. Text
	Tab  => 0,
	Indent => 4,
);
tprint $obj, "object created";
tprint $obj->file eq $FILE,     "   ->file('$FILE')";
tprint $obj->hash->{test} == 1, "   ->hash( { test => 1 } )";
tprint $obj->text eq $YAML,     "   ->text([blob of YAML])";
tprint $obj->tab eq 0,          "   ->tab(0)";
tprint $obj->indent eq ' ' x 4, "   ->indent(4)";

# --- accessors alone ---
print "  accessors only\n";
tprint $obj->file('foo') eq 'foo', "   ->file('foo')";
tprint $obj->text('bar') eq 'bar', "   ->text('bar')";
tprint $obj->tab(1)      == 1,     "   ->tab(1)";
tprint $obj->indent(2)   eq '  ',  "   ->indent(2)";

# --- tab accessors ---
print "  tab accessors: undef\n";
$obj->tab(undef);
tprint !defined $obj->tab,    "   ->tab(undef)";
tprint $obj->tval == 0,       "   ->tval(0)";
tprint $obj->tstr eq ' ' x $iTools::YAML::Lite::TAB, "   ->tstr(' 'x$iTools::YAML::Lite::TAB)";
print "  tab accessors: -1\n";
$obj->tab(-1);
tprint $obj->tab == -1,       "   ->tab(-1)";
tprint $obj->tval == -1,      "   ->tval(-1)";
tprint $obj->tstr eq ' ' x $iTools::YAML::Lite::TAB, "   ->tstr(' 'x$iTools::YAML::Lite::TAB)";
print "  tab accessors: 0\n";
$obj->tab(0);
tprint $obj->tab == 0,        "   ->tab(0)";
tprint $obj->tval == 0,       "   ->tval(0)";
tprint $obj->tstr eq ' ' x $iTools::YAML::Lite::TAB, "   ->tstr(' 'x$iTools::YAML::Lite::TAB)";
print "  tab accessors: 1\n";
$obj->tab(1);
tprint $obj->tab == 1,        "   ->tab(1)";
tprint $obj->tval == 1,       "   ->tval(1)";
tprint $obj->tstr eq ' ',     "   ->tstr(' ')";
print "  tab accessors: 8\n";
$obj->tab(8);
tprint $obj->tab == 8,        "   ->tab(8)";
tprint $obj->tval == 8,       "   ->tval(8)";
tprint $obj->tstr eq ' 'x 8 , "   ->tstr(' 'x8)";
print "  tab accessors: '    '\n";
$obj->tab('    ');
tprint $obj->tab eq '    ',   "   ->tab('    ')";
tprint $obj->tval == 4,       "   ->tval(4)";
tprint $obj->tstr eq '    ',  "   ->tstr('    ')";



$obj = new iTools::YAML::Lite(
	YAML => $YAML,
	Tab  => 3,
);
my $hash = $obj->parse;
# print Dumper($hash);

$hash = yaml2hash(YAML => $YAML, TAB => 3);

print Dumper($hash);


# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
