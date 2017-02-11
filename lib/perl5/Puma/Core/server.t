#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Puma::Core::Server;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$server,
	$hash, $obj, $header,
);

# === Constructor and Accessors =============================================
print "\nConstructor and Accessors:\n";
$server = new Puma::Core::Server;
tprint($server, "constructor");
tprint(ref $server->cgi eq 'CGI', "CGI object loaded");
tprint(ref $server->config eq 'HASH', "config hash loaded");
tprint(ref $server->session('session') eq 'Puma::Object::Session', "browser session object loaded");
tprint(ref $server->session('user') eq 'Puma::Object::User', "user session object loaded");

tprint(!$server->redirect, "redirect() accessor get");
tprint($server->redirect(1), "redirect() accessor set");
tprint($server->param('foo' => 'bar'), "param() accessor set");
tprint($server->param('foo') eq 'bar', "param() accessor get");
tprint($server->paramHash->{'foo'} eq 'bar', "paramHash() accessor get");
tprint($server->headerParam('-type' => 'foo/bar'), "headerParam() accessor set");
tprint($server->headerParam->{'-type'} eq 'foo/bar', "headerParam() accessor get");

# === CGI Headers ===========================================================
print "\nHeader Generation:\n";
tprint(!$server->redirect(0), "redirect disabled");
tprint($server->headerParam('-type' => 'foo/bar'), "setting content type to 'foo/bar'");
$header = $server->header;
tprint($header =~ /^\s*Content-Type: foo\/bar\s*$/ms ? 0 : 1, "caught redirect header");
tprint($server->redirect('some.where'), "redirect enabled");
$header = $server->header;
tprint($header =~ /^\s*Status: 302 Moved\s*Location: some.where\s*$/ms ? 0 : 1, "caught redirect header");
# print Dumper($server);

#! TODO: add tests for bake() and getCookie()

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
