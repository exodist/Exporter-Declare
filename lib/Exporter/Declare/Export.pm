package Exporter::Declare::Export;
use strict;
use warnings;
use Carp qw/croak/;

our %OBJECT_DATA;

sub required_specs {qw/ exported_by /}

sub new {
    my $class = shift;
    my ( $item, %specs ) = @_;
    my $self = bless( $item, $class );

    for my $prop ( $self->required_specs ) {
        croak "You must specify $prop when calling $class\->new()\n"
            unless $specs{$prop};
    }

    $OBJECT_DATA{$self} = \%specs;

    return $self;
}

sub _data {
    my $self = shift;
    ($OBJECT_DATA{$self}) = @_ if @_;
    $OBJECT_DATA{$self};
}

sub exported_by {
    shift->_data->{ exported_by };
}

sub name {
    my $data = shift->_data;
    ($data->{ name }) = @_ if @_;
    $data->{ name };
}

sub inject {
    my $self = shift;
    my ($class, $name) = @_;
    $name ||= $self->name;
    croak "You must provide a class and name to inject()"
        unless $class && $name;
    no strict 'refs';
    no warnings 'once';
    *{"$class\::$name"} = $self;
}

sub DESTROY {
    my $self = shift;
    delete $OBJECT_DATA{$self};
}

1;
