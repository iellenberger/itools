package iTools::SSH::Parallel;
use base qw( iTools::Core::Accessor );
$VERSION = 0.1;

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1;
use IPC::Open3;
use POSIX ":sys_wait_h";
use Symbol;
use Time::HiRes qw( usleep );
use iTools::System qw( verbosity vprint vnprint vnprintf );
use iTools::Term::ANSI qw( color cpush cpop );

use strict;
use warnings;

# === Constuctor and Constructor-like methods ===============================
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref $this || $this;

	# --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		next unless defined $value;
		lc $key eq 'cmd'       && $self->cmd($value);
		lc $key eq 'hosts'     && $self->hosts(ref $value eq 'ARRAY' ? @$value : $value);
		lc $key eq 'timeout'   && $self->timeout($value);
		lc $key eq 'user'      && $self->user($value);
		lc $key eq 'indent'    && $self->indent($value);
		lc $key eq 'vbase'     && $self->vbase($value);
		lc $key eq 'rate'      && $self->rate($value);
	}

	return $self;
}

# === Accessors =============================================================
sub cmd     { shift->_var(_cmd => @_) }                 # shell command
sub hosts   { shift->_varArray(_hosts => @_) }          # array of hosts
sub timeout { shift->_varDefault(30, _timeout => @_) }  # comand timeout
sub user    { shift->_var(_user => @_) }                # login user
sub rate    { shift->_varDefault(0, _rate => @_) }      # processes / sec to spawn, 0 = no wait

sub hosthash {
	my $self = shift;
	my $hosthash = $self->{_hosthash} ||= {};

	# --- return a slice ---
	if (@_) {
		my $slice;
		@{$slice}{@_} = @{$hosthash}{@_};
		return $slice;
	}

	# --- return the whole hash ---
	return $hosthash;
}

# --- display format flags ---
sub useAnsi       { shift->_var(_useAnsi      => @_) }
sub useBackspace  { shift->_var(_useBackspace => @_) }
# --- indent depth ---
sub indent {
	my $self = shift;
	$self->_varDefault($self->vbase() * 3, _indent => @_)
}
# --- base verbosity ---
sub vbase { shift->_varDefault(1, _vbase => @_) }

# --- private accessors ---
sub _starttime  { shift->_var(_starttime => @_) }  # epoch time first process was started
sub _prochash { shift->{_prochash} ||= {} }    # hash of running processes indexed by host

# === Thread Management =====================================================
# --- single call for spawn() and reap() ---
sub run {
	my $self = shift;
	$self->useBackspace(1);
	$self->spawn(@_);
	my $hosthash = $self->reap;
	$self->useBackspace(0);
	return $hosthash;
}

# --- spawn all processes ---
sub spawn {
	# --- incoming params ---
	my ($self, $cmd, @hosts) = @_;
	if ($cmd)   { $self->cmd($cmd) }     else { $cmd   = $self->cmd }
	if (@hosts) { $self->hosts(@hosts) } else { @hosts = $self->hosts }

	# --- declare/define a few vars ---
	my $user = $self->user ? $self->user ."@" : ''; # get username as user@
	my $prochash = $self->_prochash;
	my $rate = $self->rate;
	my $sleeptime = $rate ? int(1000000 / $rate) : 0;

	# --- spawn processes ---
	$self->start(time);
	foreach my $host (@hosts) {
		#$self->hostState($host, 'STARTING');

		# --- fire off the command, capturing stdout/err ---
		my ($out, $err) = (gensym, gensym);
		my $pid = open3 undef, $out, $err, "ssh $user$host $cmd";

		# --- save off info to track the process ---
		$prochash->{$host} = {pid => $pid, out => $out, err => $err};

		# --- set the host state and run a reaper ---
		$self->hostState($host, 'RUNNING');
		$self->reapOnce;

		# --- slow things down if requested ---
		usleep($sleeptime) if $sleeptime;
	}
}

# --- reap processes ---
sub reap {
	my $self = shift;

	# --- declare/define a few vars ---
	my $starttime = $self->_starttime;
	my $prochash  = $self->_prochash;
	my $hosthash  = $self->hosthash;
	my $timeout   = $self->timeout;
	my ($elapsed, $lasttime) = (0, time - $starttime);

	# --- reap processes until timeout ---
	while (%$prochash && $elapsed <= $timeout) {
		$lasttime = $elapsed; $elapsed = time - $starttime;
		$self->reapOnce;

		# --- sleep 1/10th os a second so we don't work too hard ---
		usleep 100000;
	}
	# --- if we get here with live processes, detach and report error ---
	foreach my $host (keys %$prochash) {
		kill 'TERM', $prochash->{$host}->{pid};
		$hosthash->{$host}->{stderr} = "[SSH::Parallel] process did not return within $timeout seconds";
		$self->hostState($host, 'ERROR');
	}
	$self->finish;

	# --- return host hash ---
	return $hosthash;
}

