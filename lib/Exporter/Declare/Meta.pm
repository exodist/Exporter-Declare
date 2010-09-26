package Exporter::Declare::Meta;
use strict;
use warnings;

use Scalar::Util qw/blessed reftype/;
use Carp qw/croak/;

our %TYPE_TO_IDX_MAP = (
    CODE   => 0,
    '&'    => 0,
    SCALAR => 1,
    '$'    => 1,
    ARRAY  => 2,
    '@'    => 2,
    HASH   => 3,
    '%'    => 3,
);
our %TYPE_TO_SIGIL = (
    CODE   => '&',
    SCALAR => '$',
    ARRAY  => '@',
    HASH   => '%',
);

sub package     { shift->[0] }
sub exports     { shift->[1] }
sub export_oks  { shift->[2] }
sub export_tags { shift->[3] }
sub _cache      { shift->[4] }
sub create_meta { shift->[5] }
sub parsers     { shift->[6] }

sub clear_cache { shift->[4] = {} }

sub _make_cached { __make_cached( $_ ) for @_ }
sub __make_cached {
    my ( $sub ) = @_;
    my $orig = __PACKAGE__->can( $sub );
    no strict 'refs';
    no warnings 'redefine';
    *$sub = sub {
        my $self = shift;

        $self->_cache->{$sub} = [ $self->$orig(@_) ]
            unless $self->_cache->{$sub};

        @{ $self->_cache->{$sub}};
    };
}

_make_cached qw/
    export_list export_ok_list all_exports_list
/;

sub new {
    my $class = shift;
    my ( $package, $creates_meta ) = @_;
    my $self = bless([$package,{},{},{},{},$creates_meta,{}], $class);
    {
        no strict 'refs';
        *{"$package\::EXPORT_TAGS"} = $self->export_tags;
        *{"$package\::export_meta"} = sub { $self };
    }
    return $self;
}

sub _add_export {
    my $self = shift;
    my ( $list, $name, $ref ) = @_;

    croak "Exports must be instances of 'Exporter::Declare::Export'"
        unless blessed( $ref ) && $ref->isa('Exporter::Declare::Export');

    my $idx = $TYPE_TO_IDX_MAP{reftype($ref)};

    croak "Already exporting type '" . reftype($ref) . "' under name '$name'"
        if $list->{$name}->[$idx];

    $self->clear_cache;
    $ref->name( $name );
    $list->{$name}->[$idx] = $ref;
}

sub add_export {
    my $self = shift;
    $self->_add_export( $self->exports, @_ );
}

sub add_export_ok {
    my $self = shift;
    $self->_add_export( $self->export_oks, @_ );
}

sub get_export_tag {
    my $self = shift;
    my ( $name ) = @_;
    return $self->_special_tag(lc( $name ))
        if $name =~ m/^(default|all|extended|prefix|suffix|extend)$/i;
    return unless $self->export_tags->{$name};
    map { ref($_) ? $_->( $self, $name ) : $_ } @{$self->export_tags->{$name}};
}

sub get_export_tags {
    my $self = shift;
    my %seen;
    grep { $seen{$_}++ ? () : ($_)} map { $self->get_export_tag($_) } @_;
}

sub push_export_tag {
    my $self = shift;
    my ( $name, @list ) = @_;
    croak "':$name' is a reserved tag, you cannot override it."
        if $name =~ m/^(default|all|extended)$/i;
    push @{$self->export_tags->{$name}} => @list;
}

sub _special_tag {
    my $self = shift;
    my ( $name ) = @_;
    return $self->export_list if $name eq 'default';
    return $self->export_ok_list if $name eq 'extended';
    return $self->all_exports_list;
}

sub _get_exports {
    my $self = shift;
    my ( $set, @names ) = @_;

    return grep { $_ } map { @{$_} } values %$set
        unless @names;

    @names = $self->build_names_list(@names);

    return map {
        my ( $type, $name ) = ( m/^([\$\@\%\&])?(.*)$/ );
        my $idx = $type ? $TYPE_TO_IDX_MAP{$type} : $TYPE_TO_IDX_MAP{CODE};
        my $ref = $set->{$name}->[$idx];

        croak $self->package . " does not export '$_'"
            unless $ref;

        $ref;
    } @names;
}

sub get_exports {
    my $self = shift;
    $self->_get_exports( $self->exports, @_ );
}

sub get_export_oks {
    my $self = shift;
    $self->_get_exports( $self->export_oks, @_ );
}

sub get_all_exports {
    my $self = shift;
    $self->_get_exports(
        {
            %{ $self->export_oks },
            %{ $self->exports },
        },
        @_,
    );
}

sub build_names_list {
    my $self = shift;
    my @in = @_;
    my ( %exclude, @include );
    for ( @in ) {
        my ( $exclude, $tag, $sigil, $name ) = ( m/^(!?)([:-]?)([\$\@\%\&]?)(.*)$/g );
        $sigil ||= '&';
        my @items = ( $tag
            ? (map { $_ =~ m/^[\@\%\$\&]/ ? $_ : "&$_" } $self->get_export_tag($name))
            : "${sigil}${name}"
        );
        if ( $exclude ) { $exclude{$_}++ for @items }
        else            { push @include => @items   }
    }
    @include = $self->export_list unless @include;
    return grep { !$exclude{$_} } @include;
}

sub _export_list {
    my $self = shift;
    my ( $set ) = @_;
    return map { $_ ? $TYPE_TO_SIGIL{reftype($_)} . $_->name : () } map { $_ ? @{$_} : () } values %$set;
}

sub export_list {
    my $self = shift;
    return $self->_export_list( $self->exports );
}

sub export_ok_list {
    my $self = shift;
    return $self->_export_list( $self->export_oks );
}

sub all_exports_list {
    my $self = shift;
    return $self->_export_list({
        %{ $self->export_oks },
        %{ $self->exports },
    });
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
