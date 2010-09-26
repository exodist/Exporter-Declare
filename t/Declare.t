#!/usr/bin/perl
use strict;
use warnings;

use Fennec::Lite;

require_ok 'Exporter::Declare';

*parse_import_args = \&Exporter::Declare::parse_import_args;

my ( $specs, @imports ) = parse_import_args(
    { a => 'b', c => 'd' },
    qw/a b c :aa -bb !:cc !-dd/,
    ':ee' => { -prefix => 'xxx_' },
    ff => { -as => 'fff' },
    gg => [qw/ a b c /],
);



done_testing;

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
        if ( ref $next eq 'ARRAY' ) {
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


