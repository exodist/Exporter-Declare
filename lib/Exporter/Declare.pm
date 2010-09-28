package Exporter::Declare;
use strict;
use warnings;

use Carp qw/croak/;
use Exporter::Declare::Parser;
use Devel::Declare::Parser::Sublike;
use aliased 'Exporter::Declare::Meta';
use aliased 'Exporter::Declare::Specs';
use aliased 'Exporter::Declare::Export::Sub';
use aliased 'Exporter::Declare::Export::Variable';
use aliased 'Exporter::Declare::Export::Generator';

BEGIN { Meta->new( __PACKAGE__ )}

our $VERSION = '0.100';

default_export( 'export', 'export' );
default_export( 'import'           );

export( 'parser', 'sublike' );
parsed_exports( 'export', qw/gen_export default_export gen_default_export/ );
exports(qw/ default_exports exports parsed_exports parsed_default_exports
            reexport import export_to export_alias options /               );

sub import {
    my $class = shift;
    my $caller = caller;
    my $specs = export_to( $class, $caller, @_ );
    $class->_import( $caller, $specs )
        if $class->can( '_import' );
}

sub _import {
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
    _export( $class, $_ ) for @_;
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
    export( $class, $_, $parser );
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

sub export_alias {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    my $short = $class;
    $short =~ s/^.*::([^:]+)$/$1/;
    $meta->push_tag( 'default', _export( $class, Sub(), $short, sub { $class }));
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
    for my $opt ( @_ ) {
        $meta->options->{$opt} = 1;
    }
}

sub _export {
    my ( $class, $expclass, $name, @param ) = @_;
    my $ref = ref($param[-1]) ? pop(@param) : undef;
    my ( $parser ) = @param;
    my $meta = $class->export_meta;

    ( $ref, $name ) = $meta->get_ref_from_package( $name )
        unless $ref;

    ( my $type, $name ) = ($name =~ m/^([\$\@\&\%]?)(.*)$/);
    $type = undef if $type eq '&';

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
