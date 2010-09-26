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

sub package   { shift->[0]   }
sub list_name { shift->[1]   }
sub FETCHSIZE {
    my $self = shift;
    my ( $index ) = @_;
    my $list_name = $self->list_name() . "_list";
    return scalar $self->package->export_meta->$list_name;
}

sub FETCH {
    my $self = shift;
    my ( $index ) = @_;
    my $list_name = $self->list_name() . "_list";
    my @out = $self->package->export_meta->$list_name;
    return $out[$index];
}

sub STORESIZE {
    my $self = shift;
    my ( $count );
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

    my $list_name = "add_" . $self->list_name();
    $self->package->export_meta->$list_name( $name, $ref );
}

sub DELETE { croak "You cannot delete from this array" }
sub CLEAR  {                                           }
sub POP    { croak "You cannot pop from this array"    }
sub SHIFT  { croak "You cannot shift from this array"  }

1;
