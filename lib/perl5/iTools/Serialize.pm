package iTools::Serialize;
use base Exporter;

use Storable qw( freeze thaw );
use UNIVERSAL qw( can );
use iTools::File qw( readfile writefile );

@EXPORT = qw( serialize unserialize );

use strict;
use warnings;

# === Constructor ===========================================================
# --- empty constructor for convenience ---
sub new { return bless {}, ref($_[0]) || $_[0] }

# === Serialization =========================================================
sub serialize {
	my ($obj, $file) = @_;
	my $ice = freeze(
		can($obj, 'serial') ? $obj->serial : $obj
	);
	writefile($file, $ice) if defined $file;
	return $ice;
}
sub unserialize {
	shift if can($_[0], 'unserialize'); # turf the obj if necessary
	my $file = shift;                   # get the filename
	return undef unless defined $file;  # file name required
	return undef unless -e $file;       # file must exist
	return thaw(readfile($file));       # thaw and return
}

# === Extendable Methods ====================================================
sub serial { $_[0] }

1;

=head1 NAME

iTools::Serialize - extension for object serialization

=head1 SYNOPSIS

  As an Export:
    use iTools::Serialize;
    serialize($object, 'filename');
    $object = unserialize('filename');

  As an Object:
    # The Object:
    package Test::Class;
    use base iTools::Serialize;
    sub serial { return $data };

    # The Script:
    $object = new Test::Class;
    $object->serialize('filename');
    $object2 = $object->unserialize('filename');

=head1 DESCRIPTION

B<iTools::Serialize> is both a base class and function exporter for data serialization and storage.

=head1 EXPORTS AND METHODS

=over 4

=item $obj->B<serialize>([FILE]) or B<serialize>(DATA [, FILE])

This method/function, B<freeze>s the given B<obj>ect or B<DATA> and writes it to B<FILE>.
If used as a method, B<serialize>() will call the B<serial>() method and B<freeze> the data it returns.

If no B<FILE> is given, no B<FILE> will be written.
Returns the frozen data or B<undef> on failure.

=item $obj->B<unserialize>(FILE) or B<unserialize>(FILE)

Retrieves the contents of B<FILE> and returns the B<thaw>ed data.
Returns B<undef> on failure.

=item $obj->B<serial>()

This is an overridable method that is called by the B<serialize>() method to fetch the data to be B<serialize>d.
This method exists in case you want to pre-process the data to be B<serialize>d.
See B<EXAMPLES> below.

All the base B<serial>() method does is return B<self>, likea sooo:

  sub serial { $_[0] }

So don't bother to extend this method, just override it.

=back

=head1 EXAMPLES

=head2 Overriding The serial() Method

There are cases where you may not want to B<serialize> the object in its current state.
For example, if you are storing temporary data in the object, you may want to delete it before serialization:

  sub serial {
    my $self = shift;
    delete $self->{_tmp};
    return $self;
  }

Of course, the above example won't work if you still need the temporary data in the current instance, so making a copy of the object may be preferable:

  use Storable qw( dclone );
  sub serial {
    my $self = dclone(shift);
    delete $self->{_tmp};
    return $self;
  }

See L<Storable>(3pm) for details on data cloning (dclone).

=head1 TODO

=head2 B<Unserialize from String>

=head2 B<File Locking>

=head2 B<URL Option>

=head2 B<ORB Plugin>

=head1 KNOWN ISSUES AND BUGS

None.

=head1 REPORTING BUGS

Report bugs in the Bug Tracker at Puma's SourceForge project page:
L<http://sourceforge.net/projects/puma/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the Puma distribution.

=head1 DEPENDENCIES

Exporter(3pm), Storable(3pm), UNIVERSAL(3pm), strict(3pm) and warnings(3pm) (stock Perl);
iTools::File(3pm)

=head1 SEE ALSO

Storable(3pm)

=cut
