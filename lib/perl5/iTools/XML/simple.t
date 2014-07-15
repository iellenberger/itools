#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::XML::Simple qw( simplexml2hash simplehash2xml );

use strict;
use warnings;

# === Globals and Constants =================================================
my $FILE = 'simple.xml';

# === Simple Tests ==========================================================
print "\nCreate scenarios:\n";

# --- create hash from text ---
my $text = <<TEXT;
<?xml version="1.0"?>
<simple name="test">
	<foo>bar</foo>
	<encodetag1 lt="&lt;">&quot;</encodetag1>
	<tagone name="one" />
	<tagtwo part="one">
		II part one
	</tagtwo>
	<tagtwo part="two">
		II part two
	</tagtwo>
	<tagthree name="three" part="one" line="getting long"/>
	<tagfour name="four"><tagfour1 name="four1"/><tag42/></tagfour>
</simple.t>
TEXT
my $hash = simplexml2hash(Text => $text);
# print $text . simplehash2xml(Hash => $hash, Indent => "   ");
tprint $hash->{simple}->{name} eq 'test', "simplexml2hash from text";

# --- create text from hash and write to file ---
$text = simplehash2xml(
	File      => $FILE,
	Hash      => $hash,
	Indent    => "   ",
	MaxLength => 40,
);
tprint $text =~ /^\s*<tagtwo part="one">$/m || 0, "simplehash2xml";
tprint -e $FILE, "simplehash2xml write to file '$FILE'";

# --- read from file and convert to hash ---
$hash = undef;  # cleanup
$hash = simplexml2hash(File => $FILE);
tprint $hash->{simple}->{name} eq 'test', "simplexml2hash read from file '$FILE'";
unlink $FILE;
tprint !-e $FILE, "deleting file '$FILE'";

# === Encoding and Decoding =================================================
print "\nTesting encoding functions:\n";

# --- prep work ---
my $tag = $hash->{simple}->{encodetag1};
$tag->{'gt'} = '>';
$hash->{simple}->{encodetag2}->{'<body>'} = '&';
$text = simplehash2xml(Hash => $hash, Indent => "   ");

tprint $text =~ /&amp;/ || undef, "XML entity encoding, body";
tprint $text =~ /gt="&gt;"/ || undef, "XML entity encoding, parameter value";
tprint $tag->{'<body>'} eq '"', "XML entity decoding, body";
tprint $tag->{lt} eq '<', "XML entity decoding, parameter value";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
