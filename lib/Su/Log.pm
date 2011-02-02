package Su::Log;
use Test::More;
use Carp;
use Data::Dumper;

=pod

=head1 NAME

Su::Log - A Simple Logger that has the feature of recognizing log
level and narrowing down the logging target class.

=head1 SYNOPSYS

  Su::Log->on('Target::Module::Name');
  Su::Log->set_level("trace");
  my $log = Su::Log->new;
  $log->info("info message");

  Su::Log->on(__PACKAGE__);
  Su::Log::info("info message");

=head1 DESCRIPTION

Su::Log is a simple Logger module.
Su::Log has the following features.

=over

=item  Narrow down the output by log level.

=item  Narrow down the logging target class.

=item  Narrow down the output by customized log kind.

=item  Customize the log handler function.

=back

=head1 FUNCTIONS

=over

=cut

our @target_class = ();
our @target_tag   = ();
our $level        = "info";

# If you use want to use this Log class not via log oblect, but log
# function directly, set current class name to this variable.
our $class_name;

our $all_on  = 0;
our $all_off = 0;
our $log_handler;

BEGIN: {

  # Set default handler.
  $log_handler =
    sub { my $msg = join( '', @_, "\n" ); print $msg; return $msg; };

} ## end BEGIN:

my $level_hash = {
  trace => 1,
  info  => 2,
  warn  => 3,
  error => 4,
  crit  => 5,
};

=item on()

Add the passed module name to the list of the logging tareget.
If the parameter is not passed, then set the whole class as logging
target.

=cut

# NOTE: @target_class is a package variable, so shared with other
# logger user even if you call this method via the specific logger
# instance.
sub on {
  shift if ( $_[0] eq __PACKAGE__ || ref $_[0] eq __PACKAGE__ );
  my $class = shift;
  if ($class) {
    push @target_class, $class;
  } else {
    $all_on  = 1;
    $all_off = 0;
  }
} ## end sub on

=item off()

Remove the passed module name from the list of the logging tareget.

=cut

sub off {
  shift if ( $_[0] eq __PACKAGE__ || ref $_[0] eq __PACKAGE__ );
  my $class = shift;

  if ($class) {

    # Remove passed class name from log target classes.
    @target_class = grep !/^$class$/, @target_class;
  } else {
    $all_off = 1;
    $all_on  = 0;
  }
} ## end sub off

=item clear_all_flag()

Clear C<$all_on> and C<$all_off> flags.

=cut

sub clear_all_flag {
  $all_on  = 0;
  $all_off = 0;
}

=item tag_on()

Add the passed tag to the target tags list.

=cut

sub tag_on {
  shift if ( $_[0] eq __PACKAGE__ );
  my $tag = shift;
  push @target_tag, $tag;
}

=item tag_off()

Remove the passed tag from the target tags list.

=cut

sub tag_off {
  shift if ( $_[0] eq __PACKAGE__ );
  my $tag = shift;
  @target_tag = grep !/^$tag$/, @target_tag;
}

=item new()

Constructor.

 my $log = new Su::Log->new;
 my $log = new Su::Log->new($self);
 my $log = new Su::Log->new('PKG::TargetClass');

Instantiate the Logger class. The passed instance or the string of the
module name is registered as a logging target class. If the parameter
is omitted, then the caller is registered automatically.

=cut

sub new {
  my $self = shift;
  $self = ref $self if ( ref $self );
  my $target_class = shift;

  # If passed argment is a reference of the instance, then extract class name.
  my $class_name = ref $target_class;

  # Else, use passed string as class name.
  if ( !$class_name ) {
    $class_name = $target_class;
  }

  if ( !$class_name ) {
    $class_name = caller();
  }

  #  diag("classname:" . $class_name);
  #  diag( Dumper($class_name));
  # Su::Log->trace( "classname:" . $class_name );
  # Su::Log->trace( Dumper($class_name) );

  return bless { class_name => $class_name }, $self;
} ## end sub new

=item is_target()

Determine whether the module is a logging target or not.

=cut

sub is_target {
  my $self = shift;

  if ($all_on) {
    return 1;
  } elsif ($all_off) {
    return 0;
  }

  my $self_class_name = $self;
  if ( ref $self ) {
    $self_class_name = $self->{class_name} ? $self->{class_name} : $class_name;
  }

  #diag("check classname:" . $self->{class_name});
  #  if(! defined($self->{class_name})){
  #    die "Class name not passed to the log instance.";
  #  }

#NOTE:Can not trace via trace or something Log class provide. Because recurssion occurs.
#diag( @target_class);

  # diag("grep result:" . (grep /^$self->{class_name}$/, @target_class));
  #  if (index($self->{class_name}, @target_class) != -1){
  if ( ( grep /^$self_class_name$/, @target_class ) ) {
    return 1;
  } else {
    return 0;
  }
} ## end sub is_target

