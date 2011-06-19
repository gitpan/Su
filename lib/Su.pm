package Su;

use strict;
use warnings;
use Exporter;
use Data::Dumper;
use Carp;
use Test::More;
use File::Path;

use Su::Process;
use Su::Template;
use Su::Model;
use Su::Log;

use Fatal qw(mkpath);

our $VERSION = '0.011';

our @ISA = qw(Exporter);

our @EXPORT = qw(resolve setup gen_defs gen_model gen_proc);

our $info_href = {};

our $BASE_DIR = './';

our $DEFS_DIR = 'Defs';

our $DEFS_MODULE_NAME = "Defs";

our $DEFAULT_MODEL_NAME = 'Model';

our $DEFAULT_PROC_NAME = 'MainProc';

=head1 NAME

Su - A simple application layer to divide and integrate data and processes in the Perl program.

=head1 SYNOPSIS

 my $su = Su->new;
 my $proc_result = $su->resolve('process_id');
 print $proc_result;

=head1 DESCRIPTION

Su is a simple application framework that works as a thin layer to
divide data and process in your Perl program. This framework aims an
ease of maintenance and extension of your application.

Su is a thin application layer, so you can use Su with many other
frameworks you prefer in many cases.

Note that Su framework has nothing to do with unix C<su> (switch
user) command.

=head3 Divide data and process in your code

For divide data and process, Su framework provides Model and Process
classes.  Model and Process classes represent data and process of your
application.  You define the data used in the application to the
Model, and describe own code to the Process.  Models and Processes are
just a simple Perl module and not required to implement any base class
of Su framework.

=head3 Integrate model and process in your code

Su integrates Model and Process classes using the definition file. The
definition file also a Perl module. Su read the definition file and
inject the data defined in the Model to the corresponding Process,
then execute that Process.

=head3 Other features Su provides

Su also provides some useful features.

For convinience, Su framework provides the methods to generate the
template of the Model and Process classes.

Su also provides logging and string template.  These features are
frequently used in many kinds of applications and you can use these
features without any other dependencies.  Surely you can use other
modules you prefer with Su framework.

=head2 Standard usage

=head3 Generate Su files

Described above, Su is composed of Model, Process and Definition module.
The Definition module named C<Defs.pm> integrates Model and Processes.
So, at first, we generate these files from the command line.

To generate the Model file, type the following command.

 perl -MSu=base,./lib/ -e 'Su::gen_model("Pkg::SomeModel")'

To generate the Process file, type the following command.

 perl -MSu=base,./lib/ -e 'Su::gen_proc("Pkg::SomeProc")'

To generate the definition file, type the following command.

 perl -MSu=base,./lib/ -e 'Su::gen_defs()'

The 'base' parameter means the base directory of the modules to generate.

Instead of these three commands, you can use the simplified single command.

 perl -MSu -e 'Su::init("MyPkg")'

This command generates these three files at once.

=head3 Describe Setting file

To call the generated process, you need to define the entry to the generated definition file F<Defs/Defs.pm>.

The Definition file is a perl module, and define the entry at the C<$defs> field of it.

 my $defs =
   {
    some_entry_id =>
    {
     proc=>'Pkg::SomeProc',
     model=>'Pkg::SomeModel',
    },
   };

In this case, the entry id is specified as C<some_entry_id>.
The Process and Model modules are specified at the field of C<proc> and C<model>, respectively.

=head3 Set data to the Model

You can define some data to the C<$model> field of the generated Model.

For example, edit C<Pkg::SomeModel> module like the following.

 my $model=
 {
   field_a =>'value_a'
 };

=head3 Describe the Process

You can describe own code to the C<process> method of the generated Process.

In this case you can edit C<Pkg::SomeProc> like the following.

 sub process{
   my $self = shift if ref $_[0] eq __PACKAGE__;

   my $param = shift;
   my $ret = "param:" . $param . " and model:" . $model->{field_a};
   return $ret;
 }

Note that you can refer to the model data previouslly defined at the
C<$model> field of the Model class via the C<$model> field.

The Process and Model modules are tied as defined in Defs module by Su framework.

=head3 Call the Process via Su

