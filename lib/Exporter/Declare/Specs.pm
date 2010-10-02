package Exporter::Declare::Specs;
use strict;
use warnings;

use Carp qw/croak/;

sub new {
    my $class = shift;
    my ( $package, @args ) = @_;
    my $self = bless( [$package,{},{},[]], $class );
    @args = (':default') unless @args;
    $self->_process( "import list", @args );
    return $self;
}

sub package  { shift->[0] }
sub config   { shift->[1] }
sub exports  { shift->[2] }
sub excludes { shift->[3] }

sub export {
    my $self = shift;
    my ( $dest ) = @_;
    for my $item ( keys %{ $self->exports }) {
        my ( $export, $conf, $args ) = @{ $self->exports->{$item} };
        my ( $sigil, $name ) = ( $item =~ m/^([\&\%\$\@])(.*)$/ );
        $name = $conf->{as} || join(
            '',
            $conf->{prefix} || $self->config->{prefix} || '',
            $name,
            $conf->{suffix} || $self->config->{suffix} || '',
        );
        $export->inject( $dest, $name, @$args );
    }
}

sub _process {
    my $self = shift;
    my ( $tag, @args ) = @_;
    my $argnum = 0;
    while ( my $item = shift( @args )) {
        croak "not sure what to do with $item ($tag argument: $argnum)"
            if ref $item;
        $argnum++;

        if ( $item =~ m/^(!?)[:-](.*)$/ ) {
            my ( $neg, $param ) = ( $1, $2 );
            if ( $self->package->export_meta->is_argument( $param )) {
                $self->config->{$param} = shift( @args );
                $argnum++;
                next;
            }
            else {
                $self->config->{$param} = ref( $args[0] ) ? $args[0] : !$neg;
            }
        }

        if ( $item =~ m/^!(.*)$/ ) {
            $self->_exclude_item( $1 )
        }
        elsif ( my $type = ref( $args[0] )) {
            my $arg = shift( @args );
            $argnum++;
            if ( $type eq 'ARRAY' ) {
                $self->_include_item( $item, undef, $arg );
            }
            elsif ( $type eq 'HASH' ) {
                $self->_include_item( $item, $arg, undef );
            }
            else {
                croak "Not sure what to do with $item => $arg ($tag arguments: "
                . ($argnum - 1) . " and $argnum)";
            }
        }
        else {
            $self->_include_item( $item )
        }
    }
    delete $self->exports->{$_} for @{ $self->excludes };
}

sub _item_name { my $in = shift; $in =~ m/^[\&\$\%\@]/ ? $in : "\&$in" }

sub _exclude_item {
    my $self = shift;
    my ( $item ) = @_;

    if ( $item =~ m/^[:-](.*)$/ ) {
        $self->_exclude_item( $_ )
            for $self->_get_tag( $1 );
        return;
    }

    push @{ $self->excludes } => _item_name($item);
}

sub _include_item {
    my $self = shift;
    my ( $item, $conf, $args ) = @_;
    $conf ||= {};
    $args ||= [];

    push @$args => @{ delete $conf->{'-args'} }
        if defined $conf->{'-args'};

    for my $key ( keys %$conf ) {
        next if $key =~ m/^[:-]/;
        push @$args => ( $key, delete $conf->{$key} );
    }

    if ( $item =~ m/^[:-](.*)$/ ) {
        $self->_include_item( $_, $conf, $args )
            for $self->_get_tag( $1 );
        return;
    }

    $item = _item_name($item);

    my $existing = $self->exports->{ $item };

    unless ( $existing ) {
        $existing = [ $self->_get_item( $item ), {}, []];
        $self->exports->{ $item } = $existing;
    }

    push @{ $existing->[2] } => @$args;
    for my $param (  keys %$conf ) {
        my ( $name ) = ( $param =~ m/^[-:](.*)$/ );
        $existing->[1]->{$name} = $conf->{$param};
    }
}

sub _get_item {
    my $self = shift;
    my ( $name ) = @_;
    $self->package->export_meta->get_export( $name );
}

sub _get_tag {
    my $self = shift;
    my ( $name ) = @_;
    $self->package->export_meta->get_tag( $name );
}

1;

=head1 NAME

Exporter::Declare::Specs - Import argument parser for Exporter::Declare

=head1 DESCRIPTION

Import arguments cna get complicated. All arguments are assumed to be exports
unless they have a - or : prefix. The prefix may denote a tag, a boolean
option, or an option that takes the next argument as a value. In addition
almost all these can be negated with the ! prefix.

This class takes care of parsing the import arguments and generating data
structures that can be used to find what the exporter needs to know.

=head1 METHODS

=over 4

=item $class->new( $package, @args )

Create a new instance and parse @args.

=item $specs->package()

Get the name of the package that should do the exporting.

=item $hashref = $specs->config()

Get the configuration hash, All specified options and tags are the keys. The
value will be true/false/undef for tags/boolean options. For options that take
arguments the value will be that argument. When a config hash is provided to a
tag it will be the value.

=item $hashref = $specs->exports()

Get the exports hash. The keys are names of the exports. Values are an array
containing the export, item specific config hash, and arguments array. This is
generally not intended for direct consumption.

=item $arrayref = $specs->excludes()

Get the arrayref containing the names of all excluded exports.

=item $specs->export( $package )

Do the actual exporting. All exports will be injected into $package.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2010 Chad Granum

Exporter-Declare is free software; Standard perl licence.

Exporter-Declare is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the license for more details.
