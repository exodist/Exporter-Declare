package Exporter::Declare;
use strict;
use warnings;

use Carp qw/croak/;
use Exporter::Declare::Parser;
use Devel::Declare::Parser::Sublike;
use Scalar::Util qw/reftype/;
use aliased 'Exporter::Declare::Meta';
use aliased 'Exporter::Declare::Specs';
use aliased 'Exporter::Declare::Export::Sub';
use aliased 'Exporter::Declare::Export::Variable';
use aliased 'Exporter::Declare::Export::Generator';

BEGIN { Meta->new( __PACKAGE__ )}

our $VERSION = '0.100';

parsed_default_exports( export => qw/
    export
    gen_export
    default_export
    gen_default_export
/);

default_exports( qw/
    import
    export_to
    exports
    default_exports
    options
/);

exports( qw/
    parsed_exports
    parsed_default_exports
    reexport
    parser
/);

sub import {
    my $class = shift;
    my $caller = caller;
    my $specs = export_to( $class, $caller, @_ );
    $class->_import( $caller, $specs )
        if $class->can( '_import' );
}

sub _import {
    my $class = shift;
    my ( $caller, $specs ) = @_;
    Meta->new( $caller );
}

sub make_exporter {
    my $class = shift;
    my ( $package, @args ) = @_;
    my $specs = $class->export_to( $package, @args );
    Meta->new( $package );
}

sub export_to {
    my $class = _find_export_class( \@_ );
    my ( $dest, @args ) = @_;
    my $specs = Specs->new( $class, @args );
    $specs->export( $dest );
    return $specs;
}

sub exports {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    _export( $class, undef, $_ ) for @_;
    $meta->get_tag('all');
}

sub default_exports {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->push_tag( 'default', _export( $class, undef, $_ ))
        for @_;
    $meta->get_tag('default');
}

sub parsed_exports {
    my $class = _find_export_class( \@_ );
    my ( $parser, @items ) = @_;
    croak "no parser specified" unless $parser;
    export( $class, $_, $parser ) for @items;
}

sub parsed_default_exports {
    my $class = _find_export_class( \@_ );
    my ( $parser, @names ) = @_;
    default_export( $class, $_, $parser ) for @names;
}

sub export {
    my $class = _find_export_class( \@_ );
    _export( $class, undef, @_ );
}

sub gen_export {
    my $class = _find_export_class( \@_ );
    _export( $class, Generator(), @_ );
}

sub default_export {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->push_tag( 'default', _export( $class, undef, @_ ));
}

sub gen_default_export {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->push_tag( 'default', _export( $class, Generator(), @_ ));
}

sub reexport {
    my $class = _find_export_class( \@_ );
    $class->export_meta->reexport( @_ );
}

sub parser {
    my $class = _find_export_class( \@_ );
    my ( $name, $code ) = @_;
    croak "You must provide a name to parser()"
        if !$name || ref $name;
    $code ||= $class->can( $name );
    croak "Could not find code for parser '$name'"
        unless $code;

    $class->export_meta->parsers->{ $name } = $code;
}

sub options {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->add_options(@_);
}

sub arguments {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->add_arguments(@_);
}

sub _export {
    my ( $class, $expclass, $name, @param ) = @_;
    my $ref = ref($param[-1]) ? pop(@param) : undef;
    my ( $parser ) = @param;
    my $meta = $class->export_meta;

    ( $ref, $name ) = $meta->get_ref_from_package( $name )
        unless $ref;

    ( my $type, $name ) = ($name =~ m/^([\$\@\&\%]?)(.*)$/);
    $type = "" if $type eq '&';

    my $fullname = "$type$name";

    $expclass ||= reftype( $ref ) eq 'CODE'
        ? Sub()
        : Variable();

    $expclass->new(
        $ref,
        exported_by => $class,
        ($parser ? ( parser => $parser    )
                 : (                      )),
        ($type   ? ( type   => 'variable' )
                 : ( type   => 'sub'      )),
    );

    $meta->add_export( $fullname, $ref );

    return $fullname;
}

sub _find_export_class {
    my $args = shift;

    return shift( @$args )
        if @$args
        && eval { $args->[0]->can('export_meta') };

    return caller(1);
}

1;
