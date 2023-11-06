#!/usr/bin/perl -I/home/phil/perl/cpan/SvgSimple/lib/ -I/home/phil/perl/cpan/SiliconChip/lib/
#-------------------------------------------------------------------------------
# Implement a B-Tree as a silicon chip.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
use v5.34;
package Silicon::Chip;
our $VERSION = 20231101;                                                        # Version
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Silicon::Chip     qw(:all);

makeDieConfess;

#D1 Btree Node                                                                  # A node in a B-Tree containing keys, data and links to other nodes. Nodes only produce output when their preset id is present on their enable bus.  This makes it possible for one node to select another node for further processing of the key being sought.

sub newBtreeNode($$$$$$$$$$$%)                                                  # Create a new B-Tree node. The node is activated only when its preset id appears on its enable bus otherwise it produces zeroes regardless of its inputs.
 {my ($chip, $id, $enable, $output, $find, $keys, $data, $next, $top, $N, $B, %options) = @_; # Chip, numeric id of this node, enable bus, output name, key to find, keys to search, data corresponding to keys, next links, top next link, maximum number of keys in a node, size of key in bits, options
  @_ >= 11 or confess "Eleven or more parameters";

  my @B = ($N, $B);
  my $O = $output;
  my $C = $chip;

  my sub id() {"$O.id"}                                                         #i Id for this node
  my sub en() {"$O.enabled"}                                                    #i Enable code
  my sub pe() {"$O.maskEqual"}                                                  #i Point mask showing key equal to search key
  my sub mm() {"$O.maskMore"}                                                   #i Monotone mask showing keys more than the search key
  my sub df() {"$O.dataFound"}     my sub dF() {"$O.DataFound"}                 #O The data corresponding to the key found or zero if not found
  my sub  f() {"$O.found"}         my sub F() {"$O.Found"}                      #O Whether a matching key was found
  my sub mf() {"$O.moreFound"}                                                  #i The next link for the first key greater than the search key is such a key is present int the node
  my sub nm() {"$O.noMore"}                                                     #i No key in the node is greater than the search key
  my sub nf() {"$O.nextLink"}      my sub nF() {"$O.NextLink"}                  #O The next link for the found key if any
  my sub pm() {"$O.pointMore"}                                                  #i Point mask showing the first key in the node greater than the search key

  $N > 2 or confess <<"END";
The number of keys the node can hold must be greater than 2, not $N
END

  $N % 2 or confess <<"END";
The number of keys the node can hold must be odd, not even: $N
END
  $C->bits(id, $B, $id);                                                        # Save id of node
  $C->compareEq(en, id, $enable, $B, %options);                                 # Check whether this node is enabled

  for my $i(1..$N)
   {$C->compareEq(n(pe, $i), n($keys, $i), $find, $B, %options);                # Compare equal point mask
    $C->compareGt(n(mm, $i), n($keys, $i), $find, $B, %options);                # Compare more  monotone mask
   }

  $C->chooseWordUnderMask(dF, $data, pe,          @B, %options);                # Choose data under equals mask
  $C->orBits             (F,         pe,          $B, %options);                # Show whether key was found

  $C->norBits            (nm, mm,                 $N, %options);                # True if the more monotone mask is all zero indicating that all of the keys in the node are less than or equal to the search key
  $C->monotoneMaskToPointMask(pm, mm,             $N, %options);                # Convert monotone more mask to point mask
  $C->chooseWordUnderMask(mf, $next, pm,          @B, %options);                # Choose next link using point mask from the more monotone mask created
  $C->chooseFromTwoWords (nF, mf, $top, nm,       $B, %options);                # Show whether key was found

  $C->enableWord(df, dF, en,                      $B, %options);                # Enable data found
  $C->and       ( f, [F, en]);                                                  # Enable found flag
  $C->enableWord(nf, nF, en,                      $B, %options);                # Enable next link
  $C
 }

=pod

=encoding utf-8

=for html <p><a href="https://github.com/philiprbrenan/SiliconChipBtree"><img src="https://github.com/philiprbrenan/SiliconChipBtree/workflows/Test/badge.svg"></a>

=head1 Name

Silicon::Chip::Btree - Implement a B-Tree as a silicon chip.

=head1 Synopsis

=head1 Description

Implement a B-Tree as a silicon chip.


Version 20231101.


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 Btree Node

A node in a B-Tree containing keys, data and links to other nodes. Nodes only produce output when their preset id is present on their enable bus.  This makes it possible for one node to select another node for further processing of the key being sought.

=head2 newBtreeNode($chip, $id, $enable, $output, $find, $keys, $data, $next, $top, $N, $B, %options)

