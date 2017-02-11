#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Puma::Core::Parser;
use iTools::File qw( writefile );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$parser, $tree,
	$text, $hash,
);
my $file = "parser.$$";

# === Constructor and Accessors =============================================
print "\nConstructor and Accessors:\n";
$parser = new Puma::Core::Parser(Text => 'foo', File => 'bar');
tprint($parser, "constructor");
tprint($parser->text eq 'foo', "constructor 'Text' parameter");
tprint($parser->file eq 'bar', "constructor 'File' parameter");
tprint($parser->text('oof') eq 'oof', "text accessor");
tprint($parser->file($file) eq $file, "file accessor");

print "\n";
writefile($file, "foobar");
tprint(-e $file, "file '$file' created");
tprint($parser->loadFile($file) eq 'foobar', "file loaded");
unlink $file;
tprint(!-e $file, "file '$file' deleted");

# === Parsing Tests =========================================================
print "\nBasic Parsing:\n";
$parser = new Puma::Core::Parser();
tprint($parser, "create new parser");
$tree = $parser->parse('foo');
tprint(shift(@$tree)->{body} eq $parser->text, "found text without tags: ". $parser->text);
$tree = $parser->parse('<foo/>');
tprint(shift(@$tree)->{body} eq $parser->text, "found text with ignored tags: ". $parser->text);

# --- text with comment ---
$tree = $parser->parse('foo<!--com<t:a/>ment-->bar');
print "\nParsing Text: ". $parser->text ."\n";
tprint(shift(@$tree)->{body} eq 'foo', "found tag in comment: before");
tprint(shift(@$tree)->{body} eq '<!--com<t:a/>ment-->', "found tag in comment: comment");
tprint(shift(@$tree)->{body} eq 'bar', "found tag in comment: after");

# --- code tag ---
$hash = ($tree = $parser->parse('<: code <code> />'))->[0];
print "\nParsing Text: ". $parser->text ."\n";
tprint($hash->{label} eq ':', "found code label");
tprint($hash->{body} eq ' code <code> ', "found code body");

# --- tag with body ---
$hash = ($tree = $parser->parse('<foo:bar>content</foo:bar>'))->[0];
print "\nParsing Text: ". $parser->text ."\n";
tprint($hash->{label} eq 'foo:bar', "found parent label");
tprint(ref $hash->{body} eq 'ARRAY', "found parent body (ref)");
tprint($hash->{body}->[0]->{body} eq 'content', "found parent body (content)");

# --- tag with inner tag ---
$hash = ($tree = $parser->parse('<foo:bar><bar:foo/></foo:bar>'))->[0];
print "\nParsing Text: ". $parser->text ."\n";
tprint($hash->{label} eq 'foo:bar', "found parent label");
tprint(ref $hash->{body} eq 'ARRAY', "found parent body (ref)");
tprint($hash->{body}->[0]->{label} eq 'bar:foo', "found child label");

# --- include tag ---
$text = qq[<foo:bar><:include file="$file"/></foo:bar>];
print "\nParsing Text: ". $text ."\n";
writefile($file, "<bar:foo/>");
tprint(-e $file, "file '$file' created");
$hash = ($tree = $parser->parse($text))->[0];
tprint($hash->{label} eq 'foo:bar', "found parent label");
tprint(ref $hash->{body} eq 'ARRAY', "found parent body (ref)");
tprint($hash->{body}->[0]->{label} eq 'bar:foo', "found included child label");
unlink $file;
tprint(!-e $file, "file '$file' deleted");

# --- special tag ---
$hash = ($tree = $parser->parse('<:bar key="value"/>'))->[0];
print "\nParsing Text: ". $parser->text ."\n";
tprint($hash->{label} eq ':bar', "found label");
tprint($hash->{attribute}->{key} eq 'value', "found attribute");

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
