#!/usr/bin/perl -w
use lib qw( ../.. );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $accessor, $value, @values );

# === Constructor and Accessors =============================================
print "\nConstructor:\n";
$accessor = new LocalTest;
tprint $accessor, "reference object created";

tprint !defined $accessor->value,  "get: undefined value";
tprint !exists $accessor->{myVal}, "probe: key does not exist";

# === Core Accessors ========================================================
print "\nCore Accessor:\n";
print "  prerequisites:\n";
tprint !exists $accessor->{myVal},         "probe: key does not exist";
tprint !defined($accessor->value),         "get: value => undef";
print "  set:\n";
tprint $value = $accessor->value('test1'), "set: value('test1')";
tprint $value eq 'test1',                  "     returned '$value'";
tprint $accessor->value eq 'test1',        "get: value => 'test1'";

print "  reset:\n";
tprint $value = $accessor->value('test2'), "set: value('test2')";
tprint $value eq 'test2',                  "     returned '$value'";
tprint $accessor->value eq 'test2',        "get: value => 'test2'";

print "  unset:\n";
tprint $value = $accessor->value(undef),   "set: value(undef)";
tprint $value eq 'test2',                  "     returned '$value'";
tprint !defined $accessor->value,          "get: value => undef";
tprint !exists $accessor->{myVal},         "probe: key does not exist";

print "\nIdempotent Accessor:\n";
print "  prerequisites:\n";
tprint !exists $accessor->{myIVal},         "probe: key does not exist";
tprint !defined($accessor->ivalue),         "get: value => undef";
print "  set:\n";
tprint $value = $accessor->ivalue('test1'), "set: value('test1')";
tprint $value eq 'test1',                   "     returned '$value'";
tprint $accessor->ivalue eq 'test1',        "get: value => 'test1'";

print "  reset:\n";
tprint $value = $accessor->ivalue('test2'), "set: value('test2')";
tprint $value eq 'test1',                   "     returned '$value'";
tprint $accessor->ivalue eq 'test1',        "get: value => 'test1'";

print "  unset:\n";
tprint $value = $accessor->ivalue(undef),   "set: value(undef)";
tprint $value eq 'test1',                   "     returned '$value'";

# === Array Accessor ========================================================
print "\nArray Accessor:\n";
print "  prerequisites:\n";
tprint !exists $accessor->{myArray},                "probe: key does not exist";
tprint !defined($accessor->avalue),                 "get: value => undef";
print "  set:\n";
tprint((@values = $accessor->avalue('test1')) == 1, "set: value('test1'), returned one value");
tprint $values[0] eq 'test1',                       "     value '$values[0]";
tprint $accessor->avalue == 1,                      "get: returned one value";
tprint(($accessor->avalue)[0] eq 'test1',           "     value => 'test1'");

print "  reset:\n";
tprint((@values = $accessor->avalue(undef, 'test2', 'test3')) == 3,
                                                    "set: value(undef, 'test2', 'test3'), returned three values");
tprint !defined $values[0],                         "     value[0] => undef";
tprint $values[1] eq 'test2',                       "     value[1] => '$values[1]'";
tprint $values[2] eq 'test3',                       "     value[2] => '$values[2]'";
# $accessor->{myArray} = "f'ed up";  # uncomment this line if you want to see an error message!
tprint $accessor->avalue == 3,                      "get: returned three values";
tprint !defined(($accessor->avalue)[0]),            "     value[0] => undef";
tprint(($accessor->avalue)[1] eq 'test2',           "     value[1] => 'test2'");
tprint(($accessor->avalue)[2] eq 'test3',           "     value[2] => 'test3'");

print "  unset:\n";
tprint((@values = $accessor->avalue(undef)) == 3,   "set: value(undef), returned three values");
tprint !defined $values[0],                         "     value[0] => undef";
tprint $values[1] eq 'test2',                       "     value[1] => '$values[1]'";
tprint $values[2] eq 'test3',                       "     value[2] => '$values[2]'";
tprint((@values = $accessor->avalue(undef)) == 0,   "get: returned zero values");
tprint !exists $accessor->{myArray},                "probe: key does not exist";

# === Default Value Accessor ================================================
print "\nDefault Value Accessor:\n";
print "  prerequisites:\n";
tprint !exists $accessor->{myDefVal},       "probe: key does not exist";
tprint $accessor->dvalue eq 'defval',       "get: value => 'defval' (default)";

print "  set:\n";
tprint $value = $accessor->dvalue('test1'), "set: value('test1')";
tprint $value eq 'test1',                   "     returned '$value'";
tprint $accessor->dvalue eq 'test1',        "get: value => 'test1'";

print "  unset:\n";
tprint $value = $accessor->dvalue(undef),   "set: value(undef)";
tprint $value eq 'defval',                  "     returned '$value'";
tprint $accessor->dvalue eq 'defval',       "get: value => 'defval' (default)";
tprint !exists $accessor->{myDefVal},       "probe: key does not exist";

# === Default Code Accessor =================================================
print "\nDefault Code Accessor:\n";
print "  prerequisites:\n";
tprint !exists $accessor->{myDefVal},      "probe: key does not exist";
tprint $accessor->dcode eq 'defcode',      "get: value => 'defcode' (default)";

print "  set:\n";
tprint $value = $accessor->dcode('test1'), "set: value('test1')";
tprint $value eq 'test1',                  "     returned '$value'";
tprint $accessor->dcode eq 'test1',        "get: value => 'test1'";

print "  unset:\n";
tprint $value = $accessor->dcode(undef),   "set: value(undef)";
tprint $value eq 'defcode',                "     returned '$value'";
tprint $accessor->dcode eq 'defcode',      "get: value => 'defcode' (default)";
tprint !exists $accessor->{myDefVal},      "probe: key does not exist";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === Simple Object for Tests ===============================================
package LocalTest;
use base 'iTools::Core::Accessor';

sub new { bless {}, ref $_[0] || $_[0] }
sub value  { shift->_var(myVal => @_) }
sub ivalue { shift->_ivar(myIVal => @_) }
sub avalue { shift->_varArray(myArray => @_) }
sub dvalue { shift->_varDefault('defval', myDefVal => @_) }
sub dcode  { shift->_varDefault(sub { 'defcode' }, myDefVal => @_) }

1;
