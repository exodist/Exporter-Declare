#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok 'Exporter::Declare::Meta';
use Exporter::Declare::Export;
our %EXPORT_TAGS;

sub fresh_meta {
    no warnings 'redefine';

    undef( &export_meta )
        if __PACKAGE__->can('export_meta');

    return Exporter::Declare::Meta->new(__PACKAGE__);
}

sub Export {
    Exporter::Declare::Export->new(
        @_,
        exported_by => __PACKAGE__,
    );
}

our @A = ( 'a', [ 'a' ], { 'a' => 'a' }, sub { 'a' });
our @B = ( 'b', [ 'b' ], { 'b' => 'b' }, sub { 'b' });

{ # setup
    my $meta = fresh_meta;

    is( __PACKAGE__->export_meta, $meta, "meta accessor" );
    is( $meta->package, __PACKAGE__, "got package" );
    is_deeply( $meta->exports, {}, "no exports" );
    is_deeply( $meta->export_oks, {}, "no export_oks" );
    is_deeply( $meta->export_tags, {}, "no export_tags" );

    is( \%EXPORT_TAGS, $meta->export_tags, "export_tags is linked" );
}

{ # adding exports
    my $meta = fresh_meta;

    my %list;

    $meta->_add_export( \%list, 'a', Export( $_ )) for \$A[0], @A[1,2,3];
    $meta->_add_export( \%list, 'b', Export( $_ )) for \$B[0], @B[1,2,3];

    is_deeply(
        \%list,
        {
            a => [ $A[3], \$A[0], $A[1], $A[2] ],
            b => [ $B[3], \$B[0], $B[1], $B[2] ],
        },
        "Added all exports"
    );

    throws_ok { $meta->_add_export( \%list, 'a', 'a' )}
        qr/Exports must be instances of 'Exporter::Declare::Export'/,
        "Must be blessed exports";

    throws_ok { $meta->_add_export( \%list, 'a', Export(sub {'a'}))}
        qr/Already exporting type 'CODE' under name 'a'/,
        "Export conflict";

    $meta->add_export( 'a', $A[3] );
    $meta->add_export_ok( 'b', $B[3] );

    is_deeply(
        $meta->exports,
        { a => [ $A[3] ]},
        "export"
    );

    is_deeply(
        $meta->export_oks,
        { b => [ $B[3] ]},
        "export_ok"
    );
}

