package iTools::System;
use base Exporter;
$VERSION = "0.01";

@EXPORT_OK = qw(
	colored verbosity vbase fatal nofatal indent
	vprint vprintf vnprint vnprintf vtmp
	die warn
	system command
	mkdir chdir mkcd symlink
	rename link unlink
);

use Carp qw( cluck confess );
use iTools::Term::ANSI qw( cpush cpop color );
use IPC::Open3;
use Symbol;

use strict;
use warnings;

# === Class Variables =======================================================
our $CONFIG = {
	indent => 3,
};

# === Accessors =============================================================
# --- should output be colored? ---
sub colored   { iTools::Term::ANSI::colored(@_) }
# --- should errors be fatal? ---
sub fatal     { _varDefault(1, 'fatal', @_) }
# --- current verbosity level ---
sub verbosity { _varDefault(0, 'verbosity', @_) }
# --- the verbosity level at which commands start showing output ---
sub vbase     { _varDefault(2, 'vbase', @_) }

# --- log file output ---
sub logfile { _var('logfile', @_) }
sub logonly { _var('logonly', @_) }

# --- indent string for vprint and vprintf ---
sub indent {
	# --- set the indent ---
	$CONFIG->{indent} = shift if @_;

	# --- empty string if no indent ---
	return '' unless defined $CONFIG->{indent};
	# --- a number of spaces by default ---
	return ' ' x $CONFIG->{indent} if $CONFIG->{indent} =~ /^\d+$/;
	# --- user set value ---
	return $CONFIG->{indent};
}

sub config { my %args = @_; foreach my $key (keys %args) { $CONFIG->{lc $key} = $args{$key} } }

# === Print Depending on Verbosity ==========================================
# --- print message based on verbosity ---
sub vnprint {
	my ($level, $text) = @_;
	return unless verbosity >= $level;

	# --- send anything below level 0 to STDERR ---
	if ($level < 0) { print STDERR $text }
	else            { print $text unless logonly() }

	# --- write log entry ---
	if (my $logfile = logfile()) {
		open iSLOG, ">>$logfile";
		print iSLOG "[". localtime() ."] $text";
		close iSLOG;
	}
}
sub vnprintf {
	my $level = shift;
	my $text = sprintf shift, @_;
	vnprint $level, $text;
}
# --- print message based on verbosity with indent ---
sub vprint {
	my ($level, $text) = @_;

	return unless verbosity >= $level;

	# --- indent message appropriately ---
	my $indent = $level > 0 ? indent() x $level : '';
	$text =~ s/^/$indent/msg;

	# --- send anything below level 0 to STDERR ---
	vnprint $level, $text;
}
sub vprintf {
	my $level = shift;
	my $text = sprintf shift, @_;
	vprint $level, $text;
}

# --- temporarily set verbosity level for a block of code ---
sub vtmp(&$) {
	my ($code, $level) = @_;

	# --- save old level and set new one ---
	my $oldlevel = verbosity();
	verbosity($level);

	# --- run the code ---
	my $retval = &$code;

	# --- reset verbosity and return code value ---
	verbosity($oldlevel);
	return $retval;
}

# === Error Handlng =========================================================
sub die {
	# --- no message if verbosity <= -2 ---
	fatal() ? exit 1 : return if verbosity() < -1;

	# --- generate and print message ---
	my $message = "\n". cpush('R') . (fatal() ? "fatal " : '' ) ."error: ". cpop. join(' ', @_);
	$message .= "\n" unless $message =~ /\n$/ms;

	# --- stack trace ---
	confess($message) if fatal;
	cluck($message);
	print STDERR "\n";
}

sub warn {
	# --- no message if verbosity <= -2 ---
	return if verbosity() < -1;

	# --- generate and print message ---
	my $message = "\n". cpush('Y') ."warning: ". cpop . join(' ', @_);
	$message .= "\n" unless $message =~ /\n$/ms;

	cluck($message);
	print STDERR "\n";
}

# --- temporarily make things non-fatal ---
sub nofatal(&) {
	my $code = shift;

	# --- save old level and set new one ---
	my $oldlevel = fatal();
	fatal(0);

	# --- run the code ---
	my $retval = &$code;

	# --- reset verbosity and return code value ---
	fatal($oldlevel);
	return $retval;
}

