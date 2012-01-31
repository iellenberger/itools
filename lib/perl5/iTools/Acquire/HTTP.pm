package iTools::Acquire::HTTP;
use base qw( iTools::Acquire::Base );
$VERSION = "0.01";

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use LWP::UserAgent;

use strict;
use warnings;

# === Required Method Overrides =============================================
sub fetch {
	my ($self, $uri) = @_;
	$uri = $self->uri unless defined $uri;

	# --- fetch URI content ---
	my $path = $uri->uri;
	my $ua = LWP::UserAgent->new;
	$ua->agent("iTools-Acquire/$iTools::Acquire::HTTP::VERSION ");
	my $req = HTTP::Request->new(GET => $path);
	my $res = $ua->request($req);

	# --- return content or error ---
	if ($res->is_success) {
		$self->content($res->content);
	} else {
		$self->content(undef);
		$self->message($res->status_line);
	}

	# --- return content ---
	return $self->content;
}

1;
