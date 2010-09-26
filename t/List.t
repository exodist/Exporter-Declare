#!/usr/bin/perl
use strict;
use warnings;

use Fennec::Lite;

BEGIN {
    use_ok "Exporter::Declare::List";
    use_ok "Exporter::Declare::Meta";
}

BEGIN { Exporter::Declare::Meta->new( 'TestClass' )}

tie( @TestClass::EXPORT, 'Exporter::Declare::List', 'TestClass', 'export' );

{
    package TestClass;
    our @EXPORT = qw/ $xxx aaa /;

    our $xxx = "xxx";
    our %bbb = ( bbb => 'bbb' );
    sub aaa { 'aaa' }
}

my ($exp) = TestClass->export_meta->get_exports( '$xxx' );
is( $$exp, "xxx", "Got correct value from ref" );
our $xxx;
$exp->inject( __PACKAGE__, 'xxx' );
is( $xxx, "xxx", "Got correct value" );
$TestClass::xxx = "change";
is( $xxx, "change", "Got correct value after change" );

is_deeply(
    [ sort TestClass->export_meta->get_exports() ],
    [ sort \$TestClass::xxx, TestClass->can('aaa' ) ],
    "Got exports"
);

push @TestClass::EXPORT => '%bbb';

is_deeply(
    [ sort TestClass->export_meta->get_exports() ],
    [ sort \$TestClass::xxx, \%TestClass::bbb, TestClass->can( 'aaa' ) ],
    "Added exports"
);

TestClass->export_meta->add_export(
    'ccc',
    Exporter::Declare::Export::Variable->new( [ 'ccc' ], exported_by => __PACKAGE__ ),
);

is_deeply(
    [ sort @TestClass::EXPORT ],
    [ sort qw/ %bbb $xxx &aaa @ccc / ],
    "List is updated"
);

done_testing;