You can call the process via Su by passing the entry id which defined in
the definition file F<Defs.pm>.

 my $su = Su->new;
 my $result = $su->resolve('some_entry_id');

=head2 Additional usage - Filters

The map, reduce and scalar filters can be defined in the definition file.

These filters are Perl module which has the method for filtering the
result of the process. (In case of C<map> filter, method name is
C<map_filter>.) You can chain filter modules.  The following code is a
sample definition which uses these filters.

  my $defs =
   {
    some_proc_id =>
    {
     proc=>'MainProc',
     model=>'Pkg::MainModel',
     map_filter=>'Pkg::FilterProc',     # or ['Filter01','Filter02']
     reduce_filter=>'Pkg::ReduceProc',  # reduce filter can only apply at once.
     scalar_filter=>'Pkg::ScalarProc',  # or ['Filter01','Filter02']
    }
   };

The filters Su recognizes are the followings.

=over

=item map_filter

The perl module which has C<map_filter> method.
The parameter of this method is an array which is a result of the
'process' method of the Process or the chained map filter.
The C<map_filter> method must return the array data type.

=item reduce_filter

The perl module which has C<reduce_filter> method.
The parameter of this method is an array which is a result of the
'process' method of the Process.
If the map_filters are defined in the C<Defs.pm>, then the map_filters
are applied to the result of the process before passed to the reduce
filter.
The C<reduce_filter> method must return the scalar data type.
Note that this method can't chain.

=item scalar_filter

The perl module which has C<scalar_filter> method.
The parameter of this method is a scalar which is a result of the
'process' method of the Process.
If the map_filters and recude_filters are defined in the C<Defs.pm>,
then these filters are applied to the result of the process before
passed to the scalar filter.

The C<scalar_filter> method must return the scalar data type.

=back

=head1 METHODS

=over

=item import()

use Su base=>'./base', proc=>'tmpls', model=>'models', defs=>'defs';

If you want to specify some parameters from the command line, then it becomes like the following.

perl -Ilib -MSu=base,./base,proc,tmpls,defs,models -e '{print "do some work";}'

=cut

sub import {
  my $self = shift;

  # Save import list and remove from hash.
  my %tmp_h        = @_;
  my $imports_aref = $tmp_h{import};

  delete $tmp_h{import};
  my $base     = $tmp_h{base};
  my $template = $tmp_h{template};
  my $defs     = $tmp_h{defs};
  my $model    = $tmp_h{model};

  #  print "base:" . Dumper($base) . "\n";
  #  print "template:" . Dumper($template) . "\n";
  #  print "model:" . Dumper($model) . "\n";
  #  print "defs:" . Dumper($defs) . "\n";
  #  $self->{logger}->trace( "base:" . Dumper($base) );
  #  $self->{logger}->trace( "template:" . Dumper($template) );
  #  $self->{logger}->trace( "model:" . Dumper($model) );
  #  $self->{logger}->trace( "defs:" . Dumper($defs) );
  Su::Log->trace( "base:" . Dumper($base) );
  Su::Log->trace( "template:" . Dumper($template) );
  Su::Log->trace( "model:" . Dumper($model) );
  Su::Log->trace( "defs:" . Dumper($defs) );

  $DEFS_DIR                   = $defs     if $defs;
  $Su::Template::TEMPLATE_DIR = $template if $template;
  $Su::Model::MODEL_DIR       = $model    if $model;

# If base is specified, then this setting effects to the all modules in Su package.
  if ($base) {
    no warnings qw(once);
    $BASE_DIR                        = $base;
    $Su::Template::TEMPLATE_BASE_DIR = $base;
    $Su::Model::MODEL_BASE_DIR       = $base;
  } ## end if ($base)

  if ( $base || $template || $model || $defs ) {
    $self->export_to_level( 1, $self, @{$imports_aref} );
  } else {

# If '' or '' is not passed, then all of the parameters are required method names.
    $self->export_to_level( 1, $self, @_ );
  }

} ## end sub import

=begin comment