{ #Retrieval
    my $meta = fresh_meta;

    $meta->add_export( 'a', $_ ) for \$A[0], @A[1,2,3];
    $meta->add_export_ok( 'b', $_ ) for \$B[0], @B[1,2,3];
    is( \%EXPORT_TAGS, $meta->export_tags, "export_tags is linked" );

    is_deeply(
        [ sort $meta->get_exports ],
        [ sort \$A[0], @A[1,2,3] ],
        "Got exports"
    );

    is_deeply(
        [ sort $meta->get_export_oks ],
        [ sort \$B[0], @B[1,2,3] ],
        "Got export_oks"
    );

    is_deeply(
        [ sort $meta->get_exports(qw/$a a/) ],
        [ sort \$A[0], $A[3] ],
        "Got exports by name"
    );

    is_deeply(
        [ sort $meta->get_export_oks(qw/%b @b/) ],
        [ sort @B[1,2] ],
        "Got export_oks by name"
    );

    throws_ok { $meta->get_exports( '$x' )}
        qr/main does not export '\$x'/,
        "Bad export";

    is_deeply(
        [ sort $meta->get_all_exports(qw/$a &a %b @b/)],
        [ sort \$A[0], $A[3], @B[1,2] ],
        "All exports - subset"
    );

    is_deeply(
        [ sort $meta->get_all_exports()],
        [ sort \$A[0], \$B[0], @A[1,2,3], @B[1,2,3] ],
        "All exports - all"
    );

    is_deeply(
        [ sort $meta->export_list ],
        [ sort qw/ $a %a @a &a /],
        "export list"
    );

    is_deeply(
        [ sort $meta->export_ok_list ],
        [ sort qw/ $b %b @b &b /],
        "export_ok list"
    );

    is_deeply(
        [ sort $meta->all_exports_list ],
        [ sort qw/ $a %a @a &a $b %b @b &b /],
        "all_exports list"
    );

    lives_ok { $meta->get_export_tag('a') } "do not die from empty tag";
    lives_ok { $meta->get_export_tags(qw/ b c /) } "do not die form empty tags";
    lives_ok { $meta->push_export_tag( 'a', qw/a b c/ ) } "Do not die pushing to empty";

    is_deeply(
        [ $meta->get_export_tag( 'a' )],
        [qw/ a b c /],
        "Pushed"
    );

    is_deeply(
        [ $meta->_special_tag( 'default' )],
        [ $meta->export_list ],
        ":default is correct"
    );

    is_deeply(
        [ $meta->_special_tag( 'extended' )],
        [ $meta->export_ok_list ],
        ":extended is correct"
    );

    is_deeply(
        [ $meta->_special_tag( 'all' )],
        [ $meta->all_exports_list ],
        ":all is correct"
    );

    throws_ok { $meta->push_export_tag( $_, qw/ a b c /)}
        qr/':$_' is a reserved tag, you cannot override it/,
        "Cannot modify :$_"
        for qw/default all extended DeFaUlT ExTeNdEd AlL/;

    is_deeply(
        [ $meta->get_export_tag($_) ],
        [ $meta->_special_tag(lc($_))],
        "$_ is special"
    ) for qw/default all extended DeFaUlT ExTeNdEd AlL/;

    is_deeply(
        [$meta->build_names_list(qw/a b c d e f g !a !f/)],
        [qw/&b &c &d &e &g/],
        "exclude works",
    );

    is_deeply(
        [sort $meta->build_names_list(qw/:a d e f g !b /)],
        [sort qw/&a &c &d &e &f &g/],
        ":tag + exclude works",
    );

    is_deeply(
        [sort $meta->build_names_list(qw/-a d e f g !b /)],
        [sort qw/&a &c &d &e &f &g/],
        "-tag + exclude works",
    );

    is_deeply(
        [sort $meta->build_names_list(qw/!:a a b c d e f g /)],
        [sort qw/&d &e &f &g/],
        "exclude tag works",
    );

    is_deeply(
        [$meta->build_names_list('!a')],
        [grep { $_ ne '&a' } $meta->export_list],
        "default + exclude",
    );
}

{
    my $meta = fresh_meta;
    our $AAA = 'aaa';
    our @AAA = ( 'aaa' );
    our %AAA = ( aaa => 'aaa' );

    is_deeply(
        [ $meta->get_ref_from_package( 'fresh_meta' )],
        [ \&fresh_meta, 'fresh_meta' ],
        "Got code ref"
    );
    is_deeply(
        [ $meta->get_ref_from_package( '$AAA' )],
        [ \$AAA, 'AAA' ],
        "Got scalar ref"
    );
    is_deeply(
        [ $meta->get_ref_from_package( '@AAA' )],
        [ \@AAA, 'AAA' ],
        "Got array ref"
    );
    is_deeply(
        [ $meta->get_ref_from_package( '%AAA' )],
        [ \%AAA, 'AAA' ],
        "Got hash ref"
    );
}

{
    my $meta = fresh_meta;
    no strict 'vars';

    is_deeply(
        [ $meta->get_ref_from_package( '&BBB' )],
        [ \&BBB, 'BBB' ],
        "Created code ref"
    );
    is_deeply(
        [ $meta->get_ref_from_package( '$BBB' )],
        [ \$BBB, 'BBB' ],
        "Created scalar ref"
    );
    is_deeply(
        [ $meta->get_ref_from_package( '@BBB' )],
        [ \@BBB, 'BBB' ],
        "Created array ref"
    );
    is_deeply(
        [ $meta->get_ref_from_package( '%BBB' )],
        [ \%BBB, 'BBB' ],
        "Created hash ref"
    );
}

done_testing;
