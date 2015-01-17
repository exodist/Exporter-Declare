#!/usr/bin/perl
use strict;
use warnings;
use Module::Build;

#This part (creating a subclass) helps generating
# a github-friendly readme.pod file alongside with
# the traditional readme file with no markdown.
my $class = Module::Build->subclass(
    class => 'My::Builder',
    code => q{
        sub ACTION_docs {
            use Pod::Readme;
            use Pod::Select;

            my $self = shift;

            podselect({ -output => 'README.pod' },
                'lib/Exporter/Declare.pm');

            my $parser = Pod::Readme->new();
            $parser->parse_from_file('README.pod', 'README');

            return $self->SUPER::ACTION_docs;
        }
    }
);

my $build = $class->new(
    module_name => 'Exporter::Declare',
    license     => 'perl',
    dist_author => 'Chad Granum <exodist7@gmail.com>',
    create_readme => 1,
    requires => {
        'perl'          => '5.8.0',
        'Carp'          => 0,
        'Scalar::Util'  => 0,
        'aliased'       => 0,
        'Meta::Builder' => '0.003',
    },
    configure_requires => {
        'Pod::Readme' => 0,
        'Pod::Select' => 0,
    },
    build_requires => {
        'Test::Simple'    => 0.88,
        'Fennec::Lite'    => '0.004',
        'Test::Exception' => '0.29',
        'Pod::Readme' => 0,
        'Pod::Select' => 0,
    },
    meta_merge => {
        resources => {
            repository  => 'http://github.com/exodist/Exporter-Declare',
            bugtracker  => 'http://github.com/exodist/Exporter-Declare/issues',
            homepage    => 'http://open-exodus.net/projects/Exporter-Declare',
        },
    }
);

$build->create_build_script;
