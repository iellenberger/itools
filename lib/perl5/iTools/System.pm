package iTools::System;
use base Exporter;
$VERSION = "0.01";

@EXPORT_OK = (qw(
	fatal nofatal
	die warn
	system command
	mkdir chdir mkcd symlink pushdir popdir
	rename link unlink
	vbase
),
#! it's getting close to the time to deprecate these:
#qw(
#	colored
#	indent verbosity vprint vprintf vnprint vnprintf vtmp
#)
);

use Carp qw( cluck confess );
use Cwd;
use iTools::Term::ANSI qw( color );
use iTools::Verbosity qw( verbosity vpush vpop vprint vprintf vindent );
use IPC::Open3;
use Symbol;

use strict;
use warnings;

# === Class Variables =======================================================
our $CONFIG = { };

# === Deprecated Calls ======================================================
sub vbase     { _varDefault(2, 'vbase', @_) }
# --- the following calls will be removed in the next version of iTools::System ---
#sub verbosity { iTools::Verbosity::verbosity(@_) }
#sub vnprint   { iTools::Verbosity::vprint(@_) }
#sub vnprintf  { iTools::Verbosity::vprintf(@_) }
#sub vprint    { iTools::Verbosity::vprint(shift, '>'. shift, @_) }
#sub vprintf   { iTools::Verbosity::vprintf(shift, '>'. shift, @_) }
#sub indent    { iTools::Verbosity::vindent(@_) }
#sub vtmp(&$) {
#	my ($code, $level) = @_;
#	vpush $level; my $retval = &$code; vpop;
#	return $retval;
#}
sub logfile { iTools::Verbosity::vlogfile(@_) }
sub logonly {
	iTools::Verbosity::vloglevel(iTools::Verbosity::verbosity());
	vpush -3;
}
#sub colored   { iTools::Term::ANSI::colored(@_) }

# === Accessors =============================================================
# --- should errors be fatal? ---
sub fatal     { _varDefault(1, 'fatal', @_) }
sub config { my %args = @_; foreach my $key (keys %args) { $CONFIG->{lc $key} = $args{$key} } }

# === Print Depending on Verbosity ==========================================

# === Error Handlng =========================================================
sub die {
	# --- no message if verbosity <= -2 ---
	fatal() ? exit 1 : return if verbosity() < -1;

	# --- generate and print message ---
	my $message = "\n". color('R', (fatal() ? "fatal " : '' ) ."error: ") . join(' ', @_);
	$message .= "\n" unless $message =~ /\n$/ms;

	# --- stack trace ---
	$Carp::CarpLevel = 1;  # don't include die() in stacktrace
	confess($message) if fatal;
	cluck($message);
	print STDERR "\n";
}

sub warn {
	# --- no message if verbosity <= -2 ---
	return if verbosity() < -1;

	# --- generate and print message ---
	my $message = "\n". color('Y', "warning: ") . join(' ', @_);
	$message .= "\n" unless $message =~ /\n$/ms;

	$Carp::CarpLevel = 1;  # don't include warn() in stacktrace
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

	# --- prepend shell to the command ---
	if (exists $CONFIG->{shell} && defined $CONFIG->{shell}) {
		my $shell = $CONFIG->{shell};
		if (ref $shell eq 'ARRAY') { unshift @cmd, @$shell }
		else                       { unshift @cmd, split /\s+/, $shell }
	}

	# --- run the command ---
	vprint vbase(), color('c', "executing: ") . join(' ', @cmd) ."\n";
	my $retval = system(@cmd) == 0 && do {
		# --- clean exit ---
		vprint vbase() + 1, color('g', "command completed successfully") ."\n";
		return 0;
	};

	# --- error executing command ---
	my $message = "the command did not succesfully execute:\n" . vindent() . join(' ', @cmd) ."\n";
	if ($? == -1) {
		$message .= "failed to execute: $!";
	} elsif ($? & 127) {
		$message .= "child died with signal ". ($? & 127) .", ". (($? & 128) ? 'with' : 'without') ." coredump";
	} else {
		$message .= "child exited with value ". ($? >> 8);
	}

	# --- exit/return ---
	iTools::System::die "$message";
	return $retval;
}