Load the definition file which binds process and model to the single entry.
The default definition file loaded by Su is F<Defs::Defs.pm>.
You can specify the loading definition file as a parameter of this method.

 $su->_load_defs_file();
 $su->_load_defs_file('Defs::CustomDefs');

=end comment

=cut

our $defs_module_name;

sub _load_defs_file {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );

  my $BASE_DIR = $self->{base} ? $self->{base} : $BASE_DIR;
  my $DEFS_DIR = $self->{defs} ? $self->{defs} : $DEFS_DIR;

  # Nothing to do if info is already set or loaded.
  # if ( $info_href && keys %{$info_href} ) {
  #   return;
  # }

  my $defs_mod_name = shift || "Defs::Defs";

  # Defs file tring to load is already loaded.
  if ($self) {
    if ( defined $self->{defs_module_name}
      && $self->{defs_module_name} eq $defs_mod_name )
    {
      return;
    }
  } else {
    if ( defined $defs_module_name && $defs_module_name eq $defs_mod_name ) {
      return;
    }
  }

  # Back up the Defs module name.
  if ($self) {
    $self->{defs_module_name} = $defs_mod_name;
  } else {
    $defs_module_name = $defs_mod_name;
  }

  # my $info_path;
  # if ( $BASE_DIR eq './' ) {
  #   $info_path = $DEFS_DIR . "/" . $DEFS_MOD_NAME . ".pm";
  # } else {
  #   $info_path = $BASE_DIR . "/" . $DEFS_DIR . "/" . $DEFS_MOD_NAME . ".pm";
  # }

  my $proc = Su::Process->new;
  $proc->load_module($defs_mod_name);

  #  require $defs_mod_name;

  if ($self) {
    $self->{defs_href} = $defs_mod_name->defs;
  } else {
    $info_href = $defs_mod_name->defs;
  }
  return $defs_mod_name->defs;

} ## end sub _load_defs_file

=item setup()

Instead of loading the definition form the Definition file, this method set the definition directly.

 Su::setup(
   menu =>{proc=>'MenuTmpl', model=>qw(main sites about)},
   book_comp =>{proc=>'BookTmpl', model=>'MenuModel'},
   menuWithArg =>{proc=>'MenuTmplWithArg', model=>{field1=>{type=>'string'},field2=>{type=>'number'}}},
  );

=cut

sub setup {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );

  if ( ref $_[0] eq 'HASH' ) {
    $info_href = shift;
  } else {
    my %h = @_;
    $info_href = \%h;
  }

} ## end sub setup

=item new()

Instantiate the Su instance.
To make Su instance recognize the custom definition module, you can
pass the package name of the definition file as a parameter.

my $su = Su->new;

my $su = Su->new('Pkg::Defs');

my $su = Su->new(defs_module=>'Pkg::Defs');

=cut

sub new {
  my $self = shift;

  if ( scalar @_ == 1 ) {
    my $defs_id = $_[0];
    my $tmp_ref = \$defs_id;
    if ( ref $tmp_ref eq 'SCALAR' ) {
      return bless { defs_module => $defs_id }, $self;
    }
    croak "invalid new parameter:" . @_;
  } ## end if ( scalar @_ == 1 )
  else {
    my %h = @_;
    return bless \%h, $self;
  }

} ## end sub new

=item resolve()

Find the passed id from the definition file and execute the
corresponding Process after the injection of the corresponding Model to
the Process.

An example of the definition in F<Defs.pm> is like the following.

 my $defs =
   {
    entry_id =>
    {
     proc=>'Pkg::SomeProc',
     model=>'Pkg::SomeModel',
    },
   };

Note that C<proc> field in the definition file is required, but
C<model> field can omit. To execute the process descired in this
example, your code will become like the following.

 my $ret = $su->resolve('entry_id');

If you pass the additional parameters to the resolve method, these
parameters are passed to the C<process> method of the Process.

 my $ret = $su->resolve('entry_id', 'param_A', 'param_B');

If the passed entry id is not defined in Defs file, then the error is thorwn.

Definition can be also specified as a parameter of the C<resolve> method like the following.

   $su->resolve({
     proc=>'MainProc',
     model=>['Model01','Model02','Model03'],
    });

  $su->resolve(
  {
    proc  => 'Sample::Procs::SomeModule',
    model => { key1 => { 'nestkey1' => ['value'] } },
  },
  'arg1',
  'arg2');

