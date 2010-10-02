package Exporter::Declare::Meta;
use strict;
use warnings;

use Scalar::Util qw/blessed reftype/;
use Carp qw/croak/;
use aliased 'Exporter::Declare::Export::Sub';
use aliased 'Exporter::Declare::Export::Variable';
use aliased 'Exporter::Declare::Export::Alias';

sub new {
    my $class = shift;
    my ( $package, %options ) = @_;

    my $self = bless([
        $package,
        {}, #exports
        { default => [], all => [] }, #tags
        {}, #parsers
        { prefix => 1, suffix => 1 }, #options
    ], $class);

    {
        no strict 'refs';
        *{$self->package . '::export_meta'} = sub { $self };
    }

    $self->add_alias unless $options{noalias};

    return $self;
}

sub new_from_exporter {
    my $class = shift;
    my ( $exporter ) = @_;
    my $self = $class->new( $exporter );
    my %seen;
    my ($exports) = $self->get_ref_from_package('@EXPORT');
    my ($export_oks) = $self->get_ref_from_package('@EXPORT_OK');
    my ($tags) = $self->get_ref_from_package('%EXPORT_TAGS');
    $self->add_export( @$_ ) for map {
        my ( $ref, $name ) = $self->get_ref_from_package( $_ );
        if ( $name =~ m/^\&/ ) {
            Sub->new( $ref, exported_by => $exporter );
        }
        else {
            Variable->new( $ref, exported_by => $exporter );
        }
        [ $name, $ref ];
    } grep { !$seen{$_}++ } @$exports, @$export_oks;
    $self->push_tag( 'default', @$exports );
    $self->push_tag( $_, $tags->{$_} ) for keys %$tags;
    return $self;
}

sub package      { shift->[0] }
sub _exports     { shift->[1] }
sub _export_tags { shift->[2] }
sub _parsers     { shift->[3] }
sub _options     { shift->[4] }

sub add_alias {
    my $self = shift;
    my $package = $self->package;
    my ( $alias ) = ( $package =~ m/([^:]+)$/ );
    $self->add_export( $alias, Alias->new( sub { $package }, exported_by => $package ));
    $self->push_tag( 'alias', $alias );
}

sub add_export {
    my $self = shift;
    my ( $item, $ref ) = @_;
    my ( $type, $name ) = ( $item =~ m/^([\&\%\@\$])?(.*)$/ );
    $type ||= '&';
    my $fullname = "$type$name";

    croak "Exports must be instances of 'Exporter::Declare::Export'"
        unless blessed( $ref ) && $ref->isa('Exporter::Declare::Export');

    croak "Already exporting '$fullname'"
        if $self->_exports->{$fullname};

    $self->_exports->{$fullname} = $ref;
    push @{ $self->_export_tags->{all}} => $fullname;
}

sub get_export {
    my $self = shift;
    my ( $item ) = @_;

    croak "get_export() does not accept a tag as an argument"
        if $item =~ m/^[:-]/;

    my ( $type, $name ) = ( $item =~ m/^([\&\%\@\$])?(.*)$/ );
    $type ||= '&';
    my $fullname = "$type$name";

    return $self->_exports->{$fullname}
        || croak $self->package . " does not export '$fullname'"
}

sub push_tag {
    my $self = shift;
    my ( $name, @list ) = @_;
    croak "'$name' is a reserved tag, you cannot override it."
        if $name eq 'all';
    croak "'$name' is already an option, you can't also make it a tag."
        if $self->is_option($name);
    push @{$self->_export_tags->{$name}} => @list;
}

sub is_tag {
    my $self = shift;
    my ( $name ) = @_;
    $self->_export_tags->{$name} ? 1 : 0;
}

sub get_tag {
    my $self = shift;
    my ( $name ) = @_;
    @{ $self->_export_tags->{$name} || []}
}

sub add_options {
    my $self = shift;
    for my $name ( @_ ) {
        croak "'$name' is already an export tag and can't be used as an option."
            if $self->is_tag($name);
        $self->_options->{$name} = 0;
    }
}

sub add_arguments {
    my $self = shift;
    for my $name ( @_ ) {
        croak "'$name' is already an export tag and can't be used as an option."
            if $self->is_tag($name);
        $self->_options->{$name} = 1;
    }
}

sub is_option {
    my $self = shift;
    my ( $option ) = @_;
    return defined $self->_options->{$option}
               && !$self->_options->{$option};
}

