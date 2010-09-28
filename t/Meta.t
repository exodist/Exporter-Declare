#!/usr/bin/perl
use strict;
use warnings;

use Fennec::Lite;
use aliased 'Exporter::Declare::Export::Sub';
use aliased 'Exporter::Declare::Export::Variable';

our $CLASS = "Exporter::Declare::Meta";
require_ok $CLASS;

tests construction => sub {
    my $meta = $CLASS->new('FakePackage');
    isa_ok( $meta, $CLASS );
    is( FakePackage->export_meta, $meta, "Linked" );
    is_deeply(
        $meta,
        [
            'FakePackage',
            {},
            { default => [], all => [] },
            {},
            { suffix => 1, prefix => 1 },
        ],
        "Correct attributes"
    );
    is( $meta->package, 'FakePackage', "Got package" );
    is_deeply( $meta->_exports, {}, "Got export hash" );
    is_deeply( $meta->_export_tags, { default => [], all => [] }, "Got export tags" );
    is_deeply( $meta->_parsers, {}, "Got parser list" );
    is_deeply( $meta->_options, { suffix => 1, prefix => 1 }, "Got options list" );
};

tests tags => sub {
    my $meta = $CLASS->new('FakeTagPackage');
    is_deeply(
        $meta->_export_tags,
        { default => [], all => [] },
        "Export tags"
    );
    is_deeply( [$meta->get_tag('all')],     [], ':all is empty list'     );
    is_deeply( [$meta->get_tag('default')], [], ':default is empty list' );

    $meta->push_tag( 'a', qw/a b c d/ );
    is_deeply( [$meta->get_tag('a')], [qw/a b c d/], "Added tag" );

    throws_ok { $meta->push_tag( 'all', "xxx" )}
        qr/'all' is a reserved tag, you cannot override it./,
        "Cannot modify 'all' tag";

    $meta->push_tag( 'default', qw/a b c d/ );
    is_deeply( [$meta->get_tag('default')], [qw/a b c d/], "updated default" );
};

tests exports => sub {
    my $meta = $CLASS->new('FakeExportPackage');
    is_deeply( $meta->_exports, {}, "No exports" );

    my $code_no_sigil = Sub->new(sub {}, exported_by => 'FakeExportPackage' );
    $meta->add_export( 'code_no_sigil', $code_no_sigil);
    is_deeply(
        $meta->_exports,
        { '&code_no_sigil' => $code_no_sigil },
        "Added export without sigil as code"
    );

    my $code_with_sigil = Sub->new(sub {}, exported_by => 'FakeExportPackage' );
    $meta->add_export( '&code_with_sigil', $code_with_sigil);
    is_deeply(
        $meta->_exports,
        {
            '&code_no_sigil' => $code_no_sigil,
            '&code_with_sigil' => $code_with_sigil,
        },
        "Added code export"
    );

    my $anon = "xxx";
    my $scalar = Variable->new( \$anon, exported_by => 'FakeExportPackage' );
    $meta->add_export( '$scalar', $scalar );

    my $hash = Variable->new( {}, exported_by => 'FakeExportPackage' );
    $meta->add_export( '%hash', $hash );

    my $array = Variable->new( [], exported_by => 'FakeExportPackage' );
    $meta->add_export( '@array', $array );

    is_deeply(
        $meta->_exports,
        {
            '&code_no_sigil'   => $code_no_sigil,
            '&code_with_sigil' => $code_with_sigil,
            '$scalar'          => $scalar,
            '%hash'            => $hash,
            '@array'           => $array,
        },
        "Added exports"
    );

    throws_ok { $meta->add_export( '@array', $array )}
        qr/Already exporting '\@array'/,
        "Can't add an export twice";

    throws_ok { $meta->add_export( '@array2', [] )}
        qr/Exports must be instances of 'Exporter::Declare::Export'/,
        "Can't add an export twice";

    is( $meta->get_export( '$scalar'          ), $scalar,          "Got scalar export" );
    is( $meta->get_export( '@array'           ), $array,           "Got array export"  );
    is( $meta->get_export( '%hash'            ), $hash,            "Got hash export"   );
    is( $meta->get_export( '&code_with_sigil' ), $code_with_sigil, "Got &code export"  );
    is( $meta->get_export( 'code_no_sigil'    ), $code_no_sigil,   "Got code export"   );

    throws_ok { $meta->get_export( '@array2' )}
        qr/FakeExportPackage does not export '\@array2'/,
        "Can't import whats not exported";

    throws_ok { $meta->get_export( '-xxx' )}
        qr/get_export\(\) does not accept a tag as an argument/,
        "Can't import whats not exported";

    throws_ok { $meta->get_export( ':xxx' )}
        qr/get_export\(\) does not accept a tag as an argument/,
        "Can't import whats not exported";
};

{
    package PackageToPull;

    sub a { 'a' }
    our $B = 'b';
    our @C = ( 'c' );
    our %D = ( 'D' => 'd' );
}

tests pull_from_package => sub {
    my $meta = $CLASS->new('PackageToPull');
    is_deeply(
        [$meta->get_ref_from_package( 'a' )],
        [ \&PackageToPull::a, '&a' ],
        "Puled a sub"
    );
    is_deeply(
        [$meta->get_ref_from_package( '&a' )],
        [ \&PackageToPull::a, '&a' ],
        "Puled a sub w/ sigil"
    );

    is_deeply(
        [$meta->get_ref_from_package( '$B' )],
        [ \$PackageToPull::B, '$B' ],
        "Puled scalar"
    );

    is_deeply(
        [$meta->get_ref_from_package( '@C' )],
        [ \@PackageToPull::C, '@C' ],
        "Puled array"
    );

    is_deeply(
        [$meta->get_ref_from_package( '%D' )],
        [ \%PackageToPull::D, '%D' ],
        "Puled hash"
    );
};

run_tests();
done_testing;
