package iTools::Acquire;
use base qw( Exporter );
$VERSION = "0.01";

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::URI;

@EXPORT = qw(
	acquire
	acquireMessage
	acquireLoader
);

use strict;
use warnings;

# === Class Variables =======================================================
# --- pre-registered loaders ---
our $LOADERS = {
	file => 'iTools::Acquire::File',
	smb  => 'iTools::Acquire::File',  # this shouldn't use ::File, but it's good enough for now
	http => 'iTools::Acquire::HTTP',
};

# --- last message ---
our $LASTMESSAGE;

# === Exports ===============================================================
sub acquire {
	my ($path, %args) = @_;

	# --- create URI object and get loader ---
	my $uri = new iTools::URI(URI => $path);
	my $loader = $uri->scheme || 'file';  # default to 'file'
	$loader = lc $loader;                 # lowercase for convenience

	unless (exists acquireLoader()->{$loader} && defined acquireLoader()->{$loader}) {
		#! TODO - replace this withe a class method like acquireMessage();
		warn "Unregister loader for URI $path";
		return;
	}

	my $class = acquireLoader()->{$loader};

	eval "require $class" or do {
		print STDERR "Could not load class '$class'\n$@";
		return;
	};

	my $obj = new $class($uri, %args);
	my $content = $obj->fetch;

	$LASTMESSAGE = $obj->message;

	return $content;
}

sub acquireMessage() { $LASTMESSAGE || '' };

sub acquireLoader() { $LOADERS };

1;

=head1 NAME

iTools::Acquire - package for acquiring data via a URI

=head1 SYNOPSIS

 use iTools::Acquire qw( acquire acquireMessage acquireLoader );

 my $content = acquire('http://google.com');
 print acquireMessage ."\n" if acquireMessage;

 acquireLoader()->{ftp} = 'My::FTP';

=head1 DESCRIPTION

B<iTools::Acquire> is a class designed to make it easy to read data from a URI addressable source.

=head1 EXPORTS

=over 4

=item B<acquire>(I<PATH> [, I<ARGS>])

B<acquire>() is used to fetch the content refered to by I<PATH>.
The I<PATH> parameter can be expressed as either a local file path, a URI (a.k.a. URL).

I<ARGS> are passed to the constructor of the loader submodule.
See the documentation for the individual loader for argument details.

Returns the content of I<PATH>

=item B<acquireMessage>()

Returns the last message generated during a call to B<acquire>().
If a blank string is returned, no message was generated.
If a non-blank string is returned, an error condition occurred and the string is a description of that string.

See the TODO list below for potential future enhancements.

=item B<acquireLoader>()

B<iTools::Acquire> associates URI loaders to classes that process data for the given loader.
B<acquireLoader()> is the accessor for that hashref and is used as follows:

  # --- fetch the loader map hashref ---
  my $loaders = acquireLoader;

  # --- add, change or delete a loader mapping ---
  acquireLoader()->{ftp} = 'My::FTP';           # add loader for 'ftp://' URIs
  delete acquireLoader()->{file} = 'My::File';  # change 'file://' to a new loader
  delete acquireLoader()->{http};               # delete 'http://' loader

This is the default loader map:

  { file => 'iTools::Acquire::File',
    smb  => 'iTools::Acquire::File',
    http => 'iTools::Acquire::HTTP' }

=back

=head1 TODO, KNOWN ISSUES AND BUGS

=over 4

=item B<Quicklist>

  - better error/warning checking/reporting

=item B<Correct handling of SMB URIs>

At present SMB is handles by the ::File plugin.
This will not work for non-connected shares.
It should be modified to use the correct native tools (such as sbmclient) for content retrieval.

=back

=head1 REPORTING BUGS

Report bugs in the Bug Tracker at Puma's SourceForge project page:
L<http://sourceforge.net/projects/puma/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2011 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the Puma distribution.

=head1 DEPENDENCIES

strict(3pm) and warnings(3pm);
Exporter(3pm);
iTools::URI(3pm),

=head1 SEE ALSO

iTools::Acquire::Base(3pm)

=cut
