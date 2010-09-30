#!/usr/bin/perl
use strict;
use warnings;

use Fennec::Lite;
use aliased 'Exporter::Declare::Meta';
use aliased 'Exporter::Declare::Export::Sub';
use aliased 'Exporter::Declare::Export::Variable';

our $CLASS = "Exporter::Declare::Specs";
require_ok $CLASS;

sub TestPackage { 'TestPackage' }

our $META = Meta->new( TestPackage );

$META->add_export(
    $_,
    Sub->new( sub {}, exported_by => __PACKAGE__ )
) for qw/x X xx XX/;

my %vars;
$META->add_export(
    "\$$_",
    Variable->new( \$vars{$_}, exported_by => __PACKAGE__ )
) for qw/y Y yy YY/;

$META->add_export(
    "\@$_",
    Variable->new( [$_], exported_by => __PACKAGE__ )
) for qw/z Z zz ZZ/;

$META->push_tag( 'xxx', qw/x $y @z/ );
$META->push_tag( 'yyy', qw/X $Y @Z/ );

$META->add_arguments( 'foo' );

tests construction => sub {
    my $spec = $CLASS->new( TestPackage );
    isa_ok( $spec, $CLASS );
    is( $spec->package, TestPackage, "Stored Package" );
    isa_ok( $spec->config, 'HASH', "Config" );
    isa_ok( $spec->exports, 'HASH', "Exports" );
    isa_ok( $spec->excludes, 'ARRAY', "Excludes" );
};

tests util => sub {
    my $spec = $CLASS->new( TestPackage );
    is( Exporter::Declare::Specs::_item_name('a' ), '&a', "Added sigil" );
    is( Exporter::Declare::Specs::_item_name('&a'), '&a', "kept sigil"  );
    is( Exporter::Declare::Specs::_item_name('$a'), '$a', "kept sigil"  );
    is( Exporter::Declare::Specs::_item_name('%a'), '%a', "kept sigil"  );
    is( Exporter::Declare::Specs::_item_name('@a'), '@a', "kept sigil"  );

    is(
        Exporter::Declare::Specs::_get_item($spec, 'X'),
        $META->get_export( 'X' ),
        "_get_export"
    );

    is_deeply(
        [ Exporter::Declare::Specs::_get_tag($spec, 'xxx')],
        [ $META->get_tag( 'xxx' )],
        "_get_export"
    );
};

tests exclude_list => sub {
    my $spec = $CLASS->new( TestPackage );
    is_deeply( $spec->excludes, [], "no excludes" );
    $spec->_exclude_item( $_ ) for qw/a &b $c %d @e/;
    is_deeply( $spec->excludes, [qw/&a &b $c %d @e/], "excludes" );
    $spec->_exclude_item( $_ ) for qw/q r -xxx :yyy/;
    is_deeply(
        $spec->excludes,
        [qw/&a &b $c %d @e &q &r &x $y @z &X $Y @Z/],
        "exclude tags"
    );
};

tests include_list => sub {
    my $spec = $CLASS->new( TestPackage );
    is_deeply( $spec->exports, {}, "Exports is an empty hash" );
    $spec->_include_item( 'XX' );
    lives_ok { $spec->_include_item( 'XX' ) } "Multiple add is no-op";
    is_deeply(
        $spec->exports,
        { '&XX' => [ $META->get_export( 'XX' ), {}, [] ]},
        "Added export"
    );
    $spec->_include_item( 'XX', { -a => 'a' }, ['a'] );
    is_deeply(
        $spec->exports,
        { '&XX' => [ $META->get_export( 'XX' ), { a => 'a' }, ['a'] ]},
        "Added export config"
    );
    $spec->_include_item( 'XX', { -a => 'a', -b => 'b', x => 'y' }, ['a', 'b'] );
    is_deeply(
        $spec->exports,
        { '&XX' => [ $META->get_export( 'XX' ), { a => 'a', b => 'b' }, ['a', 'a', 'b', 'x', 'y' ] ]},
        "combined configs"
    );

    $spec->_include_item( '-xxx', { -tag => 1, 'param' => 'p' }, [ 'from tag' ] );
    is_deeply(
        $spec->exports,
        {
            '&XX' => [ $META->get_export( 'XX' ), { a => 'a', b => 'b' }, [ 'a', 'a', 'b', 'x', 'y' ]],
            '&x'  => [ $META->get_export( '&x' ), { tag => 1 }, [ 'from tag', 'param', 'p' ]],
            '$y'  => [ $META->get_export( '$y' ), { tag => 1 }, [ 'from tag', 'param', 'p' ]],
            '@z'  => [ $META->get_export( '@z' ), { tag => 1 }, [ 'from tag', 'param', 'p' ]],
        },
        "included tag, with config"
    );
};

tests acceptance => sub {
    my $spec = $CLASS->new( TestPackage,
        qw/ $YY @ZZ &xx $yy @zz X $Y @Z !:xxx !$YY /,
        XX    => [ 'a', 'b' ],
        '&xx' => { -as => 'apple', -args => [ 'o' ], a => 'b' },
        -yyy  => { -prefix => 'uhg_', -suffix => '_blarg' },
        -foo  => 'bar',
        -prefix => 'aaa_',
    );
    is_deeply(
        $spec->excludes,
        [qw/ &x $y @z $YY/],
        "Excludes"
    );
    my $exp = sub { $META->get_export(@_)};
    is_deeply(
        $spec->exports,
        {
            '@ZZ' => [ $exp->('@ZZ'), {}, []],
            '&XX' => [ $exp->('&XX'), {}, [ 'a', 'b' ]],
            '&xx' => [ $exp->('&xx'), { as => 'apple' }, [ 'o', 'a', 'b' ]],
            '$yy' => [ $exp->('$yy'), {}, []],
            '@zz' => [ $exp->('@zz'), {}, []],
            '&X'  => [ $exp->('&X' ), { prefix => 'uhg_', suffix => '_blarg' }, []],
            '$Y'  => [ $exp->('$Y' ), { prefix => 'uhg_', suffix => '_blarg' }, []],
            '@Z'  => [ $exp->('@Z' ), { prefix => 'uhg_', suffix => '_blarg' }, []],
        },
        "Export list"
    );
    is_deeply(
        $spec->config,
        {
            foo => 'bar',
            prefix => 'aaa_',
            yyy => { -prefix => 'uhg_', -suffix => '_blarg' },
            xxx => '',
        },
        "Config"
    );

    $spec->export('FakePackage');

    can_ok( 'FakePackage', qw/apple aaa_XX uhg_X_blarg/ );
    no strict 'refs';
    isa_ok( \&{"FakePackage\::$_"}, Sub ) for qw/apple aaa_XX uhg_X_blarg/;
    isa_ok( \${"FakePackage\::$_"}, Variable ) for qw/aaa_yy uhg_Y_blarg/;
    isa_ok( \@{"FakePackage\::$_"}, Variable ) for qw/aaa_ZZ aaa_zz uhg_Z_blarg/;
};

run_tests;
done_testing;