# --- qx replacement ---
sub command($;%) {
	my ($cmd, %extinfo) = @_;

	# --- use open3 to run command and capture stdout and stderr ---
	my ($out, $err) = (gensym, gensym);
	vprint vbase(), color('c', "executing: ") ."$cmd\n";
	my $pid = open3 undef, $out, $err, $cmd;

	# --- wait for process to complete and capture return status ---
	waitpid $pid, 0;
	my $stat = $? >> 8;
	my $message;

	# --- error executing command ---
	if ($stat) {
		$message = "the command did not succesfully execute:\n" . vindent() ."$cmd\n";
		if ($? == -1) {
			$message .= "failed to execute: $!";
		} elsif ($? & 127) {
			$message .= "child died with signal ". ($? & 127) .", ". (($? & 128) ? 'with' : 'without') ." coredump";
		} else {
			$message .= "child exited with value ". ($? >> 8);
		}
		iTools::System::die "$message";
	}
	# --- command executed successfully ---
	else {
		$message = 'command completed successfully';
		vprint vbase() + 1, color('g', "$message") ."\n";
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
	my $retval = 1;

	# --- loop through params (paths) and create the dirs ---
	PATH: foreach my $path (@_) {
		next if -d $path;  # do nothing if it already exists

		vprint vbase(), color('c', "mkdir: ") ."$path\n";

		# --- make a directory list ---
		my @dirs = split /\//, $path;                                  # split path into components
		if ($path =~ /^\//) { shift @dirs; $dirs[0] = '/'. $dirs[0]; } # correction for blank entry if '^/'

		# --- create parent directories ---
		my ($path, $goodpath) = ('', 1);
		foreach my $dir (@dirs) {
			$path = ($path ? $path .'/' : ''). $dir;

			# --- skip dir if it already exists ---
			if (-d $path) {
				vprint vbase() + 1, "mkdir $path". color('y', " (already exists)") ."\n";
				next;
			}

			# --- check for errors ---
			if (-e $path) {
				nofatal {
					iTools::System::die("mkdir: could not create directory '$path' - another file is in the way")
				};
				$goodpath = $retval = 0;
				last;
			}
			vprint vbase() + 1, "mkdir $path\n";
			mkdir $path, 0755 or do {
				iTools::System::die("error creating directory '$path': $!");
				$goodpath = $retval = 0;
				last;
			}
		}
		vprint vbase() + 1, color('g', "path created") ."\n"
			if $goodpath;
	}

	# --- die if we got an error and return status ---
	iTools::System::die("mkdir: could not create all directories")
		unless $retval;
	return $retval;
}

# --- chdir wrapper ---
sub chdir {
	my $path = shift;
	vprint vbase(), color('c', "chdir: ") ."$path\n";
	chdir $path or iTools::System::die("can't chdir to '$path': $!") && return undef;
	return $path;
}

# --- mkdir and chdir in one ---
sub mkcd { iTools::System::mkdir($_[0]); iTools::System::chdir($_[0]) }

# --- push and pop to a directory stack ---
sub pushdir {
	my $dir = shift;
	$CONFIG->{dirstack} ||= [];
	unshift @{$CONFIG->{dirstack}}, cwd;
	return defined $dir ? iTools::System::chdir($dir) : cwd;
}
sub popdir {
	$CONFIG->{dirstack} ||= [];
	my $path = shift @{$CONFIG->{dirstack}};
	if (defined $path) { iTools::System::chdir($path) }
	else               { iTools::System::warn("can't popdir, directory stack is empty") }
	return $path;
}

# --- create symlink, deleting old one if necessary ---
sub symlink {
	my ($source, $dest) = @_;
	$source =~ s|/$||;                       # remove trailing slash
	$dest ||= ($source =~ m|/([^/]*)$|)[0];  # compute dest if none given

	# --- no destination defined ---
	unless ($dest) {
		iTools::System::die("error: attempted symlink without destination\n");
		return undef;
	}

	vprint vbase(), color('c', "symlink: ") ."$source -> $dest\n";

	# --- delete old symlink if possible ---
	if (-l $dest) {
		vprint vbase() + 1, color('y', "deleteting old symlink") ."\n";
		unlink $dest or iTools::System::die "could not delete old symlink\n" && return undef;
	} elsif (-e $dest) {
		iTools::System::die "cannot create symlink $dest, file is in the way\n" && return undef;
	}

	symlink $source, $dest or iTools::System::die "error creating symlink $dest" && return undef;
	vprint vbase() + 1, color('g', "symlink created") ."\n";
	return 1;
}
# --- create a hard link ---
sub link {
	my ($ori, $new) = @_;
	vprint vbase(), color('c', "link: ") ."$ori -> $new\n";
	link $ori, $new
		or iTools::System::die "could not create link\n" && return undef;
}

# --- delete a file ---
sub unlink {
	vprint vbase(), color('c', "unlink: ") . join(' ', @_) ."\n";
	unlink @_ or iTools::System::die "could not delete files\n" && return;
}

# --- rename wrapper ---
sub rename {
	my ($old, $new) = @_;
	vprint vbase(), color('c', "rename: ") ."$old -> $new\n";
	rename $old, $new or return iTools::System::die("can't rename '$old' to '$new': $!") && return undef;
	return $new;
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

iTools::System - system tool replacements and additions

=head1 SYNOPSIS

 use iTools::System qw(
    fatal nofatal
    die warn
    system command
    mkdir mkcd chdir pushdir popdir
    symlink rename link unlink
 );

=head1 DESCRIPTION

This package provides drop-in replacements for a number of Perl built-ins.
Universally, these replacements provide more verbose, controllable error handling and logging.
Other enhancements are also provided as per the nature os each function.

Unless otherwise specified, all functions take the same parameters and
return the same value as their native Perl counterparts.

The following functions are Perl built-in replacements:

   system
   chdir mkdir
   link symlink
   unlink rename
   die warn

The following functions extend functionality:

   fatal()   - enables and disables exit-on-die
   nofatal() - enables and disables exit-on-die for a code block
   command() - replacement for qx()
   mkcd      - combined mkdir() and chdir()

Functions from iTools::Term::ANSI(3pm) and iTools::Verbosity(3pm)
are used extensively in this package to provide colored and verbosity-based output.
See the manual pages for these libraries for details on setting output and logging options.

=head1 EXPORTS

All functions must be explicity imported or called with a full package path.
Failing to do so will run the native Perl function.

Example: Imported Function

   use iTools::System qw( system );    # import 'system()'
   system "command";                   # uses iTools::System
   CORE::system "command";             # uses Perl built-in

Example: Un-imported Function

   use iTools::System;                 # don't import anything
   iTools::System::system("command");  # uses iTools::System
   system "command";                   # uses Perl built-in

=head2 Perl Built-In Replacements:

All built-in replacements (except die() and warn()) provide the following:

  * show commands at verbosity(2) and success messages at verbosity(3)
  * detailed error messages with stacktraces
  * exit the program on error if fatal() is set

=over 4

=item B<system> [PROGRAM] LIST

=item B<link> OLDFILE, NEWFILE

=item B<unlink> LIST

=item B<rename> OLDNAME, NEWNAME

All of these functions take the same parameters and return the same values as
their native Perl counterparts.

=item B<mkdir> PATH [, PATH [...]]

mkdir() takes one or more PATHs and creates to associated directories and
returns '1' if all paths are created and '0' on failure.
It also creats parent directories when necessary.

=item B<chdir> PATH

chdir() changes the working directory to PATH and
returns PATH on success or 'undef' on failure.

=item B<symlink> OLDFILE, NEWFILE

symlink() takes the same parameters as the Perl built-in and
return true on success and false on failure.
It also overwrites existing symlinks if they exist and report when it does at verbosity(3).

=item B<die> LIST

=item B<warn> LIST

die() and warn() take the same parameters and return the same values as the Perl built-ins.
They also provides the following:

  * display messages at verbosity(-1)
  * display a stack trace
  * exit the program if fatal() is set (die() only)

=back

=head2 Extended Functionality:

=over 4

=item B<fatal> 0|1

=item B<nofatal> { CODE }

Allows you to change the fatality level for die() calls.

If fatal() is true (default), all calls to die() will cause the program to exit.
If fatal() is false, all calls to die() will be treated as warnings.

nofatal() allows you to temporarilly set fatal() to false for the given code block.

=item B<command> COMMAND [, %EXTINFO]

command() is a replacement for Perl's qx() with all the added features and
error handling of iTools' system() command (see above).

command() returns an array of lines sent to STDOUT in array context
or a single string of STDOUT output in scalar context.

You may optionally pass a hash as the second parameter to get extended information about the process that ran.
The hash will contain the following information:

  stdout  => <STDOUT> or ''
  stderr  => <STDERR> or ''
  pid     => the process PID
  status  => the shell command's exit status
  message => the success/failure message generated by command()

=item B<mkcd> PATH

Creates the directory PATH and then changes the working directory to PATH.
Same as, "mkdir(PATH); chdir(PATH)"

=item B<pushdir> [PATH]

=item B<popdir>

pushdir() does a chdir() and saves the old directory on a stack.
If no path is given, it simply pushes the current directory to the stack.

popdir() retrieves the last directory pushed onto the stack and returns you to it.

=back

=head1 TODO, KNOWN ISSUES AND BUGS

=over 4

=item ToDo: B<Fully Deprecate Old Verbosity Functions>

Need to do this after all my other tools are converted.

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
