use lib qw(t/test15 test15 lib ../lib);
use Su::Log;
use Test::More tests => 15;
use ForTest;

Su::Log->on('ForTest');
my $obj = ForTest->new;
my $ret = $obj->info_test();

is( $ret, "[INFO]info message.\n" );

$ret = $obj->trace_test();
ok( !$ret );

Su::Log->set_level("trace");
$ret = $obj->trace_test();
is( $ret, "[TRACE]trace message.\n" );

package Test15_Foo;
use Test::More;

sub new {
  my $self = shift;
  return bless {}, $self;
}

sub fn01 {
  my $log = Su::Log->new(shift);
  $log->info("info from Test15_Foo::fn01()");
}

sub fn02 {
  my $log = Su::Log->new(shift);
  $log->log_handler( \&hndl );
  return $log->info("info from Test15_Foo::fn02()");
}

sub hndl {
  $log_msg = join '', 'custom log handler:', @_;

  #  diag($log_msg);
  is( $log_msg, "custom log handler:[INFO]info from Test15_Foo::fn02()" );
  return $log_msg;
} ## end sub hndl

package main;

$obj = Test15_Foo->new;

$ret = undef;
$ret = $obj->fn01;

#diag( "ret is:" . $ret );
#diag(@Su::Log::target_class);

ok( !$ret, "Nothing logged because module is not registered." );

# Set the whole class as log target.
Su::Log->on;
$ret = $obj->fn01;

is(
  $ret,
  "[INFO]info from Test15_Foo::fn01()\n",
  "Logging is on, because all flag is set."
);

# test object specific log handler.

$ret = $obj->fn02;
is( $ret, "custom log handler:[INFO]info from Test15_Foo::fn02()" );

# test for functional usage.

# Omit constructor parmeter test.
Su::Log->clear_all_flag;
$log = new Su::Log->new;

ok( !$log->info("info message") );

# Register main package.
Su::Log->on(__PACKAGE__);

is( $log->info("info message"), "[INFO]info message\n" );

# Unregister main package.
Su::Log->off(__PACKAGE__);

ok( !$log->info("info message") );
ok( !$log->warn("info message") );
ok( !$log->crit("info message") );

## Use logger with function style.

$Su::Log::class_name = __PACKAGE__;
ok( !Su::Log::info("info message") );

Su::Log->on(__PACKAGE__);
is( Su::Log::info("info message2"), "[INFO]info message2\n" );

# Indeed, class_name is not required to determine caller package name.
$Su::Log::class_name = undef;
is( Su::Log::info("info message3"), "[INFO]info message3\n" );

