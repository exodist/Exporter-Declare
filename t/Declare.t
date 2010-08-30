#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
    package MyExporter;
    use strict;
    use warnings;
    use Test::More;
    use Exporter::Declare;
    use Test::Exception::LessClever;

    sub normal { 1 };
    export normala => sub { 1 };
    export normalb => \&normal;
    export 'normal';

    # export name parser { ... }

    export apple { 'apple' }

    export pear ( inject => 'my $pear = "pear";' ) { $pear }

    export eexport export ( inject => 'my $inject = 1;' ) {
        is( $_[0], "name", "got name" );
        is( $_[1], "export", "got parser" );
        is( $inject, 1, "injected" );
    }

    export_ok optional { 'You got me' }

    my $id = 1;
    gen_export id => sub { my $i = $id++; sub { $i }};
    my $id2 = 10;
    gen_export_ok id2 => sub { my $i = $id2++; sub { $i }};
}

BEGIN { MyExporter->import( ':all' ) };

eexport name export { 1 };
is( apple(), "apple", "export name and block" );
is( pear(), "pear", "export name and block with specs" );

is( optional(), 'You got me', "export_ok magic" );

is( id(), 1, "ID" );
is( id(), 1, "ID Again" );

is( id2(), 10, "ID2" );
is( id2(), 10, "ID2 Again" );

done_testing();
