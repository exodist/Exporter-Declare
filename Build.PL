#!/usr/bin/perl
use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'Exporter::Declare',
    license     => 'perl',
    dist_author => 'Chad Granum <exodist7@gmail.com>',
    create_readme => 1,
    requires => {
        'Devel::Declare::Parser' => 0.012,
        'Test::Exception::LessClever' => 0,
        'Test::Simple' => 0.88,
        'Carp' => 0,
        'Scalar::Util' => 0,
    },
    meta_merge => {
        resources => {
            repository  => 'http://github.com/exodist/Exporter-Declare',
            bugtracker  => 'http://github.com/exodist/Exporter-Declare/issues',
        },
    }
);

$build->create_build_script;
