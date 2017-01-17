#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Cwd;
use Puma::Core::Config;
use Puma::Core::Engine;
use iTools::File qw( writefile );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$engine, $perl,
);
my $file = "engine.$$";
my $content = <<'PUMA';
<: my $mary = 'Mary' />
<:use lib="/foo" module="PumaTest" import="beer" prefix="drunk" Waitress=`$mary` />
<:use module="PumaTest::TagLib" prefix="taglib" />
<:use module="PumaTest::Tag" prefix="tag" />
hello <: print "world\n" />
<drunk:girl vomit="green">
	Dumbass
</drunk:girl>
<drunk:boy/>

<:
	use Data::Dumper;
	print "foo";
/>
PUMA

# --- environment hacks 'cause we ain't got no CGI---
my $env = {
	DOCUMENT_ROOT   => cwd .'/test',
	PATH_TRANSLATED => cwd ."/$file",
};
foreach my $key (keys %$env) { $ENV{$key} = $env->{$key} }

# === Preparation ===========================================================
print "\nPreparing Stuff:\n";
writefile($file, $content);
tprint(-e $file, "writing content file '$file'");

# === Constructor and Accessors =============================================
print "\nConstructor and Accessors:\n";
$engine = new Puma::Core::Engine(File => $file);
tprint($engine, "constructor");
$perl = $engine->render;



# print Dumper($engine);
print "============================\n";
print $engine->text;
print "============================\n";
print "$perl\n";
print "============================\n";
# eval $perl || die $!;


unlink $file;
tprint(!-e $file, "deleted content file '$file'");

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');


# === Test Classes ==========================================================
no strict;

# --- PumaTest --------------------------------------------------------------
package PumaTest;
use base 'Exporter';
@EXPORT_OK = 'beer';

sub beer { print "Molson" }

# --- PumaTest::Tag ---------------------------------------------------------
package PumaTest::Tag;
use base 'Puma::Object::Tag';

# --- PumaTest::TagLib ------------------------------------------------------
package PumaTest::TagLib;
#use base 'Puma::Object::TagLib';
