package Exporter::Declare::Meta;
use strict;
use warnings;

use Scalar::Util qw/blessed reftype/;
use Carp qw/croak/;
use aliased 'Exporter::Declare::Export::Sub';

sub new {
    my $class = shift;
    my ( $package ) = @_;
    my ( $alias ) = ( $package =~ m/([^:]+)$/ );
    my $self = bless([
        $package,
        {}, #exports
        { default => [], all => [], alias => [ $alias ] }, #tags
        {}, #parsers
        { prefix => 1, suffix => 1 }, #options
    ], $class);

    {
        no strict 'refs';
        *{$self->package . '::export_meta'} = sub { $self };
    }

    $self->add_export( $alias, Sub->new( sub { $package }, exported_by => $package ));

    return $self;
}

sub new_from_exporter {
    my $class = shift;
    my ( $exporter ) = @_;
    my $self = $class->new( $exporter );
    my %seen;
    my $exports = $self->get_ref_from_package('@EXPORT');
    my $export_oks = $self->get_ref_from_package('@EXPORT_OK');
    my $tags = $self->get_ref_from_package('%EXPORT_TAGS');
    $self->add_export( $_ ) for grep { !$seen{$_}++ } @$exports, @$export_oks;
    $self->push_tag( 'default', @$export_oks );
    $self->push_tag( $_, $tags->{$_} ) for keys %$tags;
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
    my $meta = ( @_ );
    $self->add_export( $_, $meta->_exports->{ $_ })
        for keys %{ $meta->_exports };

    $self->push_tags( $_, @{ $meta->_export_tags->{ $_ }} )
        for grep { $_ ne 'all' } keys %{ $meta->_export_tags };
}

1;