Create a new B-Tree node. The node is activated only when its preset id appears on its enable bus otherwise it produces zeroes regardless of its inputs.

      Parameter  Description
   1  $chip      Chip
   2  $id        Numeric id of this node
   3  $enable    Enable bus
   4  $output    Output name
   5  $find      Key to find
   6  $keys      Keys to search
   7  $data      Data corresponding to keys
   8  $next      Next links
   9  $top       Top next link
  10  $N         Maximum number of keys in a node
  11  $B         Size of key in bits
  12  %options   Options

B<Example:>


  if (1)
   {my $B = 3; my $N = 3; my $id = 5;

    my $c = Silicon::Chip::newChip;

       $c->inputBits ("enable",   $B);                                            # Enable - the node only operates if this value matches its preset id
       $c->inputBits ("find",     $B);                                            # Key to search for
       $c->inputWords("keys", $N, $B);                                            # Keys to search
       $c->inputWords("data", $N, $B);                                            # Data associated with each key
       $c->inputWords("next", $N, $B);                                            # Next node associated with each key
       $c->inputBits ("top",      $B);                                            # Top next node


       $c->newBtreeNode($id, qw(enable out find keys data next top), $N, $B);     # B-Tree node  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


       $c->output    ("found",     "out.found");                                  # Results returned from B-Tree node
       $c->outputBits("dataFound", "out.dataFound", $B);
       $c->outputBits("nextLink",  "out.nextLink",  $B);

    my sub test($)                                                                # Find keys in a node
     {my ($f) = @_;

      my %e = setBits ("enable",     $B,    $id);
      my %f = setBits ("find",       $B,    $f);
      my %t = setBits ("top",        $B,    $N+1);
      my %k = setWords("keys",   $N, $B, 1..$N);
      my %d = setWords("data",   $N, $B, 1..$N);
      my %n = setWords("next",   $N, $B, 1..$N);
      my $i = {%e, %f, %k, %d, %n, %t};
      my $s = $c->simulate($i, $f == 2 ? (svg=>q(svg/btreeNode)) : ());

      is_deeply($s->steps, 11);
      is_deeply($s->values->{found}, $f >= 1 && $f <= $N ? 1 : 0);
      is_deeply($s->bitsToInteger("dataFound", $B), $f <= $N ? $f : 0);
      is_deeply($s->bitsToInteger("nextLink",  $B), $f <= $N ? $f+1 : $N+1);
     }
    test($_) for 0..$N+1;

    my sub test2($)                                                               # Find and not find keys in a node
     {my ($f) = @_;

      my %e = setBits ("enable",   $B,     $id);
      my %f = setBits ("find",     $B,     $f);
      my %t = setBits ("top",      $B,   2*$N+1);
      my %k = setWords("keys", $N, $B, map {2*$_}   1..$N);
      my %d = setWords("data", $N, $B,              1..$N);
      my %n = setWords("next", $N, $B, map {2*$_-1} 1..$N);
      my $i = {%e, %f, %k, %d, %n, %t};
      my $s = $c->simulate($i, $f == 2 ? (svg=>q(svg/btreeNode)) : ());

      is_deeply($s->steps, 11);
      is_deeply($s->values->{found},                $f == 0 || $f % 2 ? 0 : 1);
      is_deeply($s->bitsToInteger("dataFound", $B), $f % 2 ? 0 : $f / 2);
      is_deeply($s->bitsToInteger("nextLink",  $B), $f + ($f % 2 ? 0 : 1)) if $f <= 2*$N ;
     }
    test2($_) for 0..2*$N+1;

    my sub test3($)                                                               # Not enabled so only ever outputs 0
     {my ($f) = @_;

      my %e = setBits ("enable",   $B,     $id+1);
      my %f = setBits ("find",     $B,     $f);
      my %t = setBits ("top",      $B,   2*$N+1);
      my %k = setWords("keys", $N, $B, map {2*$_}   1..$N);
      my %d = setWords("data", $N, $B,              1..$N);
      my %n = setWords("next", $N, $B, map {2*$_-1} 1..$N);
      my $i = {%e, %f, %k, %d, %n, %t};
      my $s = $c->simulate($i, $f == 2 ? (svg=>q(svg/btreeNode)) : ());

      is_deeply($s->steps, 11);
      is_deeply($s->values->{found},                0);
      is_deeply($s->bitsToInteger("dataFound", $B), 0);
      is_deeply($s->bitsToInteger("nextLink",  $B), 0);
     }
    test3($_) for 0..2*$N+1;
   }


=for html <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipBtree/main/lib/Silicon/Chip/svg/btreeNode.svg">



=head1 Index


1 L<newBtreeNode|/newBtreeNode> - Create a new B-Tree node.

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Silicon::Chip

=head1 Author

