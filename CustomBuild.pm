#!usr/bin/perl
package CustomBuild;

use strict;
use warnings;
use Fatal qw(open);
use Data::Dumper;
use File::Copy;
use base 'Module::Build';
use Config;
our $VERSION = "0.4";

=pod

=head1 NAME

CustomBuild - The custom build class.

=head1 SYNOPSYS

=head1 DESCRIPTION

The custom build class.

=head1 ACTIONS

=over

=cut

=item ACTION_list

List up the custom actions.

=cut

sub ACTION_list {

  print "Action entries:\n";
  my $pkg_name = __PACKAGE__;
  $pkg_name =~ s/::/\//;
  open( my $f, "<", $pkg_name . ".pm" );
  for (<$f>) {
    if ( $_ =~ /sub ACTION_([a-zA-Z0-9_]+?)\s*{/ ) {
      print $1 . "\n";
    }
  }
} ## end sub ACTION_list

sub ACTION_add_changes {

  # Get the latest tag version from `git tag` command.
  open my $IN, "git tag|";
  my @tag = <$IN>;
  @tag = sort { $b <=> $a } @tag;
  my $tag_version = $tag[0] || '';
  $tag_version =~ s/(\r|\n)//g if $tag_version;

##  print @tag;

  # Get the latest tag version from the Changes file.
  my $changes_f       = "Changes";
  my $changes_version = '';
  open( my $F, '<', $changes_f );
  while ( my $line = <$F> ) {

    $line =~ s/(\r|\n)//g;

    ## print "[trace] line:$line\n";

    #    if ( $line =~ /^(\d+\.\d+)$/ ) { print "match:" . $1 . "\n" }
    if ( $line =~ /^(\d+\.\d+)$/ ) {
      $changes_version = $1;
      last;
    }
  } ## end while ( my $line = <$F> )
  close $F;

  # Get the source version via ShipIt.
  my $source_ver;
  {
    require ShipIt;
    my $SHIP_CONF_FILE = ".shipit";
    my $conf           = ShipIt::Conf->parse($SHIP_CONF_FILE);
    my $state          = ShipIt::State->new($conf);
    $source_ver = $state->pt->current_version;
  }

  print "changes_version:$changes_version\n";
  print "tag_version:$tag_version\n";
  print "source_version:$source_ver\n";

  die
"[ERROR]The version number in the projcet source and git tag is the same. Increment source version."
    if ( $tag_version && $source_ver == $tag_version );

# Note that if both has the same verion, it's ok. Because repository may has some not tagged changes.
  die
"[ERROR]The version number in the Changes is larger than the tag in repostory. So nothing to add to the Changes."
    if ( $tag_version && $changes_version > $tag_version );

  die
"[ERROR]The tag version in Changes not exist in the git tags. Changes mey be already updated by you manually."
    if ( @tag && $changes_version && not grep /$changes_version/, @tag );

  # Get the log from `git log` command to add to the Changes file.
  # Make sure the date format is iso.

  my @log = $changes_version
    ? `git log --date=iso $changes_version..HEAD`

    # If the tag is not exist, then collect all logs.
    : `git log --date=iso`;

  my @to_add;
  for my $line (@log) {
    if ( $line =~ /^(commit|Author:)/ ) {    # Ignore commit id and Author.
    } elsif ( $line =~ /^\n$/ ) {            # Ignore empty line.
    } else {
      push @to_add, $line;
    }
  } ## end for my $line (@log)

  ## print Dumper(@to_add);

  die "[ERROR]log contents are empty." unless @to_add;

  move( 'Changes', 'Changes.bak' );

  open( my $Changes_fh, '>', 'Changes' );
  print $Changes_fh "$source_ver\n";
  print $Changes_fh join( "", @to_add );
  close $Changes_fh;

  # Add old entries to the new Changes.
  `echo "" >> Changes`;
  `cat Changes.bak >> Changes`;

} ## end sub ACTION_add_changes

sub ACTION_refresh_modules {

  # Not implemented.
}

sub ACTION_stage {
  my $self = shift;

  # Not implemented.
}

=begin comment

This method is called instead of constructor.

=end comment

=cut

sub resume {
  my $self = shift;
  no warnings qw(once);
  no strict 'refs';
  no warnings 'redefine';

  # *CustomBuild::ACTION_hoge = sub {
  #   print "action hoge\n";
  # };

  my $obj = $self->SUPER::resume;

  #  print Dumper( $obj->{args} );
  #  print Dumper( $obj->{config} );
  #  print Dumper( $obj->{properties} );

  # Get defined test_types.
  my $tests = $obj->{properties}->{test_types};

  # Register the test hander.
  foreach my $key ( sort keys %{$tests} ) {

    *{"CustomBuild::ACTION_test${key}"} = sub {
      shift->generic_test( type => "${key}" );
    };
  } ## end foreach my $key ( sort keys...)

  # Register the shipit scenarios..
  foreach my $ship_file ( glob '.shipit_*' ) {
    require ShipIt;
    my $kind = $ship_file;
    $kind =~ s/\.shipit_(.+)/$1/;

    *{"CustomBuild::ACTION_shipit_${kind}"} = sub {

      my $SHIP_CONF_FILE = $ship_file;
      print "ship file:" . $SHIP_CONF_FILE . "\n";
      my $conf  = ShipIt::Conf->parse($SHIP_CONF_FILE);
      my $state = ShipIt::State->new($conf);
      foreach my $step ( $conf->steps ) {
        warn "Running step $step\n";
        $step->run($state);
      }

    };
  } ## end foreach my $ship_file ( glob...)

  return $obj;
} ## end sub resume

sub ACTION_check_pod {
  my $self  = shift;
  my @files = `find lib -type f -name "*.pm"`;

  #print Dumper(@files);

  for my $elm (@files) {
    chomp $elm;

    #    print $elm . "\n";
    open my $f, '<', $elm;
    my $txt = join '', <$f>;

    #    print $txt;

    # Check missing empty line before a section.
    while ( $txt =~ /[^\n]\n(=head\d|=item\s*\w*|=cut|=over|=back|=over)/g ) {

      my $show_txt   = $` . $&;
      my @show_lines = split "\n", $show_txt;
      my $line_num   = scalar @show_lines;
      @show_lines = @show_lines[ $#show_lines - 10 ... $#show_lines ];

      #      @show_lines = grep { $_ } @show_lines;
      print "\n[ERROR]no empty line:at $elm L$line_num\n"
        . join( "\n", @show_lines )
        . "          <---------\n";
    } ## end while ( $txt =~ ...)

    while (
      $txt =~ /\n(=head\d|=item\s*\w*|=cut|=over|=back|=over)[^\n]*?\n[^\n]/g )
    {

      my $show_txt   = $` . $&;
      my $all_txt    = $` . $& . $';
      my @show_lines = split "\n", $show_txt;
      my @all_lines  = split "\n", $all_txt;
      my $line_num   = scalar @show_lines;
      @show_lines =
        grep { defined $_ }
        @all_lines[ $#show_lines - 10 ... $#show_lines + 5 ];

      #      @show_lines = grep { $_ } @show_lines;
      print "\n[ERROR]no empty line:before $elm L$line_num\n"

        #        . join( "\n", @show_lines )
        . join(
        "\n",
        (
          @show_lines[ 0 .. $#show_lines - 6 ],
          $show_lines[ $#show_lines - 5 ] . "          <---------\n",
          @show_lines[ $#show_lines - 4 .. $#show_lines ],
          "\n"
        )
        );
    } ## end while ( $txt =~ ...)

    # Check excessive empty lines before a section.
    while ( $txt =~ /\n{3,}(=head\d)/g ) {
      my $show_txt   = $` . $&;
      my @show_lines = split "\n", $show_txt;
      my $line_num   = scalar @show_lines;
      @show_lines = @show_lines[ $#show_lines - 10 ... $#show_lines ];

      #      @show_lines = grep { $_ } @show_lines;
      print "\n[ERROR]more than 2 empty line::at $elm L$line_num\n"
        . join( "\n", @show_lines )
        . "          <---------\n";
    } ## end while ( $txt =~ /\n{3,}(=head\d)/g)

    # Check whether empty line is exit before the source section.
    my $prev_line = '';
    while (
      $txt =~

/\n(?:=head\d*[a-zA-Z() ]*|=item[\s\w_($)]*(?=\n))(.+?)(?:=cut|=over|=back|=over)/sg

 # /\n(?:=head\d*[a-zA-Z() ]*|=item[\s\w_()]*)(.+?)(?:=cut|=over|=back|=over)/sg
      )
    {

      # print "begin\n";
      my @lines = split( /\n/, $1 );
      my $b_code_block = 0;
      my $line_num;
      for my $line (@lines) {
        ++$line_num;
        $line =~ tr/\r//;

        # print "match:$elm\n";
        # print "line:$line:block:$b_code_block\n";

        if ( !$b_code_block && $line =~ /^\s.+/ && $prev_line ne '' ) {
          print "\n[ERROR] not empty line before source part.$elm L$line_num\n";
          print "$prev_line\n$line\n";
          $b_code_block = 1;
        } elsif ( !$b_code_block && $line =~ /^\s.+/ ) {
          $b_code_block = 1;
        } elsif ( $b_code_block
          && $line =~ /^[^\s].+/ )

          # && $prev_line =~ /^\s.+/ )
        {
          $b_code_block = 0;
        } ## end elsif ( $b_code_block && ...)

        $prev_line = $line;
      } ## end for my $line (@lines)
          # print "end\n";
    } ## end while ( $txt =~...)

  } ## end for my $elm (@files)

} ## end sub ACTION_check_pod

sub ACTION_uninstall {
  my $self        = shift;
  my $module_path = $self->{properties}->{module_name};
  $module_path =~ s!::!/!g;
  my $packlist_file =
    $Config{sitearchexp} . "/auto/" . $module_path . "/.packlist";

  die ".packlist file not found. $packlist_file" unless -e $packlist_file;

  open( my $F, '<', $packlist_file );
  while ( my $line = <$F> ) {

    $line =~ s/(\r|\n)//g;
    print "[INFO]Deleting: " . $line . "\n";
    unlink $line or die "[ERROR]Can not delete file:" . $line . ":$!";

  } ## end while ( my $line = <$F> )

  print "[INFO]Deleting: " . $packlist_file . "\n";
  unlink $packlist_file
    or die "[ERROR]Can not delete file:" . $packlist_file . ":$!";

} ## end sub ACTION_uninstall

# Just list up the install files.
sub ACTION_fakeuninstall {
  my $self        = shift;
  my $module_path = $self->{properties}->{module_name};
  $module_path =~ s!::!/!g;
  my $packlist_file =
    $Config{sitearchexp} . "/auto/" . $module_path . "/.packlist";

  die ".packlist file not found. $packlist_file" unless -e $packlist_file;

  open( my $F, '<', $packlist_file );
  print join( '', <$F> );

} ## end sub ACTION_fakeuninstall

1;

