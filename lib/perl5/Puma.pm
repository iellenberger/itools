package Puma;
use base 'Puma::Object::Tag';

use Puma::Core::Engine;
use Puma::Core::Server;
use Puma::Tools::Capture qw(capture);

use strict;
use warnings;

# === Constructor ===========================================================
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref $this || $this;

	# --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'server' && $self->server($value);
	}

	return $self;
}

# === Rendering Methods =====================================================
sub include {
	my ($self, %args) = @_;
	my $retval = $self->render(%args, showHeader => '0');
	print $self->html;
	return $retval;
}

sub render {
	my ($self, %args) = @_;

	# --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'server' && $self->server($value);
		lc $key eq 'file' && $self->file($value);
		lc $key eq 'showHeader' && $self->showHeader($value);
	}

	# --- declare variables in this scope ---
	my ($server, $code, @errors);
	my $html = '';

	# --- generate code from the .puma source ---
	my $startup = capture {
		# --- capture SIGWARN messages ---
		local $SIG{__WARN__} = sub { push @errors, $_[0] };

		# --- create the server object (CGI) ---
		$server = new Puma::Core::Server(Puma => $self);

		# --- parse and codify ---
		my $engine = new Puma::Core::Engine(File => $self->file);
		$code = $server->getStartCode . $engine->render . $server->getEndCode;
	};
	# --- capture error messages ---
	push @errors, $@ if $@;
	push @errors, $startup if $startup;

	# --- generate output from the code ---
	my $output = capture {
		# --- capture SIGWARN messages ---
		local $SIG{__WARN__} = sub { push @errors, $_[0] };
		eval($code);
	};
	# --- capture error messages, ignore 'SAFE' die messages ---
	push @errors, $@ if $@ && !( $@ =~ /^SAFE/);

	# === ERRORS!! ===
	if (@errors) {
		# --- stop any redirects before spitting out the header ---
		$server->redirect('');
		$html .= $server->header if $self->showHeader;

		# --- show the errors ---
		$html .= "<pre>Puma Server Pages Error : ";
		foreach my $err (@errors) { $html .= "\n$err"; }
		$html .= "</pre><hr>\n";
		$html .= "<code>". $server->header ."</code><br><hr>";

		# --- add line numbers to the code and display it ---
		my $lcode;
		my @lines = split /\n/, $code;
		my $linenumber = 1;
		foreach my $line (@lines) {
			$line =~ s/</&lt;/g;
			$lcode .= $linenumber++ .": $line\n";
		}
		$html .= "<pre><code>$lcode</code></pre>\n";

		$self->html($html);

		return -1;
	}

	# === Clean Run ===
	# --- spit out the header ---
	$html .= $server->header if $self->showHeader;
	# --- spit out the page unless there was a redirect ---
	$html .= $output ."\n" unless $server->redirect;
	$self->html($html);
}

# === Accessors =============================================================
# --- value accessors ---
sub file { defined $_[1] ? $_[0]->{_file} = $_[1] : $_[0]->{_file} || $ENV{PATH_TRANSLATED} }
sub html { defined $_[1] ? $_[0]->{_html} = $_[1] : $_[0]->{_html} }
sub showHeader { defined $_[1] ? $_[0]->{_showHeader} = $_[1] : $_[0]->{_showHeader} || 1 }

# --- object accessors ---
sub server  { defined $_[1] ? $_[0]->{_server} = $_[1] : $_[0]->{_server} }

1;
