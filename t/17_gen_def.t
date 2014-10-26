use lib qw(t/test17 lib);
use Su;
use Test::More tests => 3;

my $fg = Su->new( base => 't/test17' );

unlink 't/test17/Defs/Defs.pm' if ( -f 't/test17/Defs/Defs.pm' );

$fg->gen_defs();

ok( -f 't/test17/Defs/Defs.pm' );

$fg->_load_defs_file();

ok( $fg->{defs_href} );

$expect = {
  'main' => {
    'model' => 'Model',
    'proc'  => 'MainProc'
  }
};

is_deeply( $fg->{defs_href}, $expect )

