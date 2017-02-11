#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Puma::Core::Page;
use iTools::File qw( writefile );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$page, $text, $code,
);
my $file = "page.$$";

# === Tests =================================================================
print "\nConstructor:\n";
tprint($page = new Puma::Core::Page, "object built");

$page->text('<:use lib="/foo"/>');
print "\nCodification Test: ". $page->text ."\n";
tprint($code = $page->codify, "code generated");
_validate($code, q[use lib '/foo';]);

$page->text('<:use lib="/bar" module="Foo::Bar" prefix="foo" Name="MyFoo" import="bar foo"/>');
print "\nCodification Test: ". $page->text ."\n";
tprint($code = $page->codify, "code generated");
_validate($code, q[use lib '/bar';]);
_validate($code, q[use Foo::Bar qw(bar foo);]);
_validate($code, q[my $foo = new Foo::Bar]);
_validate($code, q[Name => 'MyFoo']);
_validate($code, q[Server => $server]);

$page->text('<head><title name="<:= $foo />"></head>');
print "\nCodification Test: ". $page->text ."\n";
tprint($code = $page->codify, "code generated");
_validate($code, q[print qq[<head><title name="];]);
_validate($code, q[print sub { $foo };]);
_validate($code, q[print qq["></head>];]);

$page->text('<foo:bar1><p>$foo->{bar2}</p><foo:bar3/></foo:bar1>');
print "\nCodification Test: ". $page->text ."\n";
tprint($code = $page->codify, "code generated");
_validate($code, q[$foo->_render(sub { $foo->bar1() }, sub {.*});]);
_validate($code, q[print qq[<p>$foo->{bar2}</p>];]);
_validate($code, q[$foo->_render(sub { $foo->bar3() }, sub {});]);

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === Subs ==================================================================
sub _validate {
	my $code = shift;
	my $re = my $text = shift;
	$re =~ s/([\[($)\]])/\\$1/g;
	tprint($code =~ m|$re|ms || 0, "code validated: $text");
}
