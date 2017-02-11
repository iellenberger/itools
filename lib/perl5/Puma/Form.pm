package Puma::Form;
use base qw( Puma::Object::Tag Puma::Form::Application );

use Data::Dumper; $Data::Dumper::Indent = 1; # for debugging only
use HashRef::NoCase qw( nchash );

use strict;
use warnings;

# === Constructor ===========================================================
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref $this || $this;

	# --- get params ---
	#! TODO: throw error if no server param
	while (my ($key, $value) = each %args) {
		lc $key eq 'name'   && $self->name($value);
		lc $key eq 'server' && $self->server($value);
		$key =~ /^app(?:lication)?/i && $self->app($value);
	}

	# --- do submit processing if submitted ---
	# $self->doSubmit if ($self->server->param('_FormName') || '') eq $self->name;

	return $self;
}

# === Accessors =============================================================
# --- value accessors ---
sub name      { defined $_[1] ? $_[0]->{_name}   = $_[1] : $_[0]->{_name}   || '__unknown__' }
# sub submitted { defined $_[1] ? $_[0]->{_submit} = $_[1] : $_[0]->{_submit} || 0 }
# sub valid     { defined $_[1] ? $_[0]->{_valid}  = $_[1] : $_[0]->{_valid}  || 0 }

# --- object accessors ---
sub app     { defined $_[1] ? $_[0]->{_app}    = $_[1] : $_[0]->{_app} || $_[0] }
sub server  { defined $_[1] ? $_[0]->{_server} = $_[1] : $_[0]->{_server} }
# sub session { shift->server->session('session') } # read only

# === Tags ==================================================================

# <tag:css />
use Puma::Form::CSS;
sub style { Puma::Form::CSS::style(@_) }
sub css { Puma::Form::CSS::css(@_) }

# <tag:form
#    onSuccess="destination.page" - replacement for 'action=""', but does not override it
#    method="get|post"            - defaults to 'post'
# > ... </tag:form>
sub form {
	my ($self, $args) = (shift, nchash(@_));

	# --- get body and set defaults ---
	my $body = $self->getBody($args);
	$args->{method} ||= 'post';

	# --- opening tag ---
	print '<form'. $self->_paramString(%$args) .'>';

	# --- 
	print qq[<input type="hidden" name="_FormName" value="]. $self->name .qq[">];

	# --- render the form body ---
	$body->();

	# --- print closing tag and return ---
	print '</form>';
	return;
}

# === Utility Methods =======================================================
# --- convert a hash to a string of parameters ---
sub _paramString {
	my ($self, %params) = @_;

	my $paramstr;
	while (my ($key, $value) = each %params) {
		$value = '' unless defined $value;
		if ($value eq '' && $key =~ /checked|selected/) {
			$paramstr .= " $key";
		} else {
			$paramstr .= qq[ $key="$value"];
	}	}
	return $paramstr;
}

# === Form Validation =======================================================

#! TODO: this isn't being used yet, need to compete and implement it.
sub doSubmit {
	my $self = shift;

	# --- load persistant data from previous rendering ---
	# $self->_loadPersistent;

	# --- set the submitted flag and load the app object ---
	$self->submitted(1);
	my $app = $self->app;
	my $cgihash = $self->server->paramHash;

	# --- push CGI params to app object ---
	$self->setValue(%$cgihash);

	# --- allow the application to do form validation/initialization ---
	$self->valid($app->validate(Form => $self));

	# --- redirect if sucessful submit ---
	# my $dest = $self->_persist('_main_', 'onSuccess');
	my $dest; #!???
	if ($dest && $self->valid) {
		#! TODO: removing this line eliminates the need for form expiry.  Perhaps we ought to clear on entry?
		# $self->_clearSession;
		$self->server->redirect($dest);
		die "SAFE: processing redirect";
	}

	# $self->_clearPersistent;
}
# sub _clearSession { delete $_[0]->server->session('session')->{'Puma::Form'} }

# === Form Data Persistance =======================================================
#sub _loadPersistent { $_[0]->{_persistent} = $_[0]->server->session('session')->{'Puma::Form'}->{$_[0]->name} }
#sub _storePersistent { $_[0]->server->session('session')->{'Puma::Form'}->{$_[0]->name} = $_[0]->{_persistent} }
#sub _clearPersistent { delete $_[0]->{_persistent} }
#sub _persist {
#	my ($self, $name, $key, $value) = @_;
#	return $self->{_persistent}->{$name}->{$key} = $value if defined $value;
#	return $self->{_persistent}->{$name}->{$key} if defined $key;
#	return $self->{_persistent}->{$name} if defined $name;
#	return $self->{_persistent};
#}

# === Puma::Tag::Application Overrides ======================================
sub validate { 1 }

# === Puma::Object::Application Overrides ===================================
# --- get form values from application ---
sub getValue {
	my ($self, $key) = @_;
	my $app = $self->app;

	return $self->{_value}->{$key} if $app == $self;
	return $app->getValue($key);
}

