use lib qw(../t/test18 t/test18 lib);
use Su;
use Data::Dumper;
use Test::More tests => 11;

if ( -f "./t/test18/Pkg/TestProc.pm" ) {
  unlink "./t/test18/Pkg/TestProc.pm" or die $!;
}

# Set base form Su::Template package.
`perl -MSu::Process=base,./t/test18/ -e 'Su::Process::generate_proc("Pkg::TestProc")'`;

ok( -f "./t/test18/Pkg/TestProc.pm" );

my $suproc = Su::Process->new;
my $proc   = $suproc->load_module('Pkg::TestProc');
ok( $proc, 'Load a Template which has nested packag name.' );

if ( -f "./t/test18/SuPkg/TestProc.pm" ) {
  unlink "./t/test18/SuPkg/TestProc.pm" or die $!;
}

# Set base form Su package.
`perl -MSu::Process=base,./t/test18/ -e 'Su::Process::generate_proc("SuPkg::TestProc")'`;

ok( -f "./t/test18/SuPkg/TestProc.pm" );

## Generate Model test.

if ( -f "./t/test18/SuModelPkg/TestModel.pm" ) {
  unlink "./t/test18/SuModelPkg/TestModel.pm" or die $!;
}

`perl -MSu::Model=base,./t/test18/ -e 'Su::Model::generate_model("SuModelPkg::TestModel")'`;

ok( -f "./t/test18/SuModelPkg/TestModel.pm" );

my $su_model = Su::Model->new;
my $mdl      = $su_model->load_model('SuModelPkg::TestModel');

ok($mdl);

if ( -f "./t/test18/Defs/Defs.pm" ) {
  unlink "./t/test18/Defs/Defs.pm" or die $!;
}

`perl -MSu=base,./t/test18/ -e 'Su::gen_defs()'`;

ok( -f "./t/test18/Defs/Defs.pm" );

if ( -f "./t/test18/MyDefs/MyDefs.pm" ) {
  unlink "./t/test18/MyDefs/MyDefs.pm" or die $!;
}

`perl -MSu=base,./t/test18/ -e 'Su::gen_defs("MyDefs::MyDefs")'`;

ok( -f "./t/test18/MyDefs/MyDefs.pm" );

my $su = Su->new( base => 't/test18', defs_module => 'MyDefs::MyDefs' );

is( $su->{defs_module}, 'MyDefs::MyDefs' );

diag( Dumper() );

my $expect = {
  'main' => {
    'proc'  => 'MainProc',
    'model' => 'Model'
  }
};

is_deeply( $su->_load_defs_file, $expect );

if ( -f "./t/test18/Pkg/TestProcFromSu.pm" ) {
  unlink "./t/test18/Pkg/TestProcFromSu.pm" or die $!;
}

# Set base form Su package.
`perl -MSu=base,./t/test18/ -e 'Su::gen_proc("Pkg::TestProcFromSu")'`;

ok( -f "./t/test18/Pkg/TestProcFromSu.pm" );

if ( -f "./t/test18/Pkg/TestModelFromSu.pm" ) {
  unlink "./t/test18/Pkg/TestModelFromSu.pm" or die $!;
}

# Set base form Su package.
`perl -MSu=base,./t/test18/ -e 'Su::gen_model("Pkg::TestModelFromSu")'`;

ok( -f "./t/test18/Pkg/TestModelFromSu.pm" );
