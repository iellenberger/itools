package iTools::Proc::Daemon;
use base qw( Exporter iTools::Core::Accessor );
$VERSION = 0.1;

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging

@EXPORT = qw( daemonize psDaemon );

use Carp;
use English;
use POSIX;
use Time::HiRes qw( usleep );

use strict;

# === obligatory constructor just in case subclass doesn't declare one ======
sub new { bless {}, ref($_[0]) || $_[0] }

# === Accessors =============================================================

# --- logging ---
sub stdlog  { shift->_var('stdlog'  => @_) }  # flag: 0/1
sub logdir  { shift->_varDefault('/var/log', 'logdir' => @_) }
sub logfile { shift->_varDefault( sub {
	my $self = shift;
	return unless $self->stdlog && $self->longname; # no log or unknown name
	return $self->logdir .'/'. $self->longname .".log"
}, 'logfile' => @_) }

# --- PID management ---
sub pid     { shift->_var('pid') }        # public:  ro
sub _pid    { shift->_var('pid' => @_) }  # private: rw
sub piddir  { shift->_varDefault('/var/run', 'piddir' => @_) }
sub pidfile { shift->_varDefault( sub {
	my $self = shift;
	return unless $self->longname; # unknown name
	return $self->piddir .'/'. $self->longname .".pid"
}, 'pidfile' => @_) }

# --- run directories ---
sub nochdir   { shift->_var('nochdir'   => @_) } # flag: 0/1
sub startdir  { shift->_var('startdir'  => @_) } # formerly chdir. Default to '/'?
sub chrootdir { shift->_var('chrootdir' => @_) }

# --- daemon parameters ---
sub user      { shift->_var('user'      => @_) }
sub group     { shift->_var('group'     => @_) }
sub umask     { shift->_var('umask'     => @_) }
sub nicelevel { shift->_var('nicelevel' => @_) }
sub command   { shift->_var('command'   => @_) }

# --- process timeout and kill signal ---
sub timeout   { shift->_varDefault(5, 'timeout' => @_) }
sub signal    { shift->_varDefault(15, 'signal' => @_) }

# --- process/instance naming ---
sub name      { shift->_var('name'     => @_) }
sub instance  { shift->_var('instance' => @_) }
sub longname { join('.', $_[0]->name, $_[0]->instance) || undef }

# sub verbosity { shift->_var('verbosity' => @_) }

# === Methods and functions for daemonizing =================================
sub daemonize {
	my ($self, $sid) = (shift, undef);

	# --- fork and exit parent ---
	iTools::Proc::Daemon::_forkDaemon();

	# --- detach from terminal ---
	croak "Cannot detach from controlling terminal"
		unless $sid = POSIX::setsid();

	# --- fork again to prevent acquiring a controling terminal ---
	$SIG{'HUP'} = 'IGNORE';
	iTools::Proc::Daemon::_forkDaemon();
	$self->isDaemon(1) if $self;

	# -- change working directory and clear file creation mask --- 
	chdir "/"; CORE::umask 0;

	# --- close open file descriptors ---
	foreach my $ii (0 .. iTools::Proc::Daemon::_openmax()) { POSIX::close($ii); }

	# --- disconnect STDIO pipes ---
	open(STDIN,  "+>/dev/null");
	open(STDOUT, "+>&STDIN");
	open(STDERR, "+>&STDIN");

	return $sid;
}

# === Starting a New Daemon =================================================

sub start {
	my $self = shift;
}

# --- check if the process is started ---
sub isStarted {
	my $self = shift;
	my $pid = shift || $self->pid;

	# --- initialize timer ---
	my $timer = 0;
	my $timeout = $self->timeout;

	# --- make sure we have a PID ---
	for (; $timer < $self->timeout; $timer += 0.1) {
		$pid = readPID() unless $pid;  # read the pidfile
		last if $pid;                  # break loop if we have a pid
		usleep 100000;                 # sleep 0.1 sec
	}
	if ($timer >= $self->timeout) {
		# --- time has expired ---
		#viprint(1, "isStarted: could not determine PID\n");
		return -1;
	}

	# --- wait for the daemon to start ---
	for (; $timer < $self->timeout; $timer += 0.1) {
		last if isAlive($pid);         # break loop if process is running
		usleep 100000;                 # sleep 0.1 sec
	}
	if ($timer >= $self->timeout) {
		# --- time has expired ---
		#viprint(1, "isStarted: process is not running\n");
		return 0;
	}

	# --- if we got here, we're good ---
	#viprint(1, "isStarted: process is running\n");
	return 1;
}

