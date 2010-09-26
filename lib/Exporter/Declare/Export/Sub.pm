package Exporter::Declare::Export::Sub;
use strict;
use warnings;

use B;

use base 'Exporter::Declare::Export';

sub inject {
    my $self = shift;
    my ($class, $name) = @_;

    $self->SUPER::inject( $class, $name );

    return unless $self->parser;

    my $parser_sub = $self->exported_by->export_meta->parsers->{ $self->parser };
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

sub start_line {
    my $self = shift;
    return B::svref_2object( $self )->START->line;
}

sub end_line {
    my $self = shift;
    return $self->_data->{end_line};
}

sub parser {
    my $self = shift;
    return $self->_data->{parser};
}

sub original_name {
    my $self = shift;
    return B::svref_2object( $self )->GV->NAME;
}

sub is_anon {
    my $self = shift;
    return $self->original_name eq '__ANON__' ? 1 : 0;
}

sub original_package {
    my $self = shift;
    return B::svref_2object( $self )->GV->STASH->NAME;
}

1;
