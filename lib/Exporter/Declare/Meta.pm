package Exporter::Declare::Meta;
use strict;
use warnings;

use Scalar::Util qw/blessed reftype/;
use Carp qw/croak/;

sub new {
    my $class = shift;
    my ( $package, %params ) = @_;
    my $self = bless([
        $package,
        {}, #exports
        { default => [], all => [] }, #tags
        {}, #parsers
    ], $class);

    $self->_establish_link unless $params{no_link};

    return $self;
}

sub package     { shift->[0] }
sub exports     { shift->[1] }
sub export_tags { shift->[2] }
sub parsers     { shift->[3] }

sub _establish_link {
    my $self = shift;
    *{$self->package . '::EXPORT_TAGS'} = $self->export_tags;
}

sub add_export {
    my $self = shift;
    my ( $item, $ref ) = @_;
    my ( $type, $name ) = ( $item =~ m/^([\&\%\@\$])(.*)$/ );
    $type ||= '&';
    my $fullname = "$type$name";

    croak "Exports must be instances of 'Exporter::Declare::Export'"
        unless blessed( $ref ) && $ref->isa('Exporter::Declare::Export');

    croak "Already exporting '$fullname'"
        if $self->exports->{$fullname};

    $self->exports->{$fullname} = $ref;
    push @{ $self->export_tags->{all}} => $fullname;
}

sub get_export {
    my $self = shift;
    my ( $item ) = @_;

    croak "get_export() does not accept a tag as an argument"
        if $item =~ m/^[:-]/;

    my ( $type, $name ) = ( $item =~ m/^([\&\%\@\$])(.*)$/ );
    $type ||= '&';
    my $fullname = "$type$name";

    return $self->exports->{$fullname}
        || croak $self->package . " does not export '$fullname'"
}

sub push_tag {
    my $self = shift;
    my ( $name, @list ) = @_;
    croak "'$name' is a reserved tag, you cannot override it."
        if $name =~ m/^(all|prefix|suffix)$/i;
    push @{$self->export_tags->{$name}} => @list;
}

sub get_tag {
    my $self = shift;
    my ( $name ) = @_;
    @{ $self->export_tags->{$name}}
}

sub get_tag_ref {
    my $self = shift;
    my ( $name ) = @_;
    $self->export_tags->{$name}
}

sub get_ref_from_package {
    my $self = shift;
    my ( $item ) = @_;
    my ( $type, $name ) = ($item =~ m/^([\&\@\%\$]?)(.*)$/);
    my $ref = $self->package . '::' . $name;

    no strict 'refs';
    return( \&{ $ref }, $name ) if !$type || $type eq '&';
    return( \${ $ref }, $name ) if $type eq '$';
    return( \@{ $ref }, $name ) if $type eq '@';
    return( \%{ $ref }, $name ) if $type eq '%';
    croak "'$item' cannot be exported"
}

1;
