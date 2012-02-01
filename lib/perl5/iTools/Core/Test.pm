package iTools::Core::Test;
use base qw( Exporter );
$VERSION = 0.1;

@EXPORT = qw( tprint tvar );

use Data::Dumper; $Data::Dumper::Indent=1; # for debugging
use iTools::Core::Accessor;
use Term::ANSIColor qw(:constants);

use strict;
use warnings;

# === Global Variables ======================================================
use vars qw( $config );
$config = {};

# === Generic Accessor ======================================================
sub tvar {
	my $key = shift;
	_tinit() unless $config->{init};  # make sure we're initialized
	iTools::Core::Accessor::_var($config, $key => @_);
}

# === Printing the Test Message =============================================
sub tprint {
	my ($test, $message) = (shift, join '', @_);
	_tinit() unless $config->{init};  # make sure we're initialized

	my $indent = tvar('indent');
	my ($color, $status) = (BOLD . GREEN, 'SUCCESS');
	unless ($test) {
		($color, $status) = (BOLD . RED, 'FAILURE');
		$config->{errors}++;
	}
	# --- unset the color if we're b&w ---
	$color = '' unless $config->{color};

	# --- no message? add a warning ---
	unless ($message) {
		$message = "warning: this test has no message";
		$message = RESET . BOLD . YELLOW . $message
			if $config->{color};
		$config->{warnings}++;
	}

	print $indent . $color ."$status: $message". ($color ? RESET : '') ."\n";
	$config->{count}++;

	return $test;
}

# === Private Initialization Routine ========================================
sub _tinit {
	$config = {
		init   => 1,
		indent => '    ',
		color  => 1,

		errors   => 0,
		warnings => 0,
		count    => 0,
	};

	# --- default color=0 for MSWin systems ---
	$config->{color} = 0 if exists $ENV{OS} && $ENV{OS} =~ /^win/i;
}

1;

=head1 NAME

iTools::Core::Test - unit test helper functions

=head1 SYNOPSIS

  #!/usr/bin/perl -w
  use lib qw( ../.. );   # path to root of library
  use iTools::Core::Test;

  print "\nTests:\n";
  tprint(0, 'message');  # prints 'FAILURE: message'
  tprint(1, 'message');  # prints 'SUCCESS: message'

  my $errors = tvar('errors');
  my $warnings = tvar('warnings');
  my $count = tvar('count');
  print "\n$errors error(s) and $warnings warning(s) in $count tests\n\n";
  exit $errors;

=head1 DESCRIPTION

iTools::Core::Test contains a series of functions to assist with making unit tests.
See the B<SYNOPSIS> for suggested usage.

=head1 ACCESSORS

=head2 Universal Accessors

An accessor labelled as B<universal> is an accessor that allows you to get, set and unset a value with a single method.
To get a the accessor's value, call the method without parameters.
To set the value, pass a single parameter with the new or changed value.
To unset a value, pass in a single parameter of B<undef>.

For details on B<universal> accessors, see the iTools::Core::Accessor(3pm) man page.

=over 4

=item B<tvar>(I<KEY> [=> I<VALUE>])

A B<universal> accessor for setting or getting values for the class.
The following I<KEY>s are available:

  errors   - a count of the number of failed tests
  warnings - a count of the number of warnings
  count    - a count of the total number of tests
  indent   - the string used to indent tprint() messages.  Default: 4 spaces
  color    - a boolean (0/1) to enable or disable color output.
                Default: 0 on MSWindows, 1 on all other OSs.

=back

=head1 METHODS

=over 4

=item B<tprint>(I<TEST>, I<MESSAGE>)

Prints a message indicating whether I<TEST> succeeded or failed.
Failure is considered a test that returned 0, B<undef> or a blank value.
All other conditions are considered successful.

The message printed is in the format:

  indent + red('FAILURE:' + MESSAGE) or
  indent + green('SUCCESS:' + MESSAGE)

See the tvar() accessor above for details on how to the indent or color options.

Returns 1 for success, 0 for error.

=back

=head1 TODO, KNOWN ISSUES AND BUGS

=over 4

=item B<Colorization Class>

Create and implement a class to extend Term::ANSIColor(3pm) to better handle colorization.
Also, look into colored output on MSWindows consoles.

=item B<Objectification>

Consdider making this a object class rather than a import.

=back

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 DEPENDENCIES

strict(3pm) and warnings(3pm),
Exporter(3pm),
iTools::Core::Accessor(3pm),
Term::ANSIColor(3pm)

=head1 SEE ALSO

=cut