# === system() Override =====================================================
sub system {
	my @cmd = @_;

	# --- run the command ---
	vprint vbase(), cpush('c'). "executing: ". cpop . join(' ', @cmd) ."\n";
	system(@cmd) == 0 && do {
		# --- clean exit ---
		vprint vbase() + 1, cpush('g') ."command completed successfully". cpop ."\n";
		return 0;
	};

	# --- error executing command ---
	my $message = "the command did not succesfully execute:\n" . indent() . join(' ', @cmd) ."\n";
	if ($? == -1) {
		$message .= "failed to execute: $!";
	} elsif ($? & 127) {
		$message .= "child died with signal ". ($? & 127) .", ". (($? & 128) ? 'with' : 'without') ." coredump";
	} else {
		$message .= "child exited with value ". ($? >> 8);
	}

	# --- exit/return ---
	iTools::System::die "$message";
}

# --- qx replacement ---
sub command($;%) {
	my ($cmd, %extinfo) = @_;

	# --- use open3 to run command and capture stdout and stderr ---
	my ($out, $err) = (gensym, gensym);
	my $pid = open3 undef, $out, $err, $cmd;

	# --- wait for process to complete and capture return status ---
	waitpid $pid, 0;
	my $stat = $? >> 8;

	my $message = 'child executed successfully';
	# --- error executing command ---
	if ($stat) {
		$message = "the command did not succesfully execute";
		if ($? == -1) {
			$message .= "failed to execute: $!";
		} elsif ($? & 127) {
			$message .= "child died with signal ". ($? & 127) .", ". (($? & 128) ? 'with' : 'without') ." coredump";
		} else {
			$message .= "child exited with value ". ($? >> 8);
		}
	}

	# --- build the %extinfo hash ---
	local $/; 
	%extinfo = (
		stdout  => <$out> || '',
		stderr  => <$err> || '',
		pid     => $pid,
		status  => $stat,
		message => $message,
	);

	# --- return stdout ---
	return wantarray ? split(/[\r\n]/, $extinfo{stdout}) : $extinfo{stdout};
}

# === Filesystem Tools ======================================================
# --- mkdir wrapper with recursive ability ---
sub mkdir {
	foreach my $path (@_) {

		# --- make a directory list ---
		my @dirs = split /\//, $path;                                  # split path into components
		if ($path =~ /^\//) { shift @dirs; $dirs[0] = '/'. $dirs[0]; } # correction for blank entry if '^/'

		# --- create parent directories ---
		my $path = '';
		foreach my $dir (@dirs) {
			$path = ($path ? $path .'/' : ''). $dir;

			# --- skip dir if it already exists ---
			if (-d $path) {
				vprint vbase(), cpush('c') ."mkdir: ". cpop . $path . cpush('y') ." (already exists)". cpop ."\n";
				next;
			}

			return iTools::System::die("writefile: could not create directory '$path' - another file is in the way")
				if -e $path;
			vprint vbase(), cpush('c') ."mkdir: ". cpop ."$path\n";
			mkdir $path, 0755 or iTools::System::die("error creating directory '$path': $!") && return undef;;
}	}	}

# --- chdir wrapper ---
sub chdir {
	my $path = shift;
	vprint vbase(), cpush('c') ."chdir: ". cpop ."$path\n";
	chdir $path or return iTools::System::die("can't chdir to '$path': $!") && return undef;
	return $path;
}

# --- mkdir and chdir in one ---
sub mkcd { iTools::System::mkdir($_[0]); iTools::System::chdir($_[0]) }

# --- create symlink, deleting old one if necessary ---
sub symlink {
	my ($source, $dest) = @_;
	$source =~ s|/$||;                       # remove trailing slash
	$dest ||= ($source =~ m|/([^/]*)$|)[0];  # compute dest if none given

	# --- no destination defined ---
	unless ($dest) {
		iTools::System::die("error: attempted symlink without destination\n");
		return;
	}

	vprint vbase(), cpush('c') . "symlink: ". cpop ."$source -> $dest\n";

	# --- delete old symlink if possible ---
	if (-l $dest) {
		vprint vbase() + 1, cpush('y') ."deleteting old symlink". cpop ."\n";
		unlink $dest or iTools::System::die "could not delete old symlink\n" && return;
	} elsif (-e $dest) {
		iTools::System::die "cannot create symlink $dest, file is in the way\n" && return;
	}

	symlink $source, $dest or iTools::System::die "error creating symlink $dest" && return;
	vprint vbase() + 1, cpush('y') ."symlink created". cpop ."\n";
}

# --- rename wrapper ---
sub rename {
	my ($old, $new) = @_;
	vprint vbase(), cpush('c') ."rename: ". cpop ."$old -> $new\n";
	rename $old, $new or return iTools::System::die("can't rename '$old' to '$new': $!") && return undef;
	return $new;
}

sub unlink {
	vprint vbase(), cpush('c') ."unlink: ". cpop . join(' ', @_) ."\n";
	unlink @_ or iTools::System::die "could not delete files\n" && return;
}

sub link {
	my ($ori, $new) = @_;
	vprint vbase(), cpush('c') ."link: ". cpop ."$ori -> $new\n";
	link $ori, $new
		or iTools::System::die "could not create link\n" && return;
}

# === Private Methods =======================================================

# --- _var and _varDefault ---
# Stolen from iTools::Core::Accessor, see documentation there for details
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
		return $value;              # return the old value
	}

	# --- set and return the value ---
	return $CONFIG->{$key} = shift;
}
sub _varDefault {
	my ($default, $key) = (shift, shift);

	# --- set or reset the value ---
	if (@_) {
		# --- set the value and return ---
		return _var($key => @_) if defined $_[0];
		# --- reset the value, continue to get default ---
		_var($key => undef);
	}

	# --- get the current value ---
	my $value = _var($key);
	# --- return the value if it's defined ---
	return $value if defined $value;

	# --- get the default value ---
	if (ref $default eq 'CODE') { $value = &$default($key) }  # default is code
	else                        { $value = $default }         # default is scalar

	# --- return the default value ---
	return $value = $default;
}

