package Exporter::Declare::Specs;
use strict;
use warnings;

use Carp qw/croak/;

sub package  { shift->[0] }
sub config   { shift->[1] }
sub exports  { shift->[2] }
sub excludes { shift->[3] }

sub new {
    my $class = shift;
    my ( $package, @args ) = @_;
    my $self = bless( [$package,{},{},[]], $class );
    @args = (':default') unless @args;
    $self->process( "import list", @args );
    return $self;
}

sub process {
    my $self = shift;
    my ( $tag, @args ) = @_;
    my $argnum = 0;
    while ( my $item = shift( @args )) {
        croak "not sure what to do with $item ($tag argument: $argnum)"
            if ref $item;

        if ( $item =~ m/^(!?)[:-](.*)$/ ) {
            my ( $neg, $tag ) = ( $1, $2 );
            if ( $self->package->export_meta->paramed_tags->{ $tag }) {
                $self->config->{$tag} = shift( @args );
                $argnum++;
            }
            else {
                $self->config->{$tag} = !$neg;
            }
        }

        if ( $item =~ m/^!(.*)$/ ) {
            $self->_exclude_item( $item )
        }
        elsif ( my $type = ref( $args[0] )) {
            my $arg = shift( @args );
            $argnum++;
            if ( $type eq 'ARRAY' ) {
                $self->_include_item_and_args( $item, $arg )
            }
            elsif ( $type eq 'HASH' ) {
                $self->_include_item_and_conf( $item, $arg )
            }
            else {
                croak "Not sure what to do with $item => $arg ($tag arguments: "
                . ($argnum - 1) . " and $argnum)";
            }
        }
        else {
            $self->_include_item( $item )
        }
        $argnum++;
    }
    delete $self->exports->{$_} for @{ $self->excludes };
}

sub _item_name { my $in = shift; $in =~ m/^[\&\$\%\@]/ ? $in : "\&in" }

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

    if ( $item =~ m/^[:-](.*)$/ ) {
        $self->_include_item( $_, $conf, $args )
            for $self->_get_tag( $1 );
        return;
    }

    $item = _item_name($item);

    my $existing = $self->exports->{ $item };
    return $self->exports->{ $item } = [
        $self->_get_item( $item ),
        $conf,
        $args,
    ] unless $existing;

    $existing->[1] = { %{$existing->[1]}, %$conf };
    push @{ $existing->[2] } => @$args;
}

sub _get_item {
    my $self = shift;
    my ( $name ) = @_;
    $self->package->export_meta->get_exports( $name );
}

sub _get_tag {
    my $self = shift;
    my ( $name ) = @_;
    $self->package->export_meta->get_tag( $name );
}

sub _include_item_and_args {
    my $self = shift;
    my ( $item, $args ) = @_;
    $self->_include_item( $item, undef, $args );
}

sub _include_item_and_conf {
    my $self = shift;
    my ( $item, $inconf ) = @_;
    my ( %conf, @args );

    push @args => @{ delete $inconf{'-args'} }
        if defined $inconf{'-args'};

    for my $key ( keys %$inconf ) {
        my $val = $inconf->{$key};
        if ( $key =~ m/^[:-](.*)$/ ) {
            $conf{$1} = $val
        }
        else {
            push @args => ( $key, $val );
        }
    }

    $self->_include_item(
        $item,
        (keys %conf ? \%conf : undef),
        (@args ? \@args : ()),
    );
}

sub export {

}

1;
