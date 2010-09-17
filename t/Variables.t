#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

BEGIN {
    package VarExporter;
    use strict;
    use warnings;
    use Exporter::Declare;

    our @EXPORT = qw/ $SCALAR @ARRAY %HASH $EMPTY %EMPTY @EMPTY /;

    our $SCALAR = 'Scalar';
    our @ARRAY = ( 'Array', 'Array' );
    our %HASH = ( Hash => 'Hash' );

    our ( %EMPTY, @EMPTY, $EMPTY );

    my $scalar = "scalar";
    my @array = ( 'array', 'array' );

    export '$scalar' => \$scalar;
    export '@array' => \@array;
    export( '%hash', { 'hash' => 'hash' });

    export( '@empty' => []);
    export( '$empty' => \'');
    export( '%empty' => {});
}

BEGIN{ VarExporter->import() };

is( $SCALAR, 'Scalar' );
is_deeply( \@ARRAY, [ 'Array', 'Array' ]);
is_deeply( \%HASH, { Hash => 'Hash' });

is( $scalar, "scalar" );
is_deeply( \@array, [ 'array', 'array' ]);
is_deeply( \%hash, { hash => 'hash' });

is( $EMPTY, undef );
is( $empty, '' );

is_deeply( \@EMPTY, [] );
is_deeply( \@empty, [] );

is_deeply( \%EMPTY, {} );
is_deeply( \%empty, {} );

done_testing;