B<Optional Usage - Model Definition>

This method works differently according to the style of the model definition.

If the C<model> field is a string, then Su treat it as a name of the Model, load
it's class and set it's C<model> field to the Process.

 some_entry_id =>{proc=>'ProcModule', model=>'ModelModule'},

If the C<model> field is a hash, Su set it's hash to the C<model> field of
the Process directly.

 some_entry_id =>{proc=>'ProcModule', model=>{key1=>'value1',key2=>'value2'}},

If the C<model> field is a reference of the string array, then Su load each
element as Model module and execute Process with each model.

 some_entry_id =>{proc=>'TmplModule', model=>['ModelA', 'ModelB', 'ModelC']},

In this case, Process is executed with each Model, and the array of
each result is returned.

B<Optional Usage - Filters>

If a definition has any filter related fields, then these filter
methods are applied before Su return the result of the process method.
The module specified as a filter must has the method which corresponds
to the filter type.  About usable filter types, see the section of
C<map_filter>, C<reduce_filter>, C<scalar_filter>.

These filter methods receive the result of the process or previous
filter as a parameter, and return the filtered result to the caller or
next filter.

Following is an example of the definition file to use post filter.

 my $defs =
   {
    exec_post_filter =>
    {
     proc=>'MainProc',
     model=>['Model01','Model02','Model03'],
     post_filter=>'FilterProc'
    },

Multiple filters can be set to the definition file.

    exec_post_filter_chain =>
    {
     proc=>'MainProc',
     model=>['Model01','Model02','Model03'],
     post_filter=>['FilterProc1', 'FilterProc1']
    }
   };

An example of the C<map_filter> method in the filter class is the following.
The C<map_filter> receives an array of previous result as a parameter and
return the result as an array.

 sub map_filter {
   my $self = shift if ref $_[0] eq __PACKAGE__;
   my @results = @_;
 
   for (@results) {
     # Do some filter process.
   }
   return @results;
 }

An example of the C<reduce_filter> method in the filter class is the
following.  The C<reduce_filter> receives an array as a parameter and
return the result as a scalar.

 sub reduce_filter {
   my $self = shift if ref $_[0] eq __PACKAGE__;
   my @results = @_;
 
   # For example, just join the result and return.
   return join( ',', @results );
 }

An example of the C<scalar_filter> method in the filter class is the
following.  The C<scalar_filter> receives a scalar as a parameter and
return the result as a scalar.

 sub scalar_filter {
   my $self = shift if ref $_[0] eq __PACKAGE__;
   my $result = shift;
 
 # Do some filter process to the $result.
  
   return $result;
 }

=cut

sub resolve {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );

  my $comp_id = shift;
  my @ctx     = @_;

  if ($self) {

    # If hash is passed, just use passed info, and not load defs file.
    $self->_load_defs_file( $self->{defs_module} )
      unless ref $comp_id eq 'HASH';
  } else {
    _load_defs_file();
  }