sub is_argument {
    my $self = shift;
    my ( $option ) = @_;
    return $self->_options->{$option};
}

sub add_parser {
    my $self = shift;
    my ( $name, $code ) = @_;
    $self->_parsers->{ $name } = $code;
}

sub get_parser {
    my $self = shift;
    my ( $name ) = @_;
    return $self->_parsers->{ $name };
}

sub get_ref_from_package {
    my $self = shift;
    my ( $item ) = @_;
    use Carp qw/confess/;
    confess unless $item;
    my ( $type, $name ) = ($item =~ m/^([\&\@\%\$]?)(.*)$/);
    $type ||= '&';
    my $fullname = "$type$name";
    my $ref = $self->package . '::' . $name;

    no strict 'refs';
    return( \&{ $ref }, $fullname ) if !$type || $type eq '&';
    return( \${ $ref }, $fullname ) if $type eq '$';
    return( \@{ $ref }, $fullname ) if $type eq '@';
    return( \%{ $ref }, $fullname ) if $type eq '%';
    croak "'$item' cannot be exported"
}

sub reexport {
    my $self = shift;
    my ( $exporter ) = @_;
    my $meta = $exporter->can( 'export_meta' )
        ? $exporter->export_meta()
        : __PACKAGE__->new_from_exporter( $exporter );
    $self->merge( $meta );
}

sub merge {
    my $self = shift;
    my ( $meta ) = @_;
    $self->add_export( $_, $meta->_exports->{ $_ })
        for grep { !$meta->_exports->{$_}->isa(Alias) } keys %{ $meta->_exports };

    $self->push_tag( $_, @{ $meta->_export_tags->{ $_ }} )
        for grep { $_ !~ m/^(all|alias)$/ } keys %{ $meta->_export_tags };

    $self->add_parser( $_, $meta->get_parser( $_ ))
        for keys %{ $meta->_parsers };
}

1;

=head1 NAME

Exporter::Declare::Meta - The mata object which stoes meta-data for all
exporters.

=head1 DESCRIPTION

All classes that use Exporter::Declare have an associated Meta object. Meta
objects track available exports, tags, and options.

=head1 METHODS

=over 4

=item $class->new( $package )

Created a meta object for the specified package. Also injects the export_meta()
sub into the package namespace that returns the generated meta object.

=item $class->new_from_exporter( $package )

Create a meta object for a package that already uses Exporter.pm. This will not
turn the class into an Exporter::Declare package, but it will create a meta
object and export_meta() method on it. This si primarily used for reexport
purposes.

=item $package = $meta->package()

Get the name of the package with which the meta object is associated.

=item $meta->add_alias()

Usually called at construction to add a package alias function to the exports.

=item $meta->add_export( $name, $ref )

Add an export, name should be the item name with sigil (assumed to be sub if
there is no sigil). $ref should be a ref blessed as an
L<Exporter::Declare::Export> subclass.

=item $meta->get_export( $name )

Retrieve the L<Exporter::Declare::Export> object by name. Name should be the
item name with sigil, assumed to be sub when sigil is missing.

=item $meta->push_tag( $name, @items )

Add @items to the specified tag. Tag will be created if it does not already
exist. $name should be the tag name B<WITHOUT> -/: prefix.

=item $bool = $meta->is_tag( $name )

Check if a tag with the given name exists.  $name should be the tag name
B<WITHOUT> -/: prefix.

=item @list = $meta->get_tag( $name )

Get the list of items associated with the specified tag.  $name should be the
tag name B<WITHOUT> -/: prefix.

=item $meta->add_options( @names )

Add import options by name. These will be boolean options that take no
arguments.

=item $meta->add_arguments( @names )

Add import options that slurp in the next argument as a value.

=item $bool = $meta->is_option( $name )

Check if the specifed name is an option.

=item $bool = $meta->is_argument( $name )

Check if the specifed name is an option that takes an argument.

=item $meta->add_parser( $name, sub { ... })

Add a parser sub that should be associated with exports via L<Devel::Declare>

=item $meta->get_parser( $name )

Get a parser by name.

=item $ref = $meta->get_ref_from_package( $item )

Returns a reference to a specific package variable or sub.

=item $meta->reexport( $package )

Re-export the exports in the provided package. Package may be an
L<Exporter::Declare> based package or an L<Exporter> based package.

=item $meta->merge( $meta2 )

Merge-in the exports and tags of the second meta object.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
