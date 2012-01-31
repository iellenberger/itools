#!/usr/bin/perl -w
use lib qw( ../.. );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::XML::Parser;

use strict;
use warnings;

# === Globals and Constants =================================================
my $ERRORS = 0;
# --- the XML to parse ---
my $xml = <<XML;
<?xml version="1.0"?>
<parser name="test">
	<tag1 key1="value1">
		content1
	</tag1>
	<tag2 key1="value1" key2='value2' key3=`value3` key4=value4 />
	<tag2 key5="value5">
		content2
	</tag2>
</parser>
XML
# --- expected results ---
my $generated = '';
my $expected = <<EXPECTED;
--- Init ---
<?xml version="1.0"?>
<parser name="test" >
<tag1 key1="value1" >
content1
</tag1>
<tag2 key1="value1" key2="value2" key3="`value3`" key4="value4" >
</tag2>
<tag2 key5="value5" >
content2
</tag2>
</parser>
--- Final ---
EXPECTED

# === The Tests =============================================================
print "\n";

# --- constructor ---
my $parser = new iTools::XML::Parser;
tprint $parser, "iTools::XML::Parser construction";

# --- parsing ---
my $parsetree = $parser->parse(
	Text => $xml,
	XMLHandlers => {
		Init => \&init,
		Start => \&start,
		Char => \&char,
		End => \&end,
		Final => \&final,
	},
);
tprint $parsetree, "executing parser";

# --- test against expected results ---
tprint $generated eq $expected, 'received expected results';

# --- dump results if there were errors ---
if (tvar('errors')) {
	print "\nErrors were encountered.\n\n";
	print "Here's the results we expected:\n". _indent($expected);
	print "\nHere's what we actually got:\n". _indent($generated);
	print "\n";
}

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === Handlers ==============================================================
sub init {
	my $header = _trim(shift);
	$generated .= "--- Init ---\n$header\n";
}
sub start {
	my ($tag, %params) = @_;
	$generated .= "<$tag ";
	foreach my $key (sort keys %params) {
		$generated .= qq[$key="$params{$key}" ];
	}
	$generated .= ">\n";
}
sub char {
	my $content = _trim(shift);
	return unless $content;
	$generated .= "$content\n";
}
sub end {
	my $tag = shift;
	$generated .= "</$tag>\n";
}
sub final {
	$generated .= "--- Final ---\n";
}

# === Subs ==================================================================
sub _indent{$_[0]=~s/^/   /mg;shift}

sub _trim {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
