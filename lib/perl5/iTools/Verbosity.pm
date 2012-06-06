package iTools::Verbosity;
use base Exporter;
$VERSION = "0.01";

@EXPORT = qw(
	verbosity
	vpush vpop vtmp
	vprint vprintf
	vindent
	vlog vlogf vlogfile vloglevel
);

use Data::Dumper; $Data::Dumper::Indent=$Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging

use strict;
use warnings;

# === Class Variables =======================================================
# --- class configuration with defaults defined ---
our $CONFIG = {
	indent    => 3,      # accessor: vindent
	verbosity => [ 0 ],  # accessor: _varray, verbosity
	logfile   => undef,  # accessor: vlogfile
	loglevel  => undef,  # accessor: vloglevel
};

# === Accessors =============================================================
# --- private: get a guaranteed verbosity array ref from $CONFIG ---
sub _varray {
	my $varray = $CONFIG->{verbosity} ||= [];  # get array from config
	$varray = [] if ref $varray ne 'ARRAY';    # guarantee we have an array ref
	push @$varray, 0 if @$varray < 1;          # make sure array is not empty
	return wantarray ? @$varray : $varray;     # return the array
}

# --- current verbosity level ---
sub verbosity {
	# --- get new level and verbosity array ---
	my ($level, $varray) = (shift, scalar _varray);
	# --- set new value if given ---
	$varray->[0] = _vcalc($level, $varray->[0])
		if defined $level;
	# --- return top of verbosity array as current level ---
	return $varray->[0];
}

# --- indent string for vprint/vprintf ---
sub vindent {
	# --- set the indent ---
	$CONFIG->{indent} = shift if @_;

	# --- empty string if no indent ---
	return '' unless defined $CONFIG->{indent};
	# --- a number of spaces by default ---
	return ' ' x $CONFIG->{indent} if $CONFIG->{indent} =~ /^\d+$/;
	# --- user set value ---
	return $CONFIG->{indent};
}

# === Print Depending on Verbosity ==========================================
# --- print message based on verbosity ---
sub vprint {
	my ($level, $text) = (shift, join('', @_));

	# --- write log entry ---
	vlog($level, $text);

	# --- don't print anything above the current verbosity level ---
	return 0 unless verbosity >= $level;

	# --- send anything below level 0 to STDERR ---
	if ($level < 0) { print STDERR _vparse($level, $text) }
	else            { print _vparse($level, $text) }

	return 1;
}
sub vprintf {
	my ($level, $format) = (shift, shift);

	# --- do a bit of checking to make sure we don't throw an error here ---
	$format = 'undef' unless defined $format;

	# --- render and print ---
	my $message = $format;
	if (@_) { $message = sprintf $format, @_ }
	vprint $level, $message;
}

# --- temporarily set verbosity for a block of code ---
sub vpush { unshift @{scalar _varray()}, _vcalc(shift) }
sub vpop  { shift @{scalar _varray()} }
sub vtmp(&$) {
	my ($code, $level) = @_;
	vpush $level; my $retval = &$code; vpop;
	return $retval;
}

# === Logfile Output ========================================================

# --- accessors ---
sub vlogfile {
	# --- just return the logfile name if we have no params ---
	return _var('logfile') unless @_;

	# --- if we hava a param, set or reset the log filename ---
	my $logfile = shift;

	# --- clear the logfilename if we get undef ---
	return _var(logfile => undef)
		unless defined $logfile;

	# --- if the file exists, make sure it's writable ---
	if (-e $logfile) {
		# --- yippie! It's writable! ---
		return _var(logfile => $logfile) if -w $logfile;

		# --- can't write to file, show message and clear logfile ---
		_var(logfile => undef);
		vprint -1, "warning: iTools::Verbosity: Logfile $logfile is not writable.  Logging disabled\n";
		return undef;
	}

	# --- if we got here, the file doesn't exist ---

	# --- open the file and write the 1st line ---
	unless (open iVLOG, ">>$logfile") {
		my $error = $!;
		_var(logfile => undef);
		vprint -1, "warning: iTools::Verbosity: Can't create $logfile. Logging disabled\n";
		vprint -1, "   $error\n";
		return undef;
	}
	# --- finally, set the logfile name in config ---
	_var('logfile', $logfile);

	# --- print message to create logfile ---
	print iVLOG "[". localtime() ."] logfile created\n"
		if vloglevel() >= 3;

	# --- ... and return ---
	close iVLOG;
	return $logfile;
}

