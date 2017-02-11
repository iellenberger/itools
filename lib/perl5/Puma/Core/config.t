#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Test;

use Cwd;
use Puma::Core::Config;
use iTools::File qw( writefile );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my (
	$config, $test,
);
my $file = "test/a/b/config.puma";
my $content = <<'XML';
<puma>
	<config cascade="off" file=".puma" />
	<directory name="a">
		<config cascade="off"/>
	</directory>
	<test value="0"/>
</puma>
XML

# --- environment hacks 'cause we ain't got no CGI---
my $env = {
	DOCUMENT_ROOT   => cwd .'/test',
	PATH_TRANSLATED => cwd ."/$file",
};
foreach my $key (keys %$env) { $ENV{$key} = $env->{$key} }

# === Preparation ===========================================================
print "\nPreparing Files:\n";
writefile($file, $content);
tprint(-e $file, "writing core config file");
writefile('test/a/b/.puma', qq[ <puma><test value="1"/></puma> ]);
tprint(-e 'test/a/b/.puma', "writing config file 1");
writefile('test/a/.puma',   qq[ <puma><test value="2"/></puma> ]);
tprint(-e 'test/a/.puma',   "writing config file 2");
writefile('test/.puma',     qq[ <puma><test value="3"/><config cascade="off"/></puma> ]);
tprint(-e 'test/.puma',     "writing config file 3");
writefile('.puma',          qq[ <puma><test value="should never get here"/></puma> ]);
tprint(-e '.puma',          "writing config file 4");

# === Constructor and Cascading =============================================
print "\nConstructor and Cascading:\n";
$config = new Puma::Core::Config(File => $file);
tprint($config, "object construction");
tprint($test = $config->genConfig->{test}, "generating local config");
tprint($test->{value} == 0, "retrieved test value '$test->{value}'");

print "\n";
tprint($config->core->{config}->{cascade} = 'on', "turned core cascading on");
tprint($config->loadLocal, "loading more local files");
tprint($test = $config->genConfig->{test}, "generating local config");
tprint($test->{value} == 1, "retrieved test value '$test->{value}'");

print "\n";
tprint($config->local("$env->{DOCUMENT_ROOT}/a")->{config}->{cascade} = 'on', "turned local 'test/a' cascading on");
tprint($config->loadLocal, "loading more local files");
tprint($test = $config->genConfig->{test}, "generating local config");
tprint($test->{value} == 3, "retrieved test value '$test->{value}'");

print "\n";
unlink '.puma';
tprint(!-e '.puma', "deleted test file");
system 'rm -rf test';
tprint(!-e 'test', "deleted test directory");

# === Serialization =========================================================
print "\nSerialization Test:\n";
$file = "config.$$";
tprint($config->serialize($file), "config object frozen");
tprint(-e $file, "   and saved to file");
tprint($test = $config->unserialize($file), "config object thawed");
tprint($test->core->{test}->{value} == 0, "unserialization verified");
unlink $file;
tprint(!-e $file, "deleted serialized object file");

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
