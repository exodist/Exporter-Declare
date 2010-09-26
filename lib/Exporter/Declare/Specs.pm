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
    my $arg = 0;
    while ( my $item = shift( @args )) {
        croak "not sure what to do with $item ($tag argument: $arg)"
            if ref $item;

        # This is a legacy thing...
        if ( $item =~ m/^[-:](prefix|suffix)(?::(.*))?$/ ) {
            $self->config->{$1} = $2 || shift( @args );
            $arg++ if $2;
        }
        elsif ( $item =~ m/^!(.*)$/ ) {
            $self->_exclude_item( $item )
        }
        elsif ( my $type = ref( $args[0] )) {
            my $arg = shift( @args );
            $arg++;
            if ( $type eq 'ARRAY' ) {
                $self->_include_item_and_args( $item, $arg )
            }
            elsif ( $type eq 'HASH' ) {
                $self->_include_item_and_conf( $item, $arg )
            }
            else {
                croak "Not sure what to do with $item => $arg ($tag arguments: "
                . ($arg - 1) . " and $arg)";
            }
        }
        else {
            $self->_include_item( $item )
        }
        $arg++;
    }
}

sub _item_name { my $in = shift; $in =~ m/^[\&\$\%\@]/ ? $in : "\&in" }

sub _exclude_item {
    my $self = shift;
    my ( $item ) = @_;
    die "handle tags";
    $item = _item_name($item)
}

sub _include_item {
    my $self = shift;
    my ( $item, $conf, $args ) = @_;
    die "handle tags";
    $item = _item_name($item)
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

__END__

sub parse_import_args {
    my @list = @_;
    my ( @imports, %specs );

    $specs{_rename} = shift( @list )
        if ref $list[0] && ref $list[0] eq 'HASH';

    for( my $i = 0; $i < @list; $i++ ) {
        my $item = $list[$i];
        my $next = (($i + 1) == @list) ? $list[$i + 1] : undef;
        my ( $neg, $tag, $name ) = ( $item =~ m/^(!?)([:-]?)(.*)$/);
        if ( ref $next ) {
            $specs{_args}->{$item} = $next;

            $i++;
        }
        if ( $tag ) {
            my ( $prop, $value ) = ( $name =~ m/^(.*):(.*)$/ );
            $specs{$prop || $name} = $value || !$neg;
        }
        push @imports => $item;
    }

    my %seen;
    return( \%specs, grep { !$seen{$_}++ } @imports, keys %{ $specs{_rename} || {} });
}
