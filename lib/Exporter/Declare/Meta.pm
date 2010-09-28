package Exporter::Declare::Meta;
use strict;
use warnings;

use Scalar::Util qw/blessed reftype/;
use Carp qw/croak/;

sub new {
    my $class = shift;
    my ( $package ) = @_;
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

    return $self;
}

sub package      { shift->[0] }
sub _exports     { shift->[1] }
sub _export_tags { shift->[2] }
sub _parsers     { shift->[3] }
sub _options     { shift->[4] }

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
    @{ $self->_export_tags->{$name}}
}

sub add_options {
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

1;
