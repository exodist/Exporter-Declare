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

default_export 'export', 'export';
default_export 'import';

export 'parser', 'sublike';
parsed_exports 'export', qw/gen_export default_export gen_default_export/;
exports qw/
    default_exports exports parsed_exports parsed_default_exports reexport
    import export_to
/;

sub import {
    my $class = shift;
    my $caller = caller;
    my $specs = export_to( $class, $caller, @_ );
    $class->_import( $caller, $specs )
        if $class->can( '_import' );
}

sub _import {
    my ( $caller, $specs ) = @_;
    Exporter::Declare::Meta->new( $caller );
}

sub make_exporter {
    my $class = shift;
    my ( $package, @args ) = @_;
    my $specs = $class->export_to( $package, @args );
    Exporter::Declare::Meta->new( $caller );
}

sub export_to {
    my ( $class, $dest, @args ) = @_;
    my $specs = Exporter::Declare::Specs->new( $class, @args );
    $specs->export( $dest );
    return $specs;
}

sub exports {
    my $caller = caller;
    my $meta = $caller->export_meta
    _export( $caller, $_ ) for @_;
    $meta->get_tag('all');
}

sub default_exports {
    my $caller = caller;
    my $meta = $caller->export_meta
    $meta->push_tag( 'default', _export( $caller, undef, $_ ))
        for my @_;
    $meta->get_tag('default');
}

sub parsed_exports {

}

sub parsed_default_exports {

}

sub export {
    my $caller = caller;
    _export( $caller, undef, @_ );
}

sub gen_export {
    my $caller = caller;
    _export( $caller, 'Exporter::Declare::Export::Generator', @_ );
}

sub default_export {
    my $caller = caller;
    $meta->push_tag( 'default', _export( $caller, undef, @_ ))
}

sub gen_default_export {
    my $caller = caller;
    $meta->push_tag(
        'default',
        _export(
            $caller,
            'Exporter::Declare::Export::Generator',
            @_,
        )
    )
}

sub reexport {
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

sub _export {
    my ( $caller, $expclass, $name, @param ) = @_;
    my $ref = ref($param[-1]) ? pop(@param) : undef;
    my ( $parser ) = @param;
    my $meta = $caller->export_meta;

    ( $ref, $name ) = $meta->get_ref_from_package( $name )
        unless $ref;

    ( my $type, $name ) = ($name =~ m/^([\$\@\&\%]?)(.*)$/);
    $type = undef if $type eq '&';

    my $fullname = "$type$name";

    $expclass ||= reftype( $ref ) eq 'CODE'
        ? 'Exporter::Declare::Export::Sub'
        : 'Exporter::Declare::Export::Variable';

    $expclass->new(
        $ref,
        exported_by => $self->package,
        ($parser ? ( parser => $parser    )
                 : (                      )),
        ($type   ? ( type   => 'variable' )
                 : ( type   => 'sub'      )),
    );

    $meta->add_export( $fullname, $ref );

    return $fullname;
}

1;
