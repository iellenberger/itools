#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Puma::Core::RegEx qw( reTagParser reAttribute parseAttribute );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$regex,
	$tag, $xml, @xmllist,
	$key, $value,
);

# === Tag Parser ============================================================
# --- tag parser, no labelrules ---
print "\nTag Parser, No Label Rules:\n";
$xml = qq[
	<foo bar="1">
		<!-- comment -->
		<eat my='shorts'/>
	</foo>
];
@xmllist = split /\s*\n\s*/, $xml; shift @xmllist;

$regex = reTagParser();
tprint($regex, "TagParser Regex generated");
for (my $ii = 0; $ii < @xmllist; $ii++) {
	$xml =~ m/$regex/gc; $tag = $2 || 'ERROR';
	tprint($tag eq $xmllist[$ii], "tag match: $xmllist[$ii] -> $tag");
}

# --- tag parser with labelrules ---
print "\nTag Parser with Label Rules:\n";
$regex = reTagParser(':[\w=]*\s|foo');
$xml .= qq[
	<foo:bar>
		<: code />
	</foo:bar>
];
@xmllist = ();
@xmllist = split /\s*\n\s*/, $xml; shift @xmllist;

tprint($regex, "TagParser Regex generated");
for (my $ii = 0; $ii < @xmllist; $ii++) {
	next if $xmllist[$ii] =~ /^<eat/;
	$xml =~ m/$regex/gc; $tag = $2 || 'ERROR';
	tprint($tag eq $xmllist[$ii], "tag match: $xmllist[$ii] -> $tag");
}

# --- tags in comments ---
print "\nTag Parser with Tags Embedded in Comment:\n";
$xml = "<!-- comment <foo:bar /> -->";
$xml =~ /$regex/;
tprint($2 eq $xml, "tag match: '$2' -> '$xml'");

# === Attribute Splitter RegEx ==============================================
# --- standard attributes ---
print "\nAttribute Regex Tests:\n";
$regex = reAttribute();
tprint($regex, "Attribute Regex generated");

# --- basic pair quoting ---
($key, $value, $xml) = matchAttr(q[key="value"]);
tprint($key eq 'key' && $value eq 'value', qq[parsing '$xml'   => $key="$value"]);
($key, $value, $xml) = matchAttr(q[key='value']);
tprint($key eq 'key' && $value eq 'value', qq[parsing '$xml'   => $key="$value"]);
($key, $value, $xml) = matchAttr(q[key=value]);
tprint($key eq 'key' && $value eq 'value', qq[parsing '$xml'     => $key="$value"]);
($key, $value, $xml) = matchAttr(q[key=`value`]);
tprint($key eq 'key' && $value eq '`value`', qq[parsing '$xml'   => $key="$value"]);
($key, $value, $xml) = matchAttr(q[`key`=`value`]);
tprint($key eq '`key`' && $value eq '`value`', qq[parsing '$xml' => $key="$value"]);

# --- funky characters, spacing and key only ---
print "\n";
($key, $value, $xml) = matchAttr(q[K_3-y = 'v ah l\'u3' ]);
tprint($key eq 'K_3-y' && $value eq 'v ah l\\\'u3', qq[parsing '$xml' => $key="$value"]);
($key, $value, $xml) = matchAttr(q[key]);
tprint($key eq 'key' && $value eq 'undef', qq[parsing '$xml'   => $key]);
($key, $value, $xml) = matchAttr(q[`key`]);
tprint($key eq '`key`' && $value eq 'undef', qq[parsing '$xml' => $key]);
($key, $value, $xml) = matchAttr(q[key ]);
tprint($key eq 'key' && $value eq 'undef', qq[parsing '$xml'  => $key]);

# --- multiple attributes ---
print "\n";
$xml = qq[key1="value1" `key2` key3 = 'value3' ];
@xmllist = ();
while ($xml =~ /$regex/gc) {
	my ($key, $value) = ($1, matchFirst($2, $3, $4, $5));
	push @xmllist, $key, $value;
}
tprint(shift @xmllist eq 'key1',   qq[multiple attributes 'key1']);
tprint(shift @xmllist eq 'value1', qq[multiple attributes 'value1']);
tprint(shift @xmllist eq '`key2`', qq[multiple attributes '`key2`']);
tprint(! defined shift @xmllist,   qq[multiple attributes undef]);
tprint(shift @xmllist eq 'key3',   qq[multiple attributes 'key3']);
tprint(shift @xmllist eq 'value3', qq[multiple attributes 'value3']);

# --- local helpers ---
sub matchAttr {
	my ($string, $regex, $key, $value) = (shift, reAttribute());
	my @matches = ($string =~ m/$regex/);
	$key = shift @matches;
	foreach my $match (@matches) { if (defined $match) { $value = $match; last } }
	$value = 'undef' unless defined $value;
	return $key, $value, $string;
}
sub matchFirst {
	foreach (@_) { return $_ if defined $_ }
	return undef;
}

# === Attribute Splitter Function ===========================================
print "\nAttribute Function Tests:\n";
$xml = 'key=`v a \" l \` ue ` ';
($key, $value) = parseAttribute($xml);
tprint($key eq 'key' && $value eq '`v a \" l ` ue `', qq[parsing '$xml' => $key="$value"]);

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
