package Exporter::Declare::Export::Generator;
use strict;
use warnings;

use base 'Exporter::Declare::Export::Sub';
use Exporter::Declare::Export::Variable;

sub type { shift->_data->{ type }}

sub generate {
    my $self = shift;
    my ( $import_class, @args ) = @_;
    my $ref = $self->( $iself->export_class, $import_class, @args );

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