L<philiprbrenan@gmail.com|mailto:philiprbrenan@gmail.com>

L<http://www.appaapps.com|http://www.appaapps.com>

=head1 Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.

=cut



#D0 Tests                                                                       # Tests and examples
goto finish if caller;                                                          # Skip testing if we are being called as a module
clearFolder(q(svg), 99);                                                        # Clear the output svg folder
eval "use Test::More qw(no_plan);";
eval "Test::More->builder->output('/dev/null');" if -e q(/home/phil2/);
eval {goto latest};

#svg https://raw.githubusercontent.com/philiprbrenan/SiliconChipBtree/main/lib/Silicon/Chip/

#latest:;
if (1)                                                                          #TnewBtreeNode
 {my $B = 3; my $N = 3; my $id = 5;

  my $c = Silicon::Chip::newChip;

     $c->inputBits ("enable",   $B);                                            # Enable - the node only operates if this value matches its preset id
     $c->inputBits ("find",     $B);                                            # Key to search for
     $c->inputWords("keys", $N, $B);                                            # Keys to search
     $c->inputWords("data", $N, $B);                                            # Data associated with each key
     $c->inputWords("next", $N, $B);                                            # Next node associated with each key
     $c->inputBits ("top",      $B);                                            # Top next node

     $c->newBtreeNode($id, qw(enable out find keys data next top), $N, $B);     # B-Tree node

     $c->output    ("found",     "out.found");                                  # Results returned from B-Tree node
     $c->outputBits("dataFound", "out.dataFound", $B);
     $c->outputBits("nextLink",  "out.nextLink",  $B);

  my sub test($)                                                                # Find keys in a node
   {my ($f) = @_;

    my %e = setBits ("enable",     $B,    $id);
    my %f = setBits ("find",       $B,    $f);
    my %t = setBits ("top",        $B,    $N+1);
    my %k = setWords("keys",   $N, $B, 1..$N);
    my %d = setWords("data",   $N, $B, 1..$N);
    my %n = setWords("next",   $N, $B, 1..$N);
    my $i = {%e, %f, %k, %d, %n, %t};
    my $s = $c->simulate($i, $f == 2 ? (svg=>q(svg/btreeNode)) : ());

    is_deeply($s->steps, 11);
    is_deeply($s->values->{found}, $f >= 1 && $f <= $N ? 1 : 0);
    is_deeply($s->bitsToInteger("dataFound", $B), $f <= $N ? $f : 0);
    is_deeply($s->bitsToInteger("nextLink",  $B), $f <= $N ? $f+1 : $N+1);
   }
  test($_) for 0..$N+1;

  my sub test2($)                                                               # Find and not find keys in a node
   {my ($f) = @_;

    my %e = setBits ("enable",   $B,     $id);
    my %f = setBits ("find",     $B,     $f);
    my %t = setBits ("top",      $B,   2*$N+1);
    my %k = setWords("keys", $N, $B, map {2*$_}   1..$N);
    my %d = setWords("data", $N, $B,              1..$N);
    my %n = setWords("next", $N, $B, map {2*$_-1} 1..$N);
    my $i = {%e, %f, %k, %d, %n, %t};
    my $s = $c->simulate($i, $f == 2 ? (svg=>q(svg/btreeNode)) : ());

    is_deeply($s->steps, 11);
    is_deeply($s->values->{found},                $f == 0 || $f % 2 ? 0 : 1);
    is_deeply($s->bitsToInteger("dataFound", $B), $f % 2 ? 0 : $f / 2);
    is_deeply($s->bitsToInteger("nextLink",  $B), $f + ($f % 2 ? 0 : 1)) if $f <= 2*$N ;
   }
  test2($_) for 0..2*$N+1;

  my sub test3($)                                                               # Not enabled so only ever outputs 0
   {my ($f) = @_;

    my %e = setBits ("enable",   $B,     $id+1);
    my %f = setBits ("find",     $B,     $f);
    my %t = setBits ("top",      $B,   2*$N+1);
    my %k = setWords("keys", $N, $B, map {2*$_}   1..$N);
    my %d = setWords("data", $N, $B,              1..$N);
    my %n = setWords("next", $N, $B, map {2*$_-1} 1..$N);
    my $i = {%e, %f, %k, %d, %n, %t};
    my $s = $c->simulate($i, $f == 2 ? (svg=>q(svg/btreeNode)) : ());

    is_deeply($s->steps, 11);
    is_deeply($s->values->{found},                0);
    is_deeply($s->bitsToInteger("dataFound", $B), 0);
    is_deeply($s->bitsToInteger("nextLink",  $B), 0);
   }
  test3($_) for 0..2*$N+1;
 }

done_testing();
finish: 1;