# --- daemon forking ---
sub _forkDaemon { exit if iTools::Proc::Daemon::_forkSafe(); $PID }
sub _forkSafe {
	my $pid = 0;
	FORK: {
		if (defined($pid = fork))              { return $pid }
		elsif ($OS_ERROR =~ /No more process/) { sleep 5; redo FORK }
		else                                   { croak "Can't fork: $!" }
}	}

# === Process Status ========================================================
# --- get the process state ---
sub isAlive { shift->getState(shift, 1) }
sub isDead  { shift->getState(shift, 0) }
sub getState {
	my $self = shift;
	#my $pid = shift || readPID() || 0;
	my $pid = shift || $self->pid || 0;
	my $state = shift || 0;

	# --- could not figure out PID ---
	unless ($pid) {
		#viprint(1, "getState($state): could not determine PID\n");
		return -1;
	}

	# --- return whether the proc is running based on desired state ---
	# if state = 0 we're trying to determine if the process is stopped
	# if state = 1 we're trying to determine if the process is running
	my $alive = kill 0, $pid;
#viprint(2, "getState($pid, $state): $alive\n");
	return $state ? $alive : !$alive;
}

# === PIDFile Management ====================================================
# --- get PID from memory or pidfile ---
sub getPID {
	my $self = shift;
	my $file = shift || $self->pidfile;
	return $self->pid if $self->pid;
	return $self->pid = readPID($file);
}

# --- write PID to pidfile ---
sub writePID {
	my $self = shift;
	my $file = shift || $self->pidfile;

	# --- sanity checks ---
	usage("Could not figure out pidfile name. Review matching options")
		unless $file;
	if (-e $file) {
		viprint(1, "(write) pidfile '$file' already exists\n");
		return;
	}

	# --- write the pidfile ---
	open PIDFILE, ">$file" or
		croak "Could not open pidfile '$file'";
	print PIDFILE $PID;
	close PIDFILE;
}

# --- read PID from pidfile ---
sub readPID {
	my $self = shift;
	my $file = shift || $self->pidfile;

	# --- sanity checks ---
	usage("Could not figure out pidfile name. Review matching options")
		unless $file;
	unless (-f $file) {
		viprint(1, "(read) pidfile '$file' does not exists\n");
		return 0;
	}

	# --- read the pidfile ---
	open PIDFILE, "$file" or
		croak "Could not open pidfile '$file'";
	my $pid; { local $/; $pid = <PIDFILE>; }
	close PIDFILE;

	# --- return the PID ---
	viprint(1, "(read) pidfile '$file' was empty\n") if !$pid;
	return $pid;
}

# --- delete pidfile ---
sub deletePID {
	my $self = shift;
	my $file = shift || $self->pidfile;

	# --- sanity checks ---
	croak "Attemted to write pidfile without giving a filename"
		unless $file;
	unless (-e $file) {
		viprint(1, "(delete) pidfile '$file' does not exists\n");
		return;
	}

	# --- attempt to delete the pidfile ---
	croak "Could not delete pidfile '$file'"
		if !unlink($file) || -e $file;
}


# === Private Methods =======================================================
# --- get max number of open files ---
sub _openmax {
	my $openmax = POSIX::sysconf(&POSIX::_SC_OPEN_MAX);
	return (!defined($openmax) || $openmax < 0) ? 64 : $openmax;
}

# === Accessors =============================================================
sub isDaemon { defined $_[1] ? $_[0]->{_OPD_isDaemon} = $_[1] : $_[0]->{_OPD_isDaemon} || 0 }

# === exports (sort of) =====================================================
# --- used to determine whether the process is running ---
#! NOTE: Should this be here or in a different package?
sub psDaemon {
	my $pid = shift || '';
	$pid = $PID if ref $PID || !($pid > 0);

	# --- start building a data structure to report status ---
	my $status = { pid => $pid };
	#! TODO: read /proc/$PID/* to figure these things out
	my $ps = `ps -o uid= -o pid= -o ppid= -o stime= -o tty= -o time= -o args= $pid`;
	if ($ps) {
		# --- split up the ps into componenets ---
		$ps =~ s/^\s+//g;
		my @ps = split /\s+/, $ps;
		$status->{ps}->{uid}    = shift @ps;     # UID
		$status->{ps}->{pid}    = shift @ps;     # PID
		$status->{ps}->{ppid}   = shift @ps;     # PPID
		$status->{ps}->{stime}  = shift @ps;     # STIME
		$status->{ps}->{tty}    = shift @ps;     # TTY
		$status->{ps}->{'time'} = shift @ps;     # TIME
		$status->{ps}->{args}    = join ' ', @ps; # CMD

		# --- it is running! ---
		$status->{running} = 1;
	}

	return $status;
}

