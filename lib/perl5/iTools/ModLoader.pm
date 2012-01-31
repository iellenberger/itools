package iTools::ModLoader;
use base 'Exporter';
our $VERSION = 0.1;

@EXPORT = qq(loadmodule);

use strict;
use warnings;

our $LASTMESSAGE;

sub loadmodule {
	my $module = shift;

	# --- search to see if module is already loaded ---
	my $path = "$module.pm";
	$path =~ s/::/\//g;
	if (exists $INC{$path}) {
		$LASTMESSAGE = "Module '$module' already loaded";
		return 1;
	}

	# --- load the module ---
	eval "require $module" or do {
		$LASTMESSAGE = "Error loading Module '$module', $@";
		return 0;
	};

	# --- success ---
	$LASTMESSAGE = "Module '$module' successfully loaded";
	return 1;
}

1;

=head1 NAME

iTools::ModLoader - alternative Perl module loader

=head1 SYNOPSIS

 use iTools::ModLoader;
 if (loadmodule("Foo::Bar")) {
     print "success: ";
 } else {
     print "failure: ";
 }
 print "$iTools::ModLoader::LASTMESSAGE\n";

=head1 DESCRIPTION

B<iTools::ModLoader> is an alternative Perl module (package/class) loader
that adds functionality over the standard Perl C<require()> command.

Some older version of Perl had issues loading and/or correctly identifying the path of inlined modules.
This would sometime lead to C<require()>s failing or attempting to load modules multiple times.
To avoid these problems, B<iTools::ModLoader> checks the canonical path for
the requested module before attempting to load it.
If the module is not found, it will load it.
If the module is found it will not reload the module and return a success status.

=head1 KNOWN ISSUES AND BUGS

None.

=head1 AUTHOR

Written by Ingmar Ellenberger.

=head1 COPYRIGHT

Copyright (c) 2001-2011, Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the Puma distribution.

=head1 SEE ALSO

perldoc -f require

=cut
