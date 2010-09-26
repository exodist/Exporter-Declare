package Exporter::Declare;
use strict;
use warnings;

use Carp qw/croak/;
use Exporter::Declare::Parser;
use Devel::Declare::Parser::Sublike;
use Exporter::Declare::Meta;
use Exporter::Declare::Specs;
use Exporter::Declare::Export::Sub;
use Exporter::Declare::Export::Variable;
use Exporter::Declare::Export::Generator;

BEGIN { Exporter::Declare::Meta->new( __PACKAGE__ )}

our $VERSION = '0.100';
our @EXPORT = qw/ export_to import/;
our @EXPORT_OK = qw/ reexport /;
export( $_, 'export' ) for qw/ export export_ok gen_export gen_export_ok /;
export( 'parser', 'sublike' );

sub _import { 1 }

sub import {
    my $class = shift;
    my $caller = caller;
    my $specs = Exporter::Declare::Specs->new( $class, @_ )->export( $caller );

    $class->_import( $caller, $specs );

    return unless $class->export_meta->create_meta;
    Exporter::Declare::Meta->new( $caller, $specs->flags->{extend} );
}

sub reexport {
    my $caller = caller;
    my $meta = $caller->meta;
    $meta->merge( $_ ) for map { $_->export_meta } @_;
}

sub _export {
    my ( $caller, $add_method, $name, @param ) = @_;
    my $ref = ref($param[-1]) ? pop(@param) : undef;
    my ( $parser ) = @param;

    my $meta = $caller->export_meta;

    ( $ref, $name ) = $meta->get_ref_from_package( $name )
        unless $ref;

    my $expclass = reftype( $ref ) eq 'CODE'
        ? 'Exporter::Declare::Export::Sub'
        : 'Exporter::Declare::Export::Variable';

    $expclass->new(
        $ref,
        exported_by => $self->package,
        $parser ? ( parser => $parser ) : (),
    );

    $meta->$add_method( $name, $ref );
}

sub export {
    my $caller = caller;
    _export( $caller, 'add_export', @_ );
}

sub export_ok {
    my $caller = caller;
    _export( $caller, 'add_export_ok', @_ );
}

sub _gen_export {
    my ( $caller, $add_method, $name, @param ) = @_;
    my $ref = ref($param[-1]) eq 'CODE' ? pop(@param) : undef;
    my ( $parser ) = @param;
    croak "You must provide a generator sub"
        unless $ref;

    ( my $type, $name ) = ($name =~ m/^([\$\@\&\%]?)(.*)$/);
    $type = undef if $type eq '&';

    my $meta = $caller->export_meta;

    my $expclass = reftype( $ref ) eq 'CODE'
        ? 'Exporter::Declare::Export::Generator'
        : croak "Export generators must be coderefs";

    $expclass->new(
        $ref,
        exported_by => $self->package,

        $parser ? ( parser => $parser    )
                : (                      ),

        $type   ? ( type   => 'variable' )
                : ( type   => 'sub'      ),
    );

    $meta->$add_method( $name, $ref );
}

sub gen_export {
    my $caller = caller;
    _gen_export( $caller, 'add_export', @_ );
}

sub gen_export_ok {
    my $caller = caller;
    _gen_export( $caller, 'add_export_ok', @_ );
}

sub export_to {
    my $class = shift;
    my ( $dest, @args ) = @_;
    Exporter::Declare::Specs->new( $class, @args )->export( $dest );
}

sub parser {
    my $caller = caller;
    my ( $name, $code ) = @_;
    croak "You must provide a name to parser()"
        if !$name || ref $name;
    $code ||= $caller->can( $name );
    croak "Could not find code for parser '$name'"
        unless $code;

    $caller->export_meta->parsers{ $name } = $code;
}

1;
