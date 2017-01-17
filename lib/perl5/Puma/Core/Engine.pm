package Puma::Core::Engine;

use Data::Dumper; $Data::Dumper::Indent = 1; # for debugging only
use Puma::Core::Parser;
use iTools::File qw( readfile );

use strict;
use warnings;

# === Globals ===============================================================
$Puma::Core::Engine::CONFIG = 'file:///ITOOLS_ROOT/etc/puma/puma.xml';

# === Constructor ===========================================================
sub new {
	my ($this, %args) = @_;
	# my $self = $this->SUPER::new(%args);
	my $self = bless {}, ref $this || $this;

	# --- get params ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'config' && $self->config($value);
		lc $key eq 'server' && $self->server($value);
		lc $key eq 'file'   && $self->loadFile($value);
		lc $key eq 'text'   && $self->text($value);
	}
	return $self;
}

# === Accessors =============================================================
sub text { defined $_[1] ? $_[0]->{_text} = $_[1] : $_[0]->{_text} }
sub file { defined $_[1] ? $_[0]->{_file} = $_[1] : $_[0]->{_file} }

#! TODO: change this from an accessor to a method that returns the actual config based on the URL
sub config { defined $_[1] ? $_[0]->{_config} = $_[1] : $_[0]->{_config} }
#! TODO: this should generate the server object if it does not exist
sub server { defined $_[1] ? $_[0]->{_server} = $_[1] : $_[0]->{_server} }

# --- load the contents of a file ---
sub loadFile { $_[0]->text(readfile($_[0]->file($_[1]))) }

# === Tree Codification =====================================================
# --- turn the hash into eval'able code ---
sub render {
	my $self = shift;
	$self = new $self unless ref $self;

	# --- if second param, load as test or file ---
	$_[0] =~ /[<>\n]/ ? $self->text($_[0]) : $self->loadFile($_[0])
		if @_;

	# --- a few presets for convenience ---
	my $text = $self->text;

	# --- parse the text ---
	my $parser = new Puma::Core::Parser(Text => $text);
	my $tree = $self->{parsetree} = $parser->parse;

	# --- create the code header ---
	my $code = ''; # qq[use Puma::Object::Global; use strict;\n\n];

	# --- codify the tree ---
	$code .= $self->codify($tree) if $tree;

	# --- return the generated code ---
	return $code;
}


# --- method called to recursively walk the tree ---
sub codify {
	my ($self, $tree) = @_;

	# --- tree is an array of elements ---
	if (ref $tree eq 'ARRAY') {
		my $code = '';
		foreach my $element (@$tree) {
			$code .= $self->codify($element);
		}
		return $code;
	}

	# --- if we got here, we have a single element ---
	my $element = $tree;

	# --- simple tag types ---
	return $self->genBody($element) unless exists $element->{label}; # body element
	return $self->genInline($element) if $element->{label} eq ':';   # inline code
	return $self->genEval($element)   if $element->{label} eq ':=';  # evaluated code

	# --- special engine tags ---
	return $self->genSpecial($element)
		if $element->{label} =~ /^:\S/;
	
	return $self->genCustom($element)
		if $element->{label} =~ /^\S+:\S+$/;

	#! TODO: error state!
	return '';
}

sub genBody   {
	my ($self, $body) = ($_[0], $_[1]->{body});
	$self->{_genBody} = 1 if !$self->{_genBody} && !($body =~ /^\s*$/);
# print "genBody = $self->{_genBody}\n$body\n";
	return $self->{_genBody} ? "print qq[$body]; " : '';
}
sub genEval   { "print($_[1]->{body}); " }
sub genInline {
	my $code = $_[1]->{body};
	# --- make the inlined code pretty ---
	$code =~ s/^\s*//ms;
	if ($code =~ /\n/) { $code =~ s/[\s;]*$/;\n/s }
	else               { $code =~ s/[\s;]*$/; /s }
	return $code;
}

sub genSpecial {
	my ($self, $element) = @_;

	# --- a few preset for convenience ---
	my $code = '';

	# -- :use tag ---
	if ($element->{label} eq ':use') {
		my $attr = $element->{attribute};

		# --- library path ---
		$code .= "use lib '$attr->{lib}'; " if $attr->{lib};

		# --- module ---
		$code .= "use $attr->{module}". (exists $attr->{import} ? " qw($attr->{import})" : '') ."; "
			if $attr->{module};

		# --- prefix ---
		if ($attr->{prefix}) {
			#! TODO: throw error if prefix sans module

			# --- create the object ---
			$code .= "my \$$attr->{prefix} = new $attr->{module}(";

			# --- add remaining parameters to constructor ---
			while (my ($key, $value) = each %$attr) {
				next if $key =~ /import|lib|module|prefix/; # skip stuff we've already done

				# --- quote the value unless it's an eval (backquotes) ---
				if ($value =~ /^`([^`]+)`$/) {
					$value = $1;
				} else {
					$value =~ s/(\')/\\$1/g;
					$value = "'$value'";
				}

				$code .= "'$key' => $value, "
			}

			# --- the required 'Server' Parameter ---
			$code .= "Server => \$server);";
		}
	}

	return "$code\n";
}

sub genCustom {
	my ($self, $element) = @_;

	# --- get tag prefix and label ---
	my ($prefix, $name) = ($element->{label} =~ /([^:]+):(.+)/);

	# --- generate the method call header ---
	my $tagcode = "\$$prefix->$name(";

	# --- add the parameters ---
	while (my ($key, $value) = each %{$element->{attribute}}) {
		# --- quote the value unless it's an eval (backquotes) ---
		if ($value =~ /^`([^`]+)`$/) {
			$value = $1;
		} else {
			$value =~ s/(\')/\\$1/g;
			$value = "'$value'";
		}
		# --- add the key/valua pair ---
		$tagcode .= "'$key' => $value, "
	}

	# --- add the tagBody parameter if there's a body ---
	$tagcode .= "tagBody => sub{". $self->codify($element->{body}) ."}"
		if defined $element->{body};

	# --- cleanup and return ---
	$tagcode =~ s/, $//;
	$tagcode .= ");";
	return "$tagcode\n";
}

1;

=head1 NAME

Puma::Core::Engine - the rendering engine that converts Puma content into executable code

=head1 SYNOPSIS

  use Puma::Core::Engine;
  my $engine = new Puma::Core::Engine(File => 'file.puma');
  eval $engine->render;

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<new Puma::Core::Engine>();

=back

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
Puma::Core::Parser(3pm)

=head1 SEE ALSO

=cut
