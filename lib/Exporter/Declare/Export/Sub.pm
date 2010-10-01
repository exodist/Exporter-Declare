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

    if ( $parser_sub ) {
        require Devel::Declare;
        Devel::Declare->setup_for(
            $class,
            { $name => { const => $parser_sub } }
        );
    }
    else {
        require Devel::Declare::Interface;
        require Exporter::Declare::Parser;
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

=head1 NAME

Exporter::Declare::Export::Sub - Export class for subs which are exported.

=head1 DESCRIPTION

Export class for subs which are exported. Overrides inject() in order to hook
into L<Devel::Declare> on parsed exports.

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
