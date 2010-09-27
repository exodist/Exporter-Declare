package Exporter::Declare::Meta;
use strict;
use warnings;

use Scalar::Util qw/blessed reftype/;
use Carp qw/croak/;

our %TYPE_TO_IDX_MAP = (
    '&'    => 0,
    '$'    => 1,
    '@'    => 2,
    '%'    => 3,
);

sub package     { shift->[0]  }
sub exports     { shift->[1]  }
sub export_tags { shift->[2]  }
sub parsers     { shift->[3]  }

sub new {
    my $class = shift;
    my ( $package, $creates_meta ) = @_;
    my $self = bless([
        $package,
        {},
        {},
        { default => [], all => [] },
        {},
    ], $class);

    {
        no strict 'refs';
        *{"$package\::export_meta"} = sub { $self };
        *{"$package\::EXPORT_TAGS"} = $self->export_tags;
        tie(
            @{"$package\::EXPORT_OK"},
            'Exporter::Declare::List',
            $self->package,
            $self->export_tags->{all},
            @{"$package\::EXPORT_OK"},
        );
        tie(
            @{"$package\::EXPORT"},
            'Exporter::Declare::List',
            $self->package,
            $self->export_tags->{default},
            @{"$package\::EXPORT"},
        );
    }

    return $self;
}

sub add_export {
    my $self = shift;
    my ( $item, $ref ) = @_;
    my ( $type, $name ) = ( $item =~ m/^([\&\%\@\$])(.*)$/ );
    $type ||= '&';

    croak "Exports must be instances of 'Exporter::Declare::Export'"
        unless blessed( $ref ) && $ref->isa('Exporter::Declare::Export');

    my $idx = $TYPE_TO_IDX_MAP{$type};

    croak "Already exporting type '" . reftype($ref) . "' under name '$name'"
        if $self->exports->{$name}->[$idx];

    $self->exports->{$name}->[$idx] = $ref;
    push @{ $self->export_tags->{all}} => "$type$name";
}

sub get_exports {
    my $self = shift;
    my @names = @_;

    return map { grep { $_ } @$_ } values %{ $self->exports };
        unless @names;

    return map {
        my ( $type, $name ) = ( m/^([\$\@\%\&\-\:])?(.*)$/ );

        croak "get_exports() does not accept tags as arguments"
            if $type =~ m/^(:|-)$/;

        my $idx = $type ? $TYPE_TO_IDX_MAP{$type} : $TYPE_TO_IDX_MAP{CODE};
        my $ref = $set->{$name}->[$idx];

        croak $self->package . " does not export '$_'"
            unless $ref;

        $ref;
    } @names;
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