# If Su->{base} is specified, this effects to Template and Model, else used own value Template and Model has.
  my $BASE_DIR = $self->{base};
  my $MODEL_DIR = $self->{model} ? $self->{model} : $Su::Model::MODEL_DIR;
  my $TEMPLATE_DIR =
    $self->{template} ? $self->{template} : $Su::Template::TEMPLATE_DIR;
  my $info_href;

  #  $info_href = $self->{defs_href} ? $self->{defs_href} : $Su::info_href;

  # If defs info is passed as paramter, then use it.
  if ( ref $comp_id eq 'HASH' ) {
    $info_href = { 'dmy_id' => $comp_id };

    # Set dummy id to use passed parameter.
    $comp_id = 'dmy_id';
  } else {
    $info_href = $self->{defs_href} ? $self->{defs_href} : $Su::info_href;
  }

  #  if(is_hash_empty($info_href->{$comp_id})){
  if (
    !$info_href->{$comp_id}
    || !(
      ref $info_href->{$comp_id} eq 'HASH' && keys %{ $info_href->{$comp_id} }
    )
    )
  {

    croak "Entry id '$comp_id' is  not found in Defs file:"
      . Dumper($info_href);

    #return undef;
  } ## end if ( !$info_href->{$comp_id...})

  my $proc = Su::Process->new( base => $BASE_DIR, dir => $TEMPLATE_DIR );
  my $proc_id = $info_href->{$comp_id}->{proc};
  croak 'proc not set in '
    . (
      $self->{defs_module_name}
    ? $self->{defs_module_name} . ":${comp_id}"
    : 'the passed definition'
    )
    . '.'
    unless $proc_id;
  my $tmpl_module = $proc->load_module($proc_id);

  # Save executed module to the instance.
  $self->{module} = $tmpl_module if $self;

  my @ret_arr = ();

  # Still not refactored!

  # If the setter method of the field 'model' exists.
  if ( $tmpl_module->can('model') ) {

    # model is hash reference. so pass it direct.
    if ( ref $info_href->{$comp_id}->{model} eq 'HASH' ) {
      $tmpl_module->model( $info_href->{$comp_id}->{model} );
    } elsif ( ref $info_href->{$comp_id}->{model} eq 'ARRAY' ) {

      # Call module method with each of models.
      my $mdl = Su::Model->new( base => $BASE_DIR, dir => $MODEL_DIR );

      for my $loaded_model ( @{ $info_href->{$comp_id}->{model} } ) {

        #diag("model:" . $info_href->{$comp_id}->{model});
        #diag("loaded:" . $mdl->load_model($info_href->{$comp_id}->{model}));
        chomp $loaded_model;
        if ($loaded_model) {
          $tmpl_module->model( $mdl->load_model($loaded_model) );
          push @ret_arr, $tmpl_module->process(@ctx);
        }
      } ## end for my $loaded_model ( ...)

    } else {

      # this should be model class name.

      my $mdl = Su::Model->new( base => $BASE_DIR, dir => $MODEL_DIR );
      my $loading_model = $info_href->{$comp_id}->{model};
      chomp $loading_model;
      if ($loading_model) {

        $tmpl_module->model( $mdl->load_model($loading_model) );

      }
    } ## end else [ if ( ref $info_href->{...})]
  } ## end if ( $tmpl_module->can...)

  my @filters = ();
  my $reduce_filter;
  my @scalar_filters = ();

  # Collect post filters.
  if ( $info_href->{$comp_id}->{map_filter} ) {

    # The single filter is set as class name string.
    if ( ref $info_href->{$comp_id}->{map_filter} eq '' ) {
      push @filters, $info_href->{$comp_id}->{map_filter};
    } elsif ( ref $info_href->{$comp_id}->{map_filter} eq 'ARRAY' ) {

      # The filters are set as array reference.
      @filters = @{ $info_href->{$comp_id}->{map_filter} };
    }

  } ## end if ( $info_href->{$comp_id...})

  # Collect reduce filter.
  # Note:Multiple reduce filter not permitted to set.
  if ( $info_href->{$comp_id}->{reduce_filter} ) {

    # The single filter is set as class name string.
    if ( ref $info_href->{$comp_id}->{reduce_filter} eq '' ) {
      $reduce_filter = $info_href->{$comp_id}->{reduce_filter};
    }
  } ## end if ( $info_href->{$comp_id...})

  # Collect scalar filters
  if ( $info_href->{$comp_id}->{scalar_filter} ) {

    # The single filter is set as class name string.
    if ( ref $info_href->{$comp_id}->{scalar_filter} eq '' ) {
      push @scalar_filters, $info_href->{$comp_id}->{scalar_filter};
    } elsif ( ref $info_href->{$comp_id}->{scalar_filter} eq 'ARRAY' ) {

      # The filters are set as array reference.
      @scalar_filters = $info_href->{$comp_id}->{scalar_filter};
    }

  } ## end if ( $info_href->{$comp_id...})

  # Multiple data process return it's result array.
  if (@ret_arr) {
    for my $elm (@filters) {
      my $tmpl_filter_module =
        $proc->load_module( $info_href->{$comp_id}->{map_filter} );
      @ret_arr = $tmpl_filter_module->map_filter(@ret_arr);
    }

#Todo: Multiple data process not implemented to apply reduce filter and scalar filter.
    return @ret_arr;
  } ## end if (@ret_arr)

  my @single_ret_arr = ( $tmpl_module->process(@ctx) );

  # Apply map filters.
  for my $elm (@filters) {
    my $tmpl_filter_module = $proc->load_module($elm);
    @single_ret_arr = $tmpl_filter_module->map_filter(@single_ret_arr);
  }

  return ( scalar @single_ret_arr == 1 ? $single_ret_arr[0] : @single_ret_arr )
    unless ( $reduce_filter or @scalar_filters );

  my $reduced_result = '';

  # Apply reduce filter once.
  if ($reduce_filter) {
    my $reduce_filter_module = $proc->load_module($reduce_filter);
    $reduced_result = $reduce_filter_module->reduce_filter(@single_ret_arr);
  } elsif ( scalar @single_ret_arr == 1 ) {
    $reduced_result = $single_ret_arr[0];
  } else {
    croak
"[ERROR]Can't apply scalar filter(s), because the result of the process is multiple and not reduced by the reduce filter";
  }

  #Apply scalar filter to the single process result.
  for my $elm (@scalar_filters) {
    my $tmpl_filter_module = $proc->load_module($elm);
    $reduced_result = $tmpl_filter_module->scalar_filter($reduced_result);
  }
  return $reduced_result;

} ## end sub resolve

