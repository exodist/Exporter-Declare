#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
    package MyExporter;
    use strict;
    use warnings;
    use Exporter::Declare;

    export xxx { "xxx" };
}

MyExporter->export_to( __PACKAGE__ );
MyExporter->export_to( __PACKAGE__, 'pref_' );

can_ok( __PACKAGE__, 'xxx' );
can_ok( __PACKAGE__, 'pref_xxx' );

done_testing();