1;

=head1 NAME

iTools::Prod::Daemon - process daemonizer

=head1 SYNOPSIS

As imported subroutines:

   use iTools::Proc::Daemon;
   daemonize();
   my $ps = psDaemon(PID);

As an object:

   my $daemon = new iTools::Proc::Daemon();
   $daemon->daemonize
      unless $daemon->isDaemon;

=head1 DESCRIPTION

iTools::Proc::Daemon provides exportable and inheritable interfaces for daemonizing processes.

Daemonization is the process of disconnecting a process from its parent
and connecting it to the root OS process (usually 'init', PID=1).
This is achieved by the following process:

=over 4

=over 3

=item 1.

Forks a child and exits the parent process.

=item 2.

Becomes a session leader (which detaches the program from the controlling terminal).

=item 3.

Forks another child process and exits first child.
This prevents the potential of acquiring a controlling terminal.

=item 4.

Changes the current working directory to "/".

=item 5.

Clears the file creation mask.

=item 6.

Closes all open file descriptors.

=back

=back

The C<daemonize()> method/import does not return a meaningful value.
If an error occurs, C<daemonize()> will croak with an error message.
You may prevent program termination by daemonizing in an C<eval>.

=head1 EXAMPLES

Here's a few simple examples.
All descriptions are in the comments.

As an object:

   # === Main Block of Code ==============================
   my $obj = new Object();            # create object
   $obj->process;                     # start processing

   # === Sample Object ===================================
   package Object;                    # class declaration
   use base 'iTools::Proc::Daemon';      # inherit ::Daemon
   sub process {                      # processing sub
      my $self = shift;               # get $self
      $self->daemonize;               # daemonize
      exit -1 unless $self->isDaemon; # barf if not daemon
      # do stuff                      # do stuff
   }

As an import:

   use iTools::Proc::Daemon; # use the module
   daemonize();              # turn myself into a daemon
   my $psMe = psDaemon();    # get status on myself
   my $psInit = psDaemon(1); # get status PID 1 (init)

=head1 EXPORTS

=over 4

=item daemonize()

Daemonizes the process.

See L<DESCRIPTION>, L<EXAMPLES> and L<METHODS daemonize()> for details.

=item psDaemon([PID])

Returns a data structure describing the status of a process.
The process reported on will be either the current process, or PID if given.

This is an example of the data structure returned.

   {  'pid'     => PID,
      'running' => 1,
      'ps' => {  # fields from `ps -fp PID`
         'cmd'   => '/usr/bin/perl -w ./daemon.t spawn',
         'uid'   => 'ingmar',
         'time'  => '00:00:00',
         'tty'   => '?',
         'c'     => '0',
         'pid'   => 'PID',
         'ppid'  => 1,
         'stime' => 'Jan05'
   }  }

At present, all values are being parsed from the C<ps> command.
A future revision of this package will use data retrieved from the F</proc> filesystem.
For details on the fields, see the manpage for L<ps(1)>.

NOTE: This subroutine may be moved to another package in the future.

=back

=head1 METHODS

=over 4

=item new CLASS()

This is a simple constructor stub provided just in case the developer is lazy and doesn't provide one.
It does nothing more than bless an empty hash into CLASS and return it.

=item OBJECT->daemonize()

Turns the process into a daemon.
C<daemonize()> actually spawns a new process, but except for detached filehandles
and a new PID, this is transparent.

This method is identical to the C<daemonize()> export, except that it runs OBJECT->isDaemon(1).

=item OBJECT->isDaemon([STATUS])

An accessor to set and retrieve a true (1) or false (0) value that indicates whether the process has been daemonized.
If a STATUS is given, the daemon status will be set to that state.

=item OBJECT->psDaemon([PID])

This is identical to the C<psdaemon()> export.

=back

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Written by Ingmar Ellenberger.

Portions taken from B<Proc::Deamon> written by Earl Hood <earl@earlhood.com>.

=head1 COPYRIGHT

Copyright (c) 2026 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

Some portions taken from B<Proc::Deamon>,
copyright (C) 1997-1999 Earl Hood <earl@earlhood.com>
and distributed under The Artistic License.

=head1 DEPENDENCIES

=over 4

=item Core Perl Modules:

B<Carp>,
B<POSIX>,
B<Exporter> (5.006),
B<English>,
B<strict> (5.6.1)

=back

=head1 SEE ALSO

L<ps(1)>,
L<POSIX(3pm)>,
L<Proc::Daemon(3pm)>

=cut