1;

=head1 NAME

iTools::System - system tools

=head1 SYNOPSIS

 use iTools::System qw( FUNCTIONS );

 verbosity(VERBOSITY);
 system(COMMAND);
 iSystemNonFatal(COMMAND);
 iChDir(DIRECTORY);
 iError(MESSAGE);
 iErrorNonFatal(MESSAGE);
 iWarn(MESSAGE);

=head1 DESCRIPTION

This package provides a number of exports for running system commands with error handling wrappers.
It also provides a standard interface for displaying warnings and error messages.

=head1 EXPORTS

All functions myst be explicitly imported.

=over 4

=item iChDir(DIRECTORY)

Does a Perl C<chdir()>.
If DIRECTORY does not exist, or it could not C<chdir()> to the DIRECTORY, it will display a message and C<exit(1)>.

=item iError(MESSAGE)

Displays C<error: MESSAGE> on STDERR and exits with a C<1>.
Since this function calls C<exit()>, there is no relevant return value.

=item iErrorNonFatal(MESSAGE)

Displays C<error: MESSAGE> on STDERR and returns a C<1>.

=item system(COMMAND)

Does a C<system()> call and returns a C<0> on success.
If the command fails, an series of error messages describing the failure will be sent to STDERR and the program will exit with a C<1>.

=item iSystemNonFatal(COMMAND)

Same as C<system()>, except that it will return a C<1> on failure instead of exiting.

=item verbosity([VERBOSITY])

Adjusts the verbosity level of commands in this module.
The following are valid values for VERBOSITY:

   -1  Turn off all warnings (errors will still be displayed)
   0   Default level
   1   display C<system()> commands as executed (like C<bash -x>)
   2   display extended debugging for C<system()> commands

C<verbosity()> will return the new verbosity level, or the current level if called without parameters.

=item iWarn(MESSAGE)

Displays C<warning: MESSAGE> on STDERR and returns a C<1>.

=back

=head1 TODO, KNOWN ISSUES AND BUGS

=over 4

=item B<Quicklist>

  - Make preferred usage as obj?
  - Setting 'fatal' internally is stateful, it shouldn't be.
    - ex. see iSystemNonFatal

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

system(1), perldoc -f system

=cut