# --- same as reap(), but only does a single pass ---
sub reapOnce {
	my $self = shift;

	# --- declare/define a few vars ---
	my $prochash = $self->_prochash;
	my $hosthash   = $self->hosthash;
		
	# --- reap processes that have completed ---
	foreach my $host (keys %$prochash) {
		
		# --- skip process if it's still running ---
		next unless waitpid($prochash->{$host}->{pid}, WNOHANG);

		# --- get pid and status ---
		$hosthash->{$host}->{pid}    = $prochash->{$host}->{pid};
		$hosthash->{$host}->{status} = $? >> 8;

		# --- reap stdout and stderr ---
		my $out = $prochash->{$host}->{out};
		my $err = $prochash->{$host}->{err};
		local $/;
		$hosthash->{$host}->{stdout} = <$out> || undef;
		$hosthash->{$host}->{stderr} = <$err> || undef;

		# --- check for errors ---
		if ($hosthash->{$host}->{status}) {
			$self->hostState($host, 'ERROR');
		} elsif ($hosthash->{$host}->{stderr}) {
			$self->hostState($host, 'WARNING');
		} else {
			$self->hostState($host, 'COMPLETE');
		}

		delete $prochash->{$host};
	}
}

# === Status and Output =====================================================
# --- set the status of the host and display ---
sub hostState {
	my ($self, $host, $code) = @_;
	$self->hosthash->{$host}->{state} = $code;

	# --- display the status of the host ---
	$self->showHost( 'm', $host) if $code eq 'STARTING';
	$self->showHost('*k', $host) if $code eq 'RUNNING';
	$self->showHost('g', $host) if $code eq 'COMPLETE';
	$self->showHost('*r', $host) if $code eq 'ERROR';
	$self->showHost('*y', $host) if $code eq 'WARNING';
}

# --- redraw the host on the screen in a given color ---
sub showHost {
	my ($self, $code, $host) = @_;
	return unless $self->vbase() <= verbosity();

	my $hash = $self->hosthash;
	# --- reset to starting posistion and move to relative x/y ---
	# <esc>8     - go to saved position
	# <esc>[{x}C - move left {x} spaces
	# <esc>[{y}B - move down {y} lines
	vnprintf $self->vbase(), "\e8\e[%dC\e[%dB", $hash->{$host}->{_x}, $hash->{$host}->{_y} + 1;
	vnprint $self->vbase(), color($code, $host);
}

# --- set up the screen for dynamic updates ---
sub start {
	my $self = shift;
	$self->_starttime(time);
	return unless $self->vbase() <= verbosity();

	# --- set a few vars ---
	my @hosts = $self->hosts;
	my $hash = $self->hosthash;
	my $indent = $self->indent;
	$| = 1;  # STDOUT autoflush

	# --- get the terminal width, default to 78 columns ---
	my $cols;
	eval { # use an eval to catch issues with pipe redirects
		require Term::ReadKey;
		$cols = ((Term::ReadKey::GetTerminalSize())[0] || 80) - 2;
	};
	$cols ||= 78;

	# --- calculate how many lines we're going to need ---
	my ($x, $y) = ($indent + 3, 0);
	foreach my $host (@hosts) {
		my $hostlen = length $host;
		if ($x + $hostlen > $cols) {
			$x = $indent + 3; $y++;
		}

		$hash->{$host}->{_x} = $x;
		$hash->{$host}->{_y} = $y;

		$x += $hostlen + 1;
	}
	$self->{_y} = $y;

	vnprint $self->vbase(), indentText($indent, "Shelling to ". scalar(@hosts) ." hosts:" . ("\n" x ($y + 2)));
	# --- move up to starting position (<esc>[{lines}A) and save position (<esc>7) ---
	# <esc>[{y}A - move up {y} lines
	# <esc>7     - save posision
	vnprint $self->vbase(), "\e[". ($y + 2) ."A\e7";
}

# --- move to end of display area ---
sub finish {
	my $self = shift;
	return unless $self->vbase() <= verbosity();
	vnprint $self->vbase(), "\e8". ("\n" x ($self->{_y} + 2));
}

# === Exit Status Report ====================================================

# --- report status of each host ---
# level 1 = all hosts
# level 2 = where stderr
# level 3 = where exit status
sub report {
	my ($self, $level, $indent) = (shift, shift, shift || 0);
	$level = 2 unless defined $level;

	my $hosthash = $self->hosthash; 
	foreach my $host (sort keys %$hosthash) { 
		my $hash = $hosthash->{$host};

		# --- determine return level and generate short message ---
		my ($hostlevel, $short, $outcolor, $errcolor);
		if ($hash->{status}) {
			# --- error ---
			($hostlevel, $outcolor, $errcolor) = (3, '*y', '*r');
			$short = "$host exited with errors, status ". $hash->{status};
		} elsif ($hash->{stderr}) {
			# --- warning ---
			($hostlevel, $outcolor, $errcolor) = (2, '*g', '*y');
			$short = "$host exited with warnings" ;
		} else {
			# --- happy, happy ---
			($hostlevel, $outcolor, $errcolor) = (1, '*g', '*g');
			$short = "$host exited cleanly";
		}

		# --- only generate message if level high enough ---
		next unless $hostlevel >= $level;
		vprint 1, indentText($indent, "$short\n");

		# --- generate long message ---
		my $long;
		$long .= indentText(color($outcolor, '   stdout: '), $hash->{stdout})
			if $hash->{stdout};
		$long .= indentText(color($errcolor, '   stderr: '), $hash->{stderr})
			if $hash->{stderr};
		vprint 1, indentText($indent, "$long") if defined $long;
	}
}

# === Utility Methods =======================================================
# --- indent a text block --- 
sub indentText { 
	my ($indent, $text) = @_; 
	$indent = ' ' x $indent if $indent =~ /^\d+$/; 
	$text =~ s/^/$indent/mg; 
	return $text; 
} 

1;
