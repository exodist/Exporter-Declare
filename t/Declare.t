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
        export gen_export default_export gen_default_export import export_to
        exports default_exports parsed_exports parsed_default_exports reexport
        import_options import_arguments parser export_tag
    /;

    $CLASS = "Exporter::Declare";
    require_ok $CLASS;
    $CLASS->import( '-alias', @IMPORTS );
}

sub xxx {'xxx'}

tests package_usage => sub {
    can_ok( $CLASS, 'export_meta' );
    can_ok( __PACKAGE__, @IMPORTS, 'Declare' );
    can_ok( __PACKAGE__, 'export_meta' );

    is( Declare(), $CLASS, "Aliased" );

    is_deeply(
        [ sort( Declare()->exports )],
        [ sort map {"\&$_" } @IMPORTS, 'Declare' ],
        "Export list"
    );

    is_deeply(
        [ sort( Declare()->default_exports )],
        [ sort qw/exports default_exports import import_options import_arguments export_tag/ ],
        "Default Exports"
    );
};

tests magic => sub {
    lives_ok { export a b {} } "export magic";
    lives_ok {
        export b => sub {};
        export c => \&xxx;
        export 'xxx';
    } "export magic non-interfering";

    is( __PACKAGE__->export_meta->get_export( 'xxx' ), \&xxx, "export added" );
};

{
    package Export::Stuff;
    use Exporter::Declare '-magic';

    sub a    { 'a'       }
    sub b    { 'b'       }
    sub c    { 'c'       }
    sub meth { return @_ }

    our $X = 'x';
    our $Y = 'y';
    our $Z = 'z';

    exports qw/ $Y b /;
    default_exports qw/ $X a /;
    import_options qw/xxx yyy/;
    import_arguments qw/ foo bar /;
    export_tag vars => qw/ $X $Y /;
    export_tag subs => qw/ a b /;

    export $Z;
    export c;
    export baz { 'baz' }
    export eexport export { return @_ }

    my $gen = 0;
    gen_export gexp { my $out = $gen++; sub { $out }}
    gen_default_export defgen { my $out = $gen++; sub { $out }}
}

tests magic_tag => sub {
    # This tests that the magic tag brings in the magic methods as well as the
    # default which is a nested tag.
    can_ok( 'Export::Stuff', qw/
        export gen_export default_export gen_default_export parser
        parsed_exports parsed_default_exports import exports default_exports
        import_options import_arguments export_tag
    /);
};

tests generator => sub {
    Export::Stuff->import(qw/gexp/);
    is( gexp(), 0, "Generated first" );
    Export::Stuff->import(qw/defgen/);
    is( defgen(), 1, "Generated second" );
    Export::Stuff->import( defgen => { -as => 'blah' });
    is( blah(), 2, "Generated again" );
};


run_tests;
done_testing;
