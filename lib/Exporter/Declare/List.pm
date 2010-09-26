package Exporter::Declare::List;
use strict;
use warnings;

use Carp qw/croak confess/;
use base 'Tie::Array';
use Scalar::Util qw/reftype/;
use Exporter::Declare::Export::Variable;
use Exporter::Declare::Export::Sub;

sub TIEARRAY {
    my $class = shift;
    my ( $package, $list, @items ) = @_;
    my $self = bless( [$package, $list], $class );
    $self->PUSH( @items );
    return $self;
}

sub package { shift->[0] }
sub list    { shift->[1] }

sub FETCHSIZE { scalar @{ shift->list }}

sub FETCH { $_[0]->list->[ $_[1] ]}

sub STORESIZE {
    my $self = shift;
    my ( $count ) = @_;
    return unless $count < $self->FETCHSIZE;
    croak "Cannot shrink this array";
}

sub STORE {
    my $self = shift;
    my ( $index, $value ) = @_;

    croak "Cannot change existing elements of this array"
        if $index < $self->FETCHSIZE;

    my ( $ref, $name ) = $self->package->export_meta->get_ref_from_package( $value );
    my $expclass = reftype( $ref ) eq 'CODE'
        ? 'Exporter::Declare::Export::Sub'
        : 'Exporter::Declare::Export::Variable';

    $expclass->new( $ref, exported_by => $self->package );

    $self->package->export_meta->add_export( $name, $ref );
    my $list = $self->list;
    push @$list => $name
        unless $list->[-1] =~ m/^\&?$name$/;
}

sub CLEAR  {                                           }
sub DELETE { croak "You cannot delete from this array" }
sub POP    { croak "You cannot pop from this array"    }
sub SHIFT  { croak "You cannot shift from this array"  }

1;
