package Puma::Core::Page;
use base Puma::Core::Parser;

use strict;
use warnings;

# === Tree Codification =====================================================
sub codify {
	my $self = shift;
	my $tree = $self->parse(@_);
	return $self->{_code} = $self->walk(@$tree);
}

sub walk {
	my ($self, @tags) = @_;

	my $code = '';
	my $body = ''; # for concatenating consecutive body tags
	foreach my $tag (@tags) {
		# --- plain old text ---
		if (exists $tag->{body} && !exists $tag->{label}) {
			$body .= $tag->{body};
			next;
		}
		$code .= $self->codifyBody($body);
		$body = '';

		# --- code ---
		$tag->{label} eq ':' && do { $code .= $tag->{body}; next };
		# --- code + print ---
		$tag->{label} eq ':=' && do { $code .= "print sub {$tag->{body}};\n"; next };
		# --- object tag ---
		$tag->{label} =~ /^[^:]/ && do { $code .= $self->codifyObject($tag); next };
		# --- special processing commands ---
		$tag->{label} =~ /^:[^:]/ && do { $code .= $self->codifySpecial($tag); next };
	}

	return $code . $self->codifyBody($body);
}

# --- generate code for text bodies ---
sub codifyBody {
	my ($self, $body) = @_;
	return '' if $body eq '';
	# --- make all-whitespace text compact ---
	$body =~ s/\n/\\n/g if $body =~ /^\s*$/;
	return "print qq[$body];\n";
}

# --- generate code for special tags ---
sub codifySpecial {
	my ($self, $tag) = @_;

	my $code = '';
	SPECIAL: {
		my $sw = ($tag->{label} =~ /^:(\S*)/)[0] || '';

		# --- use tag ---
		$sw eq 'use' && do {
			my $attr = $tag->{attribute};

			# --- use library and module ---
			$code .= "use lib '$attr->{lib}'; " if defined $attr->{lib}; # library path
			my $import = $attr->{'import'} ? " qw($attr->{import})" : '';
			$code .= "use $attr->{module}$import; " if defined $attr->{module}; # module

			# --- create an object if necessary ---
			if (defined $attr->{prefix}) {
				$code .= "my \$$attr->{prefix} = new $attr->{module}(";

				# --- delete attrs we don't want to pass to the constructor and add $server ---
				delete @{$attr}{qw( lib module prefix import )};
				$code .= $self->attr2param(%$attr, Server => '`$server`') ."); ";
			}
			$code =~ s/\s$//ms;
			$code .= "\n";
			last;
		};

		#! Add any other special tags here
	};

	return $code;
}

# --- generate code for object tags ---
sub codifyObject {
	my ($self, $tag) = @_;

	my $code = '';
	my ($object, $method) = split /:/, $tag->{label};

	# --- create code for calling tag object ---
	$code .= "\$$object->_render(sub { \$$object->$method("
		. $self->attr2param(%{$tag->{attribute}})
		. ") }, sub {";

	# --- walk body of it exists ---
	$code .= "\n". $self->walk(@{$tag->{body}})
		if ref $tag->{body};

	# --- finish it off and return ---
	return $code ."});\n";
}

# --- convert an attribute hash into a string of parameters ---
sub attr2param {
	my ($self, %attrs) = @_;

	my $paramstr = '';
	foreach my $key (keys %attrs) {
		my $value = $attrs{$key};

		# --- quote the value correctly ---
		if ($value =~ /^`([^`]+)`$/) {
			$value = $1;
		} else {
			$value =~ s/(\')/\\$1/g;
			$value = "'$value'";
		}

		# --- tack the pair to the string ---
		$paramstr .= qq[$key => $value, ];
	}
	# --- remove trailing cruft to make it pretty ---
	$paramstr =~ s/[\s,]*$//sm;

	return $paramstr;
}

1;