# --- set application values from form ---
sub setValue {
	my ($self, $key, $value) = @_;
	my $app = $self->app;
	
	return $self->{_value}->{$key} = $value if $app == $self;
	return $app->setValue($key, $value);
}

# === Form tags =============================================================

sub button { shift->_button('button', @_); }
sub reset  { shift->_button('reset',  @_); }
sub submit { shift->_button('submit', @_); }
sub image  { shift->_button('image',  @_); }

sub file     { shift->_input('file',     @_); }
sub hidden   { shift->_input('hidden',   @_); }
sub password { shift->_input('password', @_); }
sub text     { shift->_input('text',     @_); }

sub checkbox { shift->_checkbox('checkbox', @_); }
sub radio    { shift->_checkbox('radio',    @_); }

sub select   { my $self = shift; $self->_select(@_); }
sub option   { my $self = shift; $self->_option(@_); }
sub textarea { my $self = shift; $self->_textarea(@_); }


# === Tags ==================================================================
sub _button {
	my ($self, $type, $args) = (shift, shift, nchash(@_));
	$args->{type} = $type;
	print '<input'. $self->_paramString(%$args) .'>';
}

#tag definitions:
#
#	<input
#		required - flag the field as required for validation
#		label="" - the label prepended to the field (can contain HTML)
#			- is this necessary?
#		default="" - the default value - overridden by the app object's value
#	>

# --- for text, password, hidden and file input fields ---
sub _input {
	my ($self, $type, $args) = (shift, shift, nchash(@_));

	# --- preset variables as necessary ---
	$args->{type} = $type;
	my $name     = $args->{name};
	my $required = delete $args->{required};
	my $label    = delete $args->{label};
	my $default  = delete $args->{default};

	# --- determine the value ---
	unless ($args->{value}) {  # --- value="" always takes priority ---
		$args->{value} = $self->getValue($name);
		$args->{value} = $default unless defined $args->{value};
	}
	delete $args->{value} unless defined $args->{value};

	# --- data to persist ---
	# $self->_persist($name, required => 1) if defined $required;

	# --- draw the tag ---
	print $label if defined $label;
	print '<input'. $self->_paramString(%$args) .'>';
}

# <:checkbox|radio>

sub _checkbox {
	my ($self, $type, $args) = (shift, shift, nchash(@_));
	$args->{type} = $type;
	my $body = $self->getBody($args);

	# --- get value param from application ---
	if (defined delete $args->{appvalue}) {
		$args->{checked} = ''
			if $args->{value} eq ($self->getValue($args->{name}) || '');
		#print "<br>'$args->{value}' '$args->{name}' '". ($self->getValue($args->{name}) || '?') ."'<br>\n";
	}

	if ($body) {
		print "<label>";
	}
	print '<input'. $self->_paramString(%$args) .'>';

	if ($body) {
		$body->();
		print "</label>";
	}

$Data::Dumper::Deparse=1;
print "<br><pre>". Dumper($self->{_codestack}) ."<br></pre>\n";
}

sub _select {
	my ($self, %args) = @_;
	my $body = $self->getBody(%args);
	print "<select". $self->_paramString(%args) .">";
	$body->();
	print "</select>";
}

sub _option {
	my ($self, %args) = @_;
	my $body = $self->getBody(%args);
	print "<option". $self->_paramString(%args) .">";
	$body->();
	print "</option>";
}

sub _textarea {
	my ($self, $args) = (shift, nchash(@_));
	my $body = $self->getBody($args);

	# --- get value param from application ---
	my $value = delete $args->{value} || '';
	$value = $self->getValue($args->{name}) || ''
		if defined delete $args->{appvalue};

	# --- build the tag and render the children ---
	print '<textarea'. $self->_paramString(%$args) .">$value";
	$body->();
	print "</textarea>";
}


1;


=head1 NAME

Puma::Form - Forms interface for Puma

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<new Puma::Core::Engine>();

=back

=head1 TAGS

=head2 <:use prefix="form" module="Puma::Form" name="Upload" />

=head2 <form:form onSuccess="upload2.puma">



=head1 EXAMPLES

=head1 TODO

=head1 KNOWN ISSUES AND BUGS

=head1 REPORTING BUGS

Report bugs in the Bug Tracker at Puma's SourceForge project page:
L<http://sourceforge.net/projects/puma/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2005 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the Puma distribution.

=head1 DEPENDENCIES

strict(3pm) and warnings(3pm) (stock Perl);

=head1 SEE ALSO

=cut

__END__


# === Error handling routines ===============================================

sub error {
	my ($self, $message) = @_;
	$self->{_error} ||= [];

	push @{$self->{_error}}, $message if defined $message;
	return $self->{_error};
}

sub errorMessages {
	my $self = shift;
	#! TODO: return a constructed array when the full error structure is defined
	return $self->{_error};
}