=item init()

Generate the initial files at once. The initial files are composed of
Defs, Model and Process module.

 Su::init('PkgName');

=cut

sub init {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $pkg = shift;

# Note that the package of defs file is fixed and don't reflect the passed package name.
  no warnings qw(once);
  if ($self) {

# The method 'init' use the fixed module and method name. Only the package name can be specified.
    $self->gen_defs( package => $pkg );
    $self->gen_model("${pkg}::${DEFAULT_MODEL_NAME}");
    $self->gen_proc("${pkg}::${DEFAULT_PROC_NAME}");
  } else {
    gen_defs( package => $pkg );
    gen_model("${pkg}::Model");
    gen_proc("${pkg}::MainProc");

  } ## end else [ if ($self) ]

} ## end sub init

=item gen_model()

Generate a Model file.

 Su::gen_model("SomePkg::SomeModelName")

 perl -MSu=base,./lib/ -e 'Su::gen_model("Pkg::ModelName")'

=cut

sub gen_model {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $BASE_DIR = $self->{base} ? $self->{base} : $BASE_DIR;
  my $mdl = Su::Model->new( base => $BASE_DIR );
  $mdl->generate_model(@_);

} ## end sub gen_model

=item gen_proc()

Generate a Process file.

 perl -MSu=base,./lib/ -e 'Su::gen_proc("Pkg::TestProc")'

=cut

sub gen_proc {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $BASE_DIR = $self->{base} ? $self->{base} : $BASE_DIR;
  my $proc = Su::Process->new( base => $BASE_DIR );
  $proc->generate_proc(@_);

} ## end sub gen_proc

=item gen_defs()

Generate a definition file.

 perl -MSu=base,./lib/ -e 'Su::gen_defs()'

You can specify the package name of the definition file as a parameter.

 gen_defs('Defs::Defs')

Also you can specify other parameters as hash.

 gen_defs(name=>'Defs::Defs',package=>'pkg', proc=>'MyProc',model=>'MyModel')

=cut