=item set_level()

Su::Log->set_level("trace");

Set the log level. This setting effects as the package scope variable.

=cut

sub set_level {

  # The first argment may be reference of object or string of class name.
  shift if ( ref $_[0] eq __PACKAGE__ || $_[0] eq __PACKAGE__ );
  my $passed_level = shift;
  croak "Passed log level is invalid:" . $passed_level
    if !grep /^$passed_level$/, keys %{$level_hash};
  $level = $passed_level;
} ## end sub set_level

=item is_large_level()

Return whether the passed log level is larger than the current log level or not.

=cut

sub is_large_level {
  shift if ( ref $_[0] eq __PACKAGE__ );

  my $arg = shift;

#NOTE:Can not trace via trace command which Log class provides, because recursion occurs.
#diag("compare:" . $arg . ":" . $level);
  return $level_hash->{$arg} >= $level_hash->{$level} ? 1 : 0;
} ## end sub is_large_level

=item trace()

Log the passed message as trace level.

=cut

sub trace {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $log_handler = $self->{log_handler} ? $self->{log_handler} : $log_handler;
  if ( is_target( _is_empty($self) ? caller() : $self )
    && is_large_level("trace") )
  {

    #    if (is_target($self ? $self : caller()) && is_large_level("trace")){
    return $log_handler->( "[TRACE]", @_ );
  } ## end if ( is_target( _is_empty...))
} ## end sub trace

=item info()

Log the passed message as info level.

=cut

sub info {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $log_handler = $self->{log_handler} ? $self->{log_handler} : $log_handler;

  #diag("info check:" . Dumper(is_empty($self) ? caller() : $self));
  if ( is_target( _is_empty($self) ? caller() : $self )
    && is_large_level("info") )
  {
    return $log_handler->( "[INFO]", @_ );
  }
} ## end sub info

=item warn()

Log the passed message as warn level.

=cut

sub warn {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $log_handler = $self->{log_handler} ? $self->{log_handler} : $log_handler;
  if ( is_target( _is_empty($self) ? caller() : $self )
    && is_large_level("warn") )
  {

    #  if (is_target($self ? $self : caller()) && is_large_level("warn")){
    return $log_handler->( "[WARN]", @_ );
  } ## end if ( is_target( _is_empty...))
} ## end sub warn

=item error()

Log the passed message as error level.

=cut

sub error {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $log_handler = $self->{log_handler} ? $self->{log_handler} : $log_handler;
  if ( is_target( _is_empty($self) ? caller() : $self )
    && is_large_level("error") )
  {

    #  if (is_target($self ? $self : caller()) && is_large_level("error")){
    return $log_handler->( "[ERROR]", @_ );
  } ## end if ( is_target( _is_empty...))
} ## end sub error

=item crit()

Log the passed message as crit level.

=cut

sub crit {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $log_handler = $self->{log_handler} ? $self->{log_handler} : $log_handler;
  if ( is_target( _is_empty($self) ? caller() : $self )
    && is_large_level("crit") )
  {

    #  if (is_target($self ? $self : caller()) && is_large_level("crit")){
    return $log_handler->( "[CRIT]", @_ );
  } ## end if ( is_target( _is_empty...))
} ## end sub crit

=item log()

Log the message with the passed tag, if the passed tag is active.

  my $log = Su::Log->new($self);
  $log->log("some_tag","some message");

=cut

sub log {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $tag = shift;

  my $log_handler = $self->{log_handler} ? $self->{log_handler} : $log_handler;
  if ( is_target( _is_empty($self) ? caller() : $self )
    && ( grep /^$tag$/, @target_tag ) )
  {
    return $log_handler->( "[" . $tag . "]", @_ );
  }

} ## end sub log

=item log_handler()

Specify the passed method as the log handler of L<Su::Log|Su::Log>.

  $log->log_handler(\&hndl);
  $log->info("info message");

  sub hndl{
    print(join 'custom log handler:', @_);
  }

=cut

sub log_handler {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $handler = shift;
  if ($handler) {
    if ($self) {
      $self->{log_handler} = $handler;
    } else {
      $log_handler = $handler;
    }
  } else {
    return $log_handler;
  }
} ## end sub log_handler

=begin comment

Internal Utility function.

=end comment

=cut

sub _is_empty {
  my $arg = shift;
  return 1 if ( !$arg );
  if ( ref $arg eq 'HASH' ) {
    return 1 unless ( scalar keys %{$arg} );
  }
  return 0;
} ## end sub _is_empty

=pod

=back

=cut