# --- return loglevel if defined, else return verbosity() ---
sub vloglevel {
	my $level = _var('vloglevel', @_);
	return defined $level ? $level : verbosity();
}

# --- send a message to the logfile ---
sub vlog {
	my ($level, $text) = (shift, join('', @_));

	# --- don't print anything above the current log verbosity level ---
	return 0 unless vloglevel >= $level;

	# --- write log entry ---
	if (my $logfile = vlogfile) {
		unless (open iVLOG, ">>$logfile") {
			my $error = $!;
			_var(logfile => undef);
			vprint -1, "warning: iTools::Verbosity: Unable to open $logfile. Logging disabled\n";
			vprint -1, "   $error\n";
			return -1;
		}
		print iVLOG "[". localtime() ."] ". _vparse($level, $text);
		close iVLOG;
		return 1;
	}

	return 0;
}
sub vlogf { vlog shift, sprintf(shift, @_) }

# === Private Methods =======================================================
# --- parse text for indents 'n stuff ---
sub _vparse {
	my ($level, $text) = (shift, join('', @_));

	# --- get indent length and set the indent flag ---
	$text =~ s/^(>*)//;
	my ($ilen, $iflag) = (length($1), 0);
	if    ($ilen == 0) { $ilen  = 0; $iflag = 0 }  # ''  - do nothing
	elsif ($ilen == 1) { $ilen  = 0; $iflag = 1 }  # >   - replace with indent
	elsif ($ilen == 2) { $ilen  = 1; $iflag = 0 }  # >>  - replace with '>'
	else               { $ilen -= 2; $iflag = 1 }  # >>> - replace with indent + '>'

	# --- reconstruct indent and '>'s ---
	my $indent = $iflag && $level > 0 ? vindent() x $level : '';
	$text = $indent . ('>' x $ilen) . $text;

	#! TODO: add feature to strip non-printable chars and sequences

	return $text;
}

# --- calculate verbosity for relative vs absolute params ---
sub _vcalc {
	my ($level, $current) = @_;

	# --- parameter processing ---
	$current = verbosity()        # get current verbosity
		unless defined $current;   #    if not given as param
	return $current               # return current level
		unless defined $level;     #    if level not defined

	# --- calculate new verbosity ---
	my $newval = $level;          # set verbosity to level
	$newval = $current + $level   # adjust verbosity from current
		if $level =~ /^[+-]{2}/;   #    if level is signed

	return $newval;
}

# --- _var: stolen from iTools::Core::Accessor ---
sub _var {
	my $key = shift;

	# --- get the value ---
	unless (@_) {
		return $CONFIG->{$key} if exists $CONFIG->{$key};
		return undef;
	}

	# --- delete the key if value = undef ---
	unless (defined $_[0]) {
		my $value = $CONFIG->{$key};  # store the old value
		delete $CONFIG->{$key};       # delete the key
		return $value;                # return the old value
	}

	# --- set and return the value ---
	return $CONFIG->{$key} = shift;
}

1;

=head1 NAME

iTools::Verbosity - tools for managing script verbosity

=head1 SYNOPSIS

 use iTools::Verbosity;

 verbosity LEVEL;
 vpush LEVEL;
 vpop;
 vtmp { CODE } LEVEL;
 vprint LEVEL, STRING;
 vprintf LEVEL, FORMAT, ARGS ...;
 vindent (STRING|COUNT);
 vlog LEVEL, STRING;
 vlogf LEVEL, FORMAT, ARGS ...;
 vlogfile FILENAME;
 vloglevel LEVEL;

