package Exporter::Declare;
use strict;
use warnings;

use Carp qw/croak/;
use Devel::Declare::Parser::Sublike;
use Scalar::Util qw/reftype/;
use aliased 'Exporter::Declare::Meta';
use aliased 'Exporter::Declare::Specs';
use aliased 'Exporter::Declare::Export::Sub';
use aliased 'Exporter::Declare::Export::Variable';
use aliased 'Exporter::Declare::Export::Generator';

BEGIN { Meta->new( __PACKAGE__ )}

our $VERSION = '0.100';

default_exports( qw/
    import
    exports
    default_exports
    import_options
    import_arguments
    export_tag
/);

exports( qw/
    parsed_exports
    parsed_default_exports
    reexport
    export_to
/);

parsed_exports( export => qw/
    export
    gen_export
    default_export
    gen_default_export
    parser
/);

export_tag( magic => qw/
    -default
    export
    gen_export
    default_export
    gen_default_export
    parser
    parsed_exports
    parsed_default_exports
/);

sub import {
    my $class = shift;
    my $caller = caller;
    my $specs = export_to( $class, $caller, @_ );
    $class->after_import( $caller, $specs )
        if $class->can( 'after_import' );
}

sub after_import {
    my $class = shift;
    my ( $caller, $specs ) = @_;
    Meta->new( $caller );
}

sub export_to {
    my $class = _find_export_class( \@_ );
    my ( $dest, @args ) = @_;
    my $specs = Specs->new( $class, @args );
    $specs->export( $dest );
    return $specs;
}

sub export_tag {
    my $class = _find_export_class( \@_ );
    my ( $tag, @list ) = @_;
    $class->export_meta->push_tag( $tag, @list );
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
    croak "no parser specified" unless $parser;
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

sub parser {
    my $class = _find_export_class( \@_ );
    my ( $name, $code, $bad ) = @_;
    croak "You must provide a name to parser()"
        if !$name || ref $name;
    croak "Too many parameters passed to parser()"
        if $bad;
    $code ||= $class->can( $name );
    croak "Could not find code for parser '$name'"
        unless $code;

    $class->export_meta->parsers->{ $name } = $code;
}

sub import_options {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->add_options(@_) if @_;
}

sub import_arguments {
    my $class = _find_export_class( \@_ );
    my $meta = $class->export_meta;
    $meta->add_arguments(@_) if @_;
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

sub reexport {
    my $class = _find_export_class( \@_ );
    $class->export_meta->reexport( $_ ) for @_;
}

1;

__END__

=head1 NAME

Exporter::Declare - Declarative exporting, better import interface.

=head1 DESCRIPTION

Exporting tools can be frustrating, L<Exporter> is showing its age.
L<Sub::Exporter> is a bit complicated for the module doing the exporting. Above
all else most export modules install their own import() function that can be a
pain to wrap or override without screwing something up.

Exporter declare solves these problems and more by providing the following:

=over 4

=item Declarative Exporting (Like L<Moose> for Exporting)

=item Meta Class Stores Per-Exporter Meta Data

=item Highly Customisable Import Process

=item Support for Export Lists (tags)

=item No Dependance on Package Variables

=item Export Generators

=item Higher Level Interface to L<Devel::Declare>

=item Clear and Concise OO API

=item All Exports are Blessed for Enhancement

=item Extended Import Syntax Based on L<Sub::Exporter>

=back

=head1 IMPORT INTERFACE

=head2 THE SPEC OBJECT

=head2 EXPORTS

=head2 TAGS

=head2 OPTIONS

=head2 ARGUMENTS

=head1 PRIMARY EXPORT API

=head1 EXTENDED EXPORT API

=head1 META CLASS

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
