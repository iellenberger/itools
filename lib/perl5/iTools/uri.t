#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use iTools::URI;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $obj, $uri );

my @uris = (
	'http://user:pass@domain.com:80/path/to/file.ext?key1=val1&key2#frag',
	'//user:pass@domain.com:80/path/to/file.ext?key1=val1&key2#frag',
	'//:pass@domain.com:80/path/to/file.ext?key1=val1&key2#frag',
	'//user@domain.com:80/path/to/file.ext?key1=val1&key2#frag',
	'//domain.com:80/path/to/file.ext?key1=val1&key2#frag',
	'//domain.com/path/to/file.ext?key1=val1&key2#frag',
	'//:80/path/to/file.ext?key1=val1&key2#frag',
	'/path/to/file.ext?key1=val1&key2#frag',
	'?key1=val1&key2#frag',
	'#frag',
	'http://domain.com/path/to/file.ext?key1=val1&key2',
	'http://domain.com/path/to/file.ext?key1=val1',
	'http://domain.com/path/to/file.ext?key1',
	'http://domain.com/path/to/file.ext',
	'http://domain.com/',
	'http://domain.com',
	'http:',
);

# === Tests =================================================================
print "\nConstruction and Core Accessors:\n";
$obj = new iTools::URI;
tprint($obj, "object created");
tprint($obj->CLASS eq 'iTools::URI', "object class 'iTools::URI'");
tprint($obj->VERSION eq $iTools::URI::VERSION, "class version $iTools::URI::VERSION");

print "\nGeneral Component Verification:\n";
$uri = 'http://user:pass@domain.com:80/path/to/page.html?key1=val1&key2#frag';
tprint($obj->uri($uri) eq $uri, "URI loaded '$uri'");
tprint($obj->scheme    eq 'http', 'scheme verification');
tprint($obj->authority eq 'user:pass@domain.com:80', 'authority verification');
tprint($obj->user      eq 'user', 'user verification');
tprint($obj->password  eq 'pass', 'password verification');
tprint($obj->host      eq 'domain.com', 'host verification');
tprint($obj->port      eq '80', 'port verification');
tprint($obj->path      eq '/path/to/page.html', 'path verification');
tprint($obj->query     eq 'key1=val1&key2', 'query verification');
tprint($obj->fragment  eq 'frag', 'fragment verification');

print "\nOutside case tests:\n";
$uri = '/home/user/foo.log';
tprint($obj->uri($uri) eq $uri, "Loading '$uri'");
tprint($obj->path eq $uri, "   checking path");
$uri = '../user/foo.log';
tprint($obj->uri($uri) eq $uri, "Loading '$uri'");
tprint($obj->path eq $uri, "   checking path");
$uri = 'user/foo.log';
tprint($obj->uri($uri) eq $uri, "Loading '$uri'");
tprint($obj->path eq $uri, "   checking path");
$uri = '\\\\domain\shares\doc.doc';
tprint($obj->uri($uri) eq '//domain/shares/doc.doc', "Loading '$uri'");
tprint($obj->host eq 'domain', "   checking host");
tprint($obj->path eq '/shares/doc.doc', "   checking path");

print "\nURI Recomposition:\n";
foreach $uri (@uris) {
	tprint($obj->uri($uri) eq $uri, "$uri");
	# print Dumper($obj);
}

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
