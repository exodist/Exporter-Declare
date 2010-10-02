#!/usr/bin/perl
use strict;
use warnings;

use Fennec::Lite;

our $PARSER_RAN;
BEGIN { $PARSER_RAN = 0 }

BEGIN {
    package My::Exporter;
    use Exporter::Declare '-magic';

    parser test {
        $main::PARSER_RAN++;
    }

    default_export doit test {
        return "blah";
    }
}

BEGIN { My::Exporter->import }

is( doit(), "blah", "Run keyword" );
is( $PARSER_RAN, 1, "Parser was invoked" );

done_testing;
