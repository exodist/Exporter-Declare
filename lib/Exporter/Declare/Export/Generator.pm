package Exporter::Declare::Export::Generator;
use strict;
use warnings;

use base 'Exporter::Declare::Export::Sub';
use Exporter::Declare::Export::Variable;
use Carp qw/croak/;

sub required_specs {
    my $self = shift;
    return(
        $self->SUPER::required_specs(),
        qw/ type /,
    );
}

sub type { shift->_data->{ type }}

sub new {
    my $class = shift;
    croak "Generators must be coderefs, not " . ref($_[0])
        unless ref( $_[0] ) eq 'CODE';
    $class->SUPER::new( @_ );
}

sub generate {
    my $self = shift;
    my ( $import_class, @args ) = @_;
    my $ref = $self->( $self->exported_by, $import_class, @args );

    return Exporter::Declare::Export::Sub->new(
        $ref,
        %{ $self->_data },
    ) if $self->type eq 'sub';

    return Exporter::Declare::Export::Variable->new(
        $ref,
        %{ $self->_data },
    );
}

sub inject {
    my $self = shift;
    my ( $class, $name, @args ) = @_;
    $self->generate( $class, @args )->inject( $class, $name );
}

1;
