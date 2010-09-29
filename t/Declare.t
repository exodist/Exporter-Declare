#!/usr/bin/perl
use strict;
use warnings;

use Fennec::Lite;
use aliased 'Exporter::Declare::Meta';
use aliased 'Exporter::Declare::Specs';
use aliased 'Exporter::Declare::Export::Sub';
use aliased 'Exporter::Declare::Export::Variable';

our $CLASS;
our @IMPORTS;
BEGIN {
    @IMPORTS = qw/
        export
        gen_export
        default_export
        gen_default_export
        import
        export_to
        exports
        default_exports
        parsed_exports
        parsed_default_exports
        reexport
        options
    /;

    $CLASS = "Exporter::Declare";
    use_ok( $CLASS, '-alias', @IMPORTS );
}

can_ok( $CLASS, 'export_meta' );
can_ok( __PACKAGE__, @IMPORTS, 'Declare' );

is( Declare(), $CLASS, "Aliased" );

run_tests;
done_testing;
