package Exporter::Declare::Export::Sub;
use strict;
use warnings;

use base 'Exporter::Declare::Export';

sub inject {
    my $self = shift;
    my ($class, $name) = @_;

    $self->SUPER::inject( $class, $name );

    return unless $self->parser;

    my $parser_sub = $self->exported_by->export_meta->get_parser( $self->parser );
    if ( my $parser_sub ) {
        require Devel::Declare;
        Devel::Declare->setup_for(
            $class,
            { method => { const => $parser_sub } }
        );
    }
    else {
        require Devel::Declare::Interface;
        Devel::Declare::Interface::enhance(
            $class,
            $name,
            $self->parser,
        );
    }
}

sub parser {
    my $self = shift;
    return $self->_data->{parser};
}

1;
