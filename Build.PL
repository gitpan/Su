#!/usr/bin/perl

use strict;
use warnings;

use CustomBuild;
use lib qw(lib);

my $builder = CustomBuild->new(
  module_name => 'Su',
  license     => 'perl',
  dist_author => 'lottz <lottzaddr@gmail.com>',
  dist_abstract =>
'A simple application layer to divide and integrate data and processes in the Perl program.',
  requres => {
    Exporter        => 0,
    'Test::More'    => 0,
    'File::Path'    => 0,
    'File::Copy'    => 0,
    Carp            => 0,
    'Module::Build' => 0,
    Fatal           => 0,
    'Data::Dumper'  => 0,
  },
  pm_files => {
    'lib/Su.pm'          => 'lib/Su.pm',
    'lib/Su/Log.pm'      => 'lib/Su/Log.pm',
    'lib/Su/Model.pm'    => 'lib/Su/Model.pm',
    'lib/Su/Process.pm'  => 'lib/Su/Process.pm',
    'lib/Su/Template.pm' => 'lib/Su/Template.pm'
  },
  dist_version_from  => 'lib/Su.pm',
  add_to_cleanup     => ['Su-*'],
  create_makefile_pl => 'traditional',

  test_types => {

    # ./Build testdoc
    testdoc => ['.td'],

    # ./Build testtd
    td => ['.td'],
    }

);

$builder->create_build_script;