=head1 DESCRIPTION

This package provides tools to display output based on a verbosity level.

=head1 EXPORTS

All functions are explicitly exported unless otherwise requested (see Exporter(3pm));

=over 4

=item B<verbosity> [LEVEL]

Sets or reports the verbosity LEVEL.
In general, verbosity levels generally adhere to these entirely arbitrary values:

   -3  suppress all messages
   -2  only show error messages
   -1  only show warning and error messages
   0   normal output
   1   extended progress
   2   debug output and system() commands
   3   command execution details

verbosity() returns the new verbosity level, or the current level if called without parameters.

=item B<vindent> [STRING|COUNT]

When indenting, this module uses either a indent STRING or space COUNT for display.
If the value is a STRING, it will repeat the STRING as per the desired verbosity level.
If the value is numeric, it uses that number of spaces as the STRING.

verbosity() returns the new indent, or the current indent if called without parameters.

=item B<vpush> LEVEL

=item B<vpop>

=item B<vtmp> { CODE } LEVEL

There are two different ways to temporarilly change the verbosity level in a block of code.
You can either push a new level and then subsequent pop it
or you can use vtmp() to set the level for a block of code.

You can also specify relative verbosity LEVELS for these functions.
For example, if your current verbosity level is '1' you can do the following:

   vtmp { CODE } 3       tmp level = 3
   vtmp { CODE } -1      tmp level = 0
   vtmp { CODE } '++1'   tmp level = 2
   vtmp { CODE } '--1'   tmp level = 0
   vtmp { CODE } '--3'   tmp level = 0 (see note below)

Relative verbosity levels will never drop below zero (0) but can be incremented as high as you'd like.

=item B<vprint> LEVEL, STRING

=item B<vprintf> LEVEL, FORMAT, ARGS ...

These functions implement Perl's print() and printf() functions and perform in the same manner exvept for the conditions listed below.

The LEVEL parameter indicates at what verbosity() level the message should be printed.
If the current verbosity() level is >= LEVEL the message will be printed, otherwise it will be supressed.

You can also have the message automatically inented based on the current indent()
be using a '>' as the first character of the string.
You can escape this character by using '>>'.

If vlogfile() is set, vlog() or vlogf() are also invoked.

Returns '1' if the message was printed and '0' if it was not.

=item B<vlog> LEVEL, STRING

=item B<vlogf> LEVEL, FORMAT, ARGS ...

vlog() and vlogf() are used to send output to a logfile.
The parameters are the same as their vprint() and vprintf() counterparts.

If vlogfile() is set, these methods are automatically invoked by vprint() and vprintf().
Used on thir own, they will only send output to the logfile.

vlog() and vlogf() send output to the logfile using the same format as
vprint() and vprintf() send output to the screen except that each line is
prepended by a timestamp as in the example below:

   [Sat Jan  1 00:00:00 2000] Happy New Year!
   [Sat Jan  1 00:00:01 2000]    checking to see if the world ended
   [Sat Jan  1 00:00:10 2000]    nope, we're good

=item B<vlogfile> [FILENAME]

vlogfile() is used to define the log output file.
If theis value is set, all messages written via vprint() and vprintf() will
be also be appended to FILENAME.

You can clear vlogfile() by passing 'undef' as the parameter.
Returns the new value, or the current value if called without parameters.

=item B<vloglevel> LEVEL

vloglevel() defines the verbosity level for logfile output.
If the value is 'undef', the current verbosity() level is used.

You can reset vloglevel() by passing 'undef' as the parameter.
Returns the new value, or the current value if called without parameters.

=back

=head1 TODO, KNOWN ISSUES AND BUGS

=over 4

=item ToDo: B<Remove Colored Output from Logfiles>

... or at least provide the option.

=back

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Written by Ingmar Ellenberger.

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 SEE ALSO

=cut
