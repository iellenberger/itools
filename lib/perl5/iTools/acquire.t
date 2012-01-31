#!/usr/bin/perl -w
use lib qw( .. );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::Acquire;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ($imports, $loaders, $message);
@{$imports}{qw( acquire acquireMessage acquireLoader )} = (0, 0, 0);
@{$loaders}{qw( file smb http )} = (0, 0, 0);


# === Tests =================================================================
print "\nClass Integrity Tests:\n";
tprint $iTools::Acquire::VERSION, "class version $iTools::Acquire::VERSION";

# --- test imports ---
map { $imports->{$_}++ } @iTools::Acquire::EXPORT;
foreach my $method (sort keys %$imports) {
	tprint $imports->{$method} == 1, "method '$method' imported $imports->{$method} time(s)";
}

# --- check for loaders ---
print "\nDefault Loaders\n";
map { $loaders->{$_}++ } keys %{&acquireLoader};
foreach my $loader (sort keys %$loaders) {
	tprint $loaders->{$loader} == 1, "loader '$loader' registered $loaders->{$loader} time(s)";
}

# --- test loaders ---
print "\nTesting Loaders\n";
tprint acquire('http://site42.com/'), "HTTP test (site42.com)";
tprint !($message = acquireMessage), "   message: ". nonl($message);
tprint !acquire('http://site42.foo/'), "HTTP test (site42.foo), intentional failure";
tprint $message = acquireMessage, "   message: ". nonl($message);

tprint acquire('acquire.t'), "file test (acquire.t)";
tprint !($message = acquireMessage), "   message: ". nonl($message);
tprint !acquire('acquire.foo'), "file test (acquire.foo), intentional failure";
tprint $message = acquireMessage, "   message: ". nonl($message);

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# --- remove stuff from text for prettiness ---
sub nonl {
	my $text = shift;
	return "(blank)" unless $text;   # blank
	$text =~ s/[\r\n]//msg;          # <cr> or <lf>
	$text =~ s/\s+/ /msg;             # extra spaces
	return $text;
}