sub gen_defs {
  my $self = shift if ( ref $_[0] eq __PACKAGE__ );
  my $defs_id;
  my %defs_h;

  # The single parameter is Defs file name.
  if ( scalar @_ == 1 ) {
    $defs_id = shift || $DEFS_MODULE_NAME;
  } else {

    # Else the hash of parameters.
    %defs_h = @_;

    $defs_id = $defs_h{name} || $defs_h{file_name} || $DEFS_MODULE_NAME;

  } ## end else [ if ( scalar @_ == 1 ) ]

  my $BASE_DIR = $self->{base} ? $self->{base} : $BASE_DIR;
  my $DEFS_DIR = $self->{defs} ? $self->{defs} : $DEFS_DIR;

  # Make directory path.
  my @arr = split( '/|::', $defs_id );
  my $defs_base_name = '';
  if ( scalar @arr > 1 ) {
    $defs_base_name = join( '/', @arr[ 0 .. scalar @arr - 2 ] );
  }

  my $dir;
  if ( $defs_id =~ /::|\// ) {
    $dir = $BASE_DIR . "/" . $defs_base_name;
  } else {
    $dir = $BASE_DIR . "/" . $DEFS_DIR . "/" . $defs_base_name;
  }

  # Prepare directory for generate file.
  mkpath $dir unless ( -d $dir );

  if ( !-d $dir ) {
    die "Can't make dir:" . $!;
  }

  my $defs_id_filepath = $defs_id;
  $defs_id_filepath =~ s!::!/!g;

  # Generate file.
  my $fpath;
  if ( $defs_id =~ /::|\// ) {
    $fpath = $BASE_DIR . "/" . $defs_id_filepath . ".pm";
  } else {
    $fpath = $BASE_DIR . "/" . $DEFS_DIR . "/" . $defs_id_filepath . ".pm";
  }

  $defs_id =~ s/\//::/g;

  if ( $defs_id !~ /::/ ) {
    my $defs_dir_for_package = $DEFS_DIR;
    $defs_dir_for_package =~ s!/!::!g;

    #Note: Automatically add the default package Models.
    $defs_id = $defs_dir_for_package . '::' . $defs_id;
  } ## end if ( $defs_id !~ /::/ )

  open( my $file, '>', $fpath );

  my $ft = Su::Template->new;

  my $defs_proc_name  = $defs_h{proc}    || $DEFAULT_PROC_NAME;
  my $defs_model_name = $defs_h{model}   || $DEFAULT_MODEL_NAME;
  my $pkg             = $defs_h{package} || $defs_h{pkg};
  use Data::Dumper;

  # Make package name, else remain empty.
  $pkg = $pkg ? ( $pkg . '::' ) : '';

  my $contents = $ft->expand(
    <<'__TMPL__', $defs_id, $pkg, $defs_proc_name, $defs_model_name );
% my $defs_pkg = shift;
% my $pkg = shift;
% my $proc = shift;
% my $model = shift;
package <%=$defs_pkg%>;
use strict;
use warnings;

my $defs =
  {
   main =>
   {
    proc=>"<%="${pkg}${proc}"~%>",
    model=>"<%="${pkg}${model}"~%>",
   },
#   comp_id2 =>
#   {
#    proc=>'MainProc',
#    model=>['Model01','Model02','Model03'],
#    map_filter=>'FilterProc'    # or ['Filter01','Filter02']
#    reduce_filter=>'ReduceProc'  # reduce filter can apply at once.
#    scalar_filter=>'ScalarProc'  # or ['Filter01','Filter02']
#   }
  };

sub defs{
  shift if ($_[0] eq __PACKAGE__);

  my $arg = shift;
  if ($arg){
    $defs = $arg;
  }else{
    return $defs;
  }
}
__TMPL__

  print $file $contents;

} ## end sub gen_defs

=begin comment

Return 1 if passed argument is reference of empty hash.
Note that if argument type is not reference, then return 1;
Non-hash type parameter also return 1.

Note: Currently not used.

=end comment

=cut

# sub is_hash_empty {
#   my $self = shift if ( ref $_[0] eq __PACKAGE__ );
#   my $href = shift;
#   return 1 if ( !$href );
#   if ( ref $href eq 'HASH' ) {
#     if ( keys %{$href} ) {
#       return 0;
#     } else {
#       return 1;
#     }
#   } ## end if ( ref $href eq 'HASH')
#   return 1;
# } ## end sub is_hash_empty

1;

__END__

=back

=head1 SEE ALSO

L<Su::Process|Su::Process>,L<Su::Model|Su::Model>,L<Su::Template|Su::Template>,L<Su::Log|Su::Log>

=head1 AUTHOR

lottz <lottzaddr@gmail.com>

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


