#!/usr/bin/perl -I/home/phil/perl/cpan/SvgSimple/lib/ -I/home/phil/perl/cpan/SiliconChip/lib/ -I/home/phil/perl/cpan/SiliconChipLayout/lib/ -I/home/phil/perl/cpan/SiliconChipWiring/lib/ -I/home/phil/perl/cpan/Math-Intersection-Circle-Line/lib
#-------------------------------------------------------------------------------
# Implement a B-Tree as a silicon chip.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
# Database on a chip: high speed low power database look ups save data center operators money on their electricity bills.
use v5.34;
package Silicon::Chip::Btree;
our $VERSION = 20240331;                                                        # Version
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Silicon::Chip     qw(:all);
use Time::HiRes qw(time);

makeDieConfess;

#D1 B-Tree                                                                      # Create a Btree as a Silicon Chip.

sub newBtreeNodeCompare($$$$$$$$$$$%)                                           # Create a new B-Tree node. The node is activated only when its preset id appears on its enable bus otherwise it produces zeroes regardless of its inputs.
 {my ($chip, $id, $output, $enable, $find, $keys, $data, $next, $top, $N, $B, %options) = @_; # Chip, numeric id of this node, output name, enable bus, key to find, keys to search, data corresponding to keys, next links, top next link, maximum number of keys in a node, size of key in bits, options
  @_ >= 11 or confess "Eleven or more parameters";

  my @B = ($N, $B);
  my sub C {$chip}

  my sub leaf(){$options{leaf}}                                                 # True if the node is a leaf node

  my sub aa($) {my ($n) = @_; "$output.$n"}                                     # Create an internal gate name for this node

  my sub id () {aa "id"}                                                        #i Id for this node
  my sub en () {aa "enabled"}                                                   #i Enable code
  my sub pe () {aa "maskEqual"}                                                 #i Point mask showing key equal to search key
  my sub mm () {aa "maskMore"}                                                  #i Monotone mask showing keys more than the search key
  my sub dfo() {aa "dataFound"}                                                 #O The data corresponding to the key found or zero if not found
  my sub df () {aa "dataFound1"}
  my sub df2() {aa "dataFound2"}
  my sub  fo() {aa "found"}                                                     #O Whether a matching key was found
  my sub  f () {aa "found1"}
  my sub  f2() {aa "found2"}
  my sub mf () {aa "moreFound"}                                                 #i The next link for the first key greater than the search key is such a key is present int the node
  my sub nm () {aa "noMore"}                                                    #i No key in the node is greater than the search key
  my sub nfo() {aa "nextLink"}                                                  #O The next link for the found key if any
  my sub nf () {aa "nextLink1"}
  my sub nf2() {aa "nextLink2"}
  my sub pm () {aa "pointMore"}                                                 #i Point mask showing the first key in the node greater than the search key

  $N > 2 or confess <<"END";
The number of keys the node can hold must be greater than 2, not $N
END

  $N % 2 or confess <<"END";
The number of keys the node can hold must be odd, not even: $N
END

  C->bits(id, $B, $id);                                                         # Save id of node
  C->compareEq(en, id, $enable, %options);                                      # Check whether this node is enabled

  for my $i(1..$N)
   {C->compareEq(n(pe, $i), n($keys, $i), $find, %options);                     # Compare equal point mask
    C->compareGt(n(mm, $i), n($keys, $i), $find, %options) unless leaf;         # Compare more  monotone mask
   }
  C->setSizeBits(pe, $N);
  C->setSizeBits(mm, $N) unless leaf;

  C->chooseWordUnderMask    (df2, $data, pe,         %options);                 # Choose data under equals mask
  C->orBits                 (f2,         pe,         %options);                 # Show whether key was found

  unless(leaf)
   {C->norBits                (nm,  mm,              %options);                 # True if the more monotone mask is all zero indicating that all of the keys in the node are less than or equal to the search key
    C->monotoneMaskToPointMask(pm,  mm,              %options);                 # Convert monotone more mask to point mask
    C->chooseWordUnderMask    (mf,  $next, pm,       %options);                 # Choose next link using point mask from the more monotone mask created
    C->chooseFromTwoWords     (nf2, mf,    $top, nm, %options);                 # Show whether key was found
   }

  C->enableWord               (df,  df2,   en,       %options);                 # Enable data found
  C->outputBits               (dfo, df,              %options);                 # Enable data found output

  C->and                      (f,  [f2,    en]);                                # Enable found flag
  C->output                   (fo,  f,  undef,       %options);                 # Enable found flag output

  unless(leaf)
   {C->enableWord             (nf,  nf2,   en,       %options);                 # Enable next link
    C->outputBits             (nfo, nf,              %options);                 # Enable next link output
   }

  C
 }

my $BtreeNodeIds = 0;                                                           # Create unique ids for nodes

sub newBtreeNode($$$$$%)                                                        # Create a new B-Tree node. The node is activated only when its preset id appears on its enable bus otherwise it produces zeroes regardless of its inputs.
 {my ($chip, $output, $find, $K, $B, %options) = @_;                            # Chip, name prefix for node, key to find, maximum number of keys in a node, size of key in bits, options

  @_ >= 5 or confess "Five or more parameters";
  my sub leaf(){$options{leaf}}                                                 # True if the node is a leaf node

  my $c = $chip;
  my @b = qw(enable);    push @b, q(top)  unless leaf;                          # Leaf nodes do not need the top word which holds the last link
  my @w = qw(keys data); push @w, q(next) unless leaf;                          # Leaf nodes do not need next links
  my @B = qw(found);
  my @W = qw(dataFound nextLink);

  my $id = ++$BtreeNodeIds;                                                     # Node number used to identify the node
  my sub n($)
   {my ($name) = @_;                                                            # Options
    "$output.$id.$name"
   }

  $c->inputBits (n($_),     $B) for @b;                                         # Input bits
  $c->inputWords(n($_), $K, $B) for @w;                                         # Input words

  newBtreeNodeCompare($c, $id,                                                  # B-Tree node
    "$output.$id", n("enable"), $find, n("keys"),
     n("data"), n("next"), n("top"), $K, $B, %options);

  genHash(__PACKAGE__."::Node",                                                 # Node in B-Tree
   (map {($_=>n($_))} @b, @w, @B, @W),
    find => $find,
    chip => $chip,
    id   => $id,
   );
 }

my $BtreeIds = 0;                                                               # Create unique ids for trees

sub newBtree($$$$$$%)                                                           # Create a new B-Tree of a specified name
 {my ($chip, $output, $find, $keys, $levels, $bits, %options) = @_;             # Chip, name, key to find, maximum number of keys in a node, maximum number of levels in the tree, number of bits in a key, options
  @_ >= 5 or confess "Five or more parameters";
  $BtreeIds++;                                                                  # Each tree gets a unique name prefixed by a known label
  $BtreeNodeIds = 0;                                                            # Reset node ids for this tree

  my sub c {$chip}
  my sub o {$output.".".$BtreeIds}
  my sub B {$bits}
  my sub K {$keys}
  my sub aa($) {o.".".$_[0]}                                                    # Create an internal gate name for this node
  my sub f {aa "foundLevel"}                                                    # Find status for a level
  my sub fo{aa "foundOr"}                                                       # Or of finds together
  my sub ff{aa "foundOut"}                                                      # Whether the key was found by any node
  my sub D {aa "dataFoundLevel"}                                                # Data found at this level for matching key if any
  my sub Do{aa "dataFoundOr"}                                                   # Or of all data found words
  my sub DD{aa "dataFoundOut"}                                                  # Data found for key
  my sub L {aa "nextLink"}
  my sub levels {$levels}

  my %n;                                                                        # Nodes in tree
  for my $l(1..levels)                                                          # Create each level of the tree
   {my sub N {($keys+1)**($l-1)}                                                # Number of nodes at this level
    my sub leaf {$l == levels}                                                  # Final level is made of leaf nodes
    my @l = leaf ? (leaf=>1) : ();                                              # Final level is made of leaf nodes
    my @n = undef;                                                              # Start the array at 1

    for my $n(1..N)                                                             # Create the requisite number of nodes for this layer each connected to the key to find
     {push @n, $n{$l}{$n} = newBtreeNode(c, o, $find, K, B, @l);
     }

    c->or(n(f, $l), [map{$n[$_]->found} 1..N]);                                 # Found for this level by or of found for each node

    for my $b(1..B)                                                             # Bits in dataFound and nextLink for this level
     {my $D = [map {n($n[$_]->dataFound, $b)} 1..N];
      my $L = [map {n($n[$_]->nextLink,  $b)} 1..N];
      c->or(nn(D, $l, $b), $D);                                                 # Data found
      c->or(nn(L, $l, $b), $L) unless leaf;                                     # Next link
     }
    c->setSizeBits(n(L, $l), B) unless leaf;                                    # Size of bit bus for next link

    if ($l > 1)                                                                 # Subsequent layers are enabled by previous layers
     {my $nl = n(L, $l-1);                                                      # Next link from previous layer
      for my $n(1..N)                                                          # Each node at this level
       {c->connectInputBits($n{$l}{$n}->enable, $nl);                           # Enable from previous layer
       }
     }
   }

  c->setSizeWords(D, levels, B);                                                # Data found in each level
  c->orWordsX    (Do, D);                                                       # Data found over all layers
  c->outputBits  (DD, Do);                                                      # Data found output

  c->setSizeBits (f, levels);                                                   # Found status on each layer

  c->orBits      (fo, f);                                                       # Or of found status over all layers
  c->output      (ff, fo);                                                      # Found status output

  genHash(__PACKAGE__,                                                          # Node in B-Tree
    chip  => $chip,                                                             # Chip containing tree
    found => ff,                                                                # B<1> if a match was found for the input key otherwise B<0>
    data  => DD,                                                                # Data associated with matched key is any otherwise zeroes
    nodes => \%n,                                                               # Nodes in tree
   )
 }

=pod

=encoding utf-8

=for html <p><a href="https://github.com/philiprbrenan/SiliconChipBtree"><img src="https://github.com/philiprbrenan/SiliconChipBtree/workflows/Test/badge.svg"></a>

=head1 Name

Silicon::Chip::Btree - Implement a B-Tree as a silicon chip.

See:

=for html <p><a href="http://prb.appaapps.com/zesal/pitchdeck/pitchDeck.html">the pitch deck</a>

for the reasons why you might want to get involved with this project.

=head1 Synopsis

=head1 Description

Implement a B-Tree as a silicon chip.


Version 20240331.


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 B-Tree

Create a Btree as a Silicon Chip.

=head2 newBtreeNodeCompare ($chip, $id, $output, $enable, $find, $keys, $data, $next, $top, $N, $B, %options)

Create a new B-Tree node. The node is activated only when its preset id appears on its enable bus otherwise it produces zeroes regardless of its inputs.

      Parameter  Description
   1  $chip      Chip
   2  $id        Numeric id of this node
   3  $output    Output name
   4  $enable    Enable bus
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

    my $c = Silicon::Chip::newChip; my sub c {$c}

       c->inputBits ("enable",   $B);                                             # Enable - the node only operates if this value matches its preset id
       c->inputBits ("find",     $B);                                             # Key to search for
       c->inputWords("keys", $N, $B);                                             # Keys to search
       c->inputWords("data", $N, $B);                                             # Data associated with each key
       c->inputWords("next", $N, $B);                                             # Next node associated with each key
       c->inputBits ("top",      $B);                                             # Top next node


      &newBtreeNodeCompare($c, $id, qw(out enable find keys data next top),$N,$B);# B-Tree node  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    my sub test($)                                                                # Find keys in a node
     {my ($f) = @_;

      my %e = $c->setBits ("enable",    $id);
      my %f = $c->setBits ("find",      $f);
      my %t = $c->setBits ("top",       $N+1);
      my %k = $c->setWords("keys",   1..$N);
      my %d = $c->setWords("data",   1..$N);
      my %n = $c->setWords("next",   1..$N);
      my $i = {%e, %f, %k, %d, %n, %t};
      my $s = $c->simulate($i, $f == 2 ? (svg=>q(btreeNode), pngs=>1) : ());

      is_deeply($s->steps, 14);
      is_deeply($s->value("out.found"),     $f >= 1 && $f <= $N ? 1 : 0);
      is_deeply($s->bInt ("out.dataFound"), $f <= $N ? $f : 0);
      is_deeply($s->bInt ("out.nextLink"),  $f <= $N ? $f+1 : $N+1);
     }
    test($_) for 0..$N+1;

    my sub test2($)                                                               # Find and not find keys in a node
     {my ($f) = @_;

      my %e = setBits ($c, "enable",        $id);
      my %f = setBits ($c, "find",          $f);
      my %t = setBits ($c, "top",         2*$N+1);
      my %k = setWords($c, "keys",   map {2*$_}   1..$N);
      my %d = setWords($c, "data",                1..$N);
      my %n = setWords($c, "next",   map {2*$_-1} 1..$N);
      my $i = {%e, %f, %k, %d, %n, %t};
      my $s = $c->simulate($i);

      is_deeply($s->steps, 14);
      is_deeply($s->value('out.found'),     $f == 0 || $f % 2 ? 0 : 1);
      is_deeply($s->bInt ("out.dataFound"), $f % 2 ? 0 : $f / 2);
      is_deeply($s->bInt ("out.nextLink"),  $f + ($f % 2 ? 0 : 1)) if $f <= 2*$N ;
     }
    test2($_) for 0..2*$N+1;

    my sub test3($)                                                               # Not enabled so only ever outputs 0
     {my ($f) = @_;

      my %e = setBits ($c, "enable",     0);                                      # Disable
      my %f = setBits ($c, "find",       $f);
      my %t = setBits ($c, "top",      2*$N+1);
      my %k = setWords($c, "keys",   map {2*$_}   1..$N);
      my %d = setWords($c, "data",                1..$N);
      my %n = setWords($c, "next",   map {2*$_-1} 1..$N);
      my $i = {%e, %f, %k, %d, %n, %t};
      my $s = $c->simulate($i);

      is_deeply($s->steps, 14);
      is_deeply($s->value("out.found"),     0);
      is_deeply($s->bInt ("out.dataFound"), 0);
      is_deeply($s->bInt ("out.nextLink"),  0);
     }
    test3($_) for 0..2*$N+1;
   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/btreeNode.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/btreeNode_1.png">


=head2 newBtreeNode($chip, $output, $find, $K, $B, %options)

Create a new B-Tree node. The node is activated only when its preset id appears on its enable bus otherwise it produces zeroes regardless of its inputs.

     Parameter  Description
  1  $chip      Chip
  2  $output    Name prefix for node
  3  $find      Key to find
  4  $K         Maximum number of keys in a node
  5  $B         Size of key in bits
  6  %options   Options

B<Example:>


  if (1)
   {my $B = 3; my $N = 3;

    my $c = Silicon::Chip::newChip;
       $c->inputBits ("find",  $B);                                               # Key to find


    my @n = map {newBtreeNode($c, "n", "find", $N, $B)} 1..3;                     # B-Tree node  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    my %e = map {setBits ($c, $_->enable,     1)             } @n;
    my %f = map {setBits ($c, $_->find,       2)             } @n;
    my %t = map {setBits ($c, $_->top,      2*$N+1)          } @n;
    my %k = map {setWords($c, $_->keys,   map {2*$_}   1..$N)} @n;
    my %d = map {setWords($c, $_->data,                1..$N)} @n;
    my %n = map {setWords($c, $_->next,   map {2*$_-1} 1..$N)} @n;
    my $i = {%e, %f, %k, %d, %n, %t};

    my $s = $c->simulate($i);
    is_deeply($s->value($n[0]->found),     1);
    is_deeply($s->bInt ($n[0]->dataFound), 1);
    is_deeply($s->bInt ($n[0]->nextLink),  3);
   }


=head2 newBtree($chip, $output, $find, $keys, $levels, $bits, %options)

Create a new B-Tree of a specified name

     Parameter  Description
  1  $chip      Chip
  2  $output    Name
  3  $find      Key to find
  4  $keys      Maximum number of keys in a node
  5  $levels    Maximum number of levels in the tree
  6  $bits      Number of bits in a key
  7  %options   Options

B<Example:>


  if (1)
   {my sub B{8}                                                                   # Maximum number of keys per node, levels in the tree, bits per key

    my $c = Silicon::Chip::newChip(name=>"Btree-".B);
    $c->inputBits("find", B);

    my $t = newBtree($c, "tree", "find", 3, 2, B);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    my %i = $c->setBits("find", 2);                                               # Key to find
    if (1)                                                                        # Root node
     {my $n = $t->nodes->{1}{1};
      %i = (%i, $c->setWords($n->keys, 10, 20, 30));
      %i = (%i, $c->setWords($n->data, 11, 22, 33));
      %i = (%i, $c->setWords($n->next, 2,   3,  4));
      %i = (%i, $c->setBits ($n->top,  5));
      %i = (%i, $c->setBits ($n->enable, 1));
     }
    if (1)                                                                        # Leaves
     {my $n = $t->nodes->{2}{1};
      %i = (%i, $c->setWords($n->keys,  2,  4,  6));
      %i = (%i, $c->setWords($n->data, 22, 44, 66));
     }
    if (1)
     {my $n = $t->nodes->{2}{2};
      %i = (%i, $c->setWords($n->keys, 13, 15, 17));
      %i = (%i, $c->setWords($n->data, 31, 51, 71));
     }
    if (1)
     {my $n = $t->nodes->{2}{3};
      %i = (%i, $c->setWords($n->keys, 22, 24, 26));
      %i = (%i, $c->setWords($n->data, 22, 42, 62));
     }
    if (1)
     {my $n = $t->nodes->{2}{4};
      %i = (%i, $c->setWords($n->keys, 33, 35, 37));
      %i = (%i, $c->setWords($n->data, 33, 53, 73));
     }

  # Find the value 22 corresponding to key 2

  # if (my $s = $c->simulate({%i}, svg=>q(tree), spaceDx=>2, spaceDy=>2, newChange=>1,  borderDx=>4, borderDy=>4))  # Fails in 6 hours
  # if (my $s = $c->simulate({%i}, svg=>q(tree), svg =>12, gsx=>1, gsy=>1, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 90 minutes
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>10, gsx=>2, gsy=>1, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 3h15
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>9,  gsx=>1, gsy=>2, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 2h18
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>7,  gsx=>1, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 3h40
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>7,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 3h40
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>6,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>4, log=>1, placeFirst=>1))  # 30 minutes
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  # 1h46
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>6, spaceDy=>6))  # 2h43
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>20, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  # 1h52
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>8))  #
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>4))  #
  # if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8))  # 3h48
  # if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  # 2h41
  # if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  #
  # if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  # 1m55 Java
  # if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8))  # 3m21
  # if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>20, spaceDy=>8)) #
  # if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>3,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>20, spaceDy=>20)) # 21m
  # if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>3,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>100, log=>1, placeFirst=>1, spaceDx=>20, spaceDy=>20)) # 22m
    if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>3,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>20, spaceDy=>20)) # 22m
     {is_deeply($s->steps,                      46);                              # Steps
      is_deeply($s->bInt($t->data),             22);                              # Data associated with search key 2
      ok($s->checkLevelsMatch);
  #   is_deeply($s->length,                 300531);
     }
   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/svg/tree.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree_1.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree_2.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree_3.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree_4.png">



=head1 Hash Definitions




=head2 Silicon::Chip::Btree Definition


Node in B-Tree




=head3 Output fields


=head4 chip

Chip containing tree

=head4 data

Data associated with matched key is any otherwise zeroes

=head4 found

B<1> if a match was found for the input key otherwise B<0>

=head4 nodes

Nodes in tree



=head1 Index


1 L<newBtree|/newBtree> - Create a new B-Tree of a specified name

2 L<newBtreeNode|/newBtreeNode> - Create a new B-Tree node.

3 L<newBtreeNodeCompare|/newBtreeNodeCompare> - Create a new B-Tree node.

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Silicon::Chip::Btree

=head1 Author

L<philiprbrenan@gmail.com|mailto:philiprbrenan@gmail.com>

L<http://prb.appaapps.com|http://prb.appaapps.com>

=head1 Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.

=cut



#D0 Tests                                                                       # Tests and examples
goto finish if caller;                                                          # Skip testing if we are being called as a module
clearFolder(q(svg), 99);                                                        # Clear the output svg folder
eval "use Test::More qw(no_plan)";
eval "Test::More->builder->output('/dev/null')" if -e q(/home/phil/);
my $start = time;
eval {goto latest};
lll "Started";

#svg https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/svg/


#latest:;
if (1)                                                                          #TnewBtreeNodeCompare
 {my $B = 3; my $N = 3; my $id = 5;

  my $c = Silicon::Chip::newChip; my sub c {$c}

     c->inputBits ("enable",   $B);                                             # Enable - the node only operates if this value matches its preset id
     c->inputBits ("find",     $B);                                             # Key to search for
     c->inputWords("keys", $N, $B);                                             # Keys to search
     c->inputWords("data", $N, $B);                                             # Data associated with each key
     c->inputWords("next", $N, $B);                                             # Next node associated with each key
     c->inputBits ("top",      $B);                                             # Top next node

    &newBtreeNodeCompare($c, $id, qw(out enable find keys data next top),$N,$B);# B-Tree node

  my sub test($)                                                                # Find keys in a node
   {my ($f) = @_;

    my %e = $c->setBits ("enable",    $id);
    my %f = $c->setBits ("find",      $f);
    my %t = $c->setBits ("top",       $N+1);
    my %k = $c->setWords("keys",   1..$N);
    my %d = $c->setWords("data",   1..$N);
    my %n = $c->setWords("next",   1..$N);
    my $i = {%e, %f, %k, %d, %n, %t};
    my $s = $c->simulate($i, $f == 2 ? (svg=>q(btreeNode), pngs=>1) : ());

    is_deeply($s->steps, 14);
    is_deeply($s->value("out.found"),     $f >= 1 && $f <= $N ? 1 : 0);
    is_deeply($s->bInt ("out.dataFound"), $f <= $N ? $f : 0);
    is_deeply($s->bInt ("out.nextLink"),  $f <= $N ? $f+1 : $N+1);
   }
  test($_) for 0..$N+1;

  my sub test2($)                                                               # Find and not find keys in a node
   {my ($f) = @_;

    my %e = setBits ($c, "enable",        $id);
    my %f = setBits ($c, "find",          $f);
    my %t = setBits ($c, "top",         2*$N+1);
    my %k = setWords($c, "keys",   map {2*$_}   1..$N);
    my %d = setWords($c, "data",                1..$N);
    my %n = setWords($c, "next",   map {2*$_-1} 1..$N);
    my $i = {%e, %f, %k, %d, %n, %t};
    my $s = $c->simulate($i);

    is_deeply($s->steps, 14);
    is_deeply($s->value('out.found'),     $f == 0 || $f % 2 ? 0 : 1);
    is_deeply($s->bInt ("out.dataFound"), $f % 2 ? 0 : $f / 2);
    is_deeply($s->bInt ("out.nextLink"),  $f + ($f % 2 ? 0 : 1)) if $f <= 2*$N ;
   }
  test2($_) for 0..2*$N+1;

  my sub test3($)                                                               # Not enabled so only ever outputs 0
   {my ($f) = @_;

    my %e = setBits ($c, "enable",     0);                                      # Disable
    my %f = setBits ($c, "find",       $f);
    my %t = setBits ($c, "top",      2*$N+1);
    my %k = setWords($c, "keys",   map {2*$_}   1..$N);
    my %d = setWords($c, "data",                1..$N);
    my %n = setWords($c, "next",   map {2*$_-1} 1..$N);
    my $i = {%e, %f, %k, %d, %n, %t};
    my $s = $c->simulate($i);

    is_deeply($s->steps, 14);
    is_deeply($s->value("out.found"),     0);
    is_deeply($s->bInt ("out.dataFound"), 0);
    is_deeply($s->bInt ("out.nextLink"),  0);
   }
  test3($_) for 0..2*$N+1;
 }

#latest:;
if (1)                                                                          #TnewBtreeNode
 {my $B = 3; my $N = 3;

  my $c = Silicon::Chip::newChip;
     $c->inputBits ("find",  $B);                                               # Key to find

  my @n = map {newBtreeNode($c, "n", "find", $N, $B)} 1..3;                     # B-Tree node

  my %e = map {setBits ($c, $_->enable,     1)             } @n;
  my %f = map {setBits ($c, $_->find,       2)             } @n;
  my %t = map {setBits ($c, $_->top,      2*$N+1)          } @n;
  my %k = map {setWords($c, $_->keys,   map {2*$_}   1..$N)} @n;
  my %d = map {setWords($c, $_->data,                1..$N)} @n;
  my %n = map {setWords($c, $_->next,   map {2*$_-1} 1..$N)} @n;
  my $i = {%e, %f, %k, %d, %n, %t};

  my $s = $c->simulate($i);
  is_deeply($s->value($n[0]->found),     1);
  is_deeply($s->bInt ($n[0]->dataFound), 1);
  is_deeply($s->bInt ($n[0]->nextLink),  3);
 }

latest:;
if (1)                                                                          #TnewBtree
 {my sub B{8}                                                                   # Maximum number of keys per node, levels in the tree, bits per key

  my $c = Silicon::Chip::newChip(name=>"Btree-".B);
  $c->inputBits("find", B);
  my $t = newBtree($c, "tree", "find", 3, 2, B);

  my %i = $c->setBits("find", 2);                                               # Key to find
  if (1)                                                                        # Root node
   {my $n = $t->nodes->{1}{1};
    %i = (%i, $c->setWords($n->keys, 10, 20, 30));
    %i = (%i, $c->setWords($n->data, 11, 22, 33));
    %i = (%i, $c->setWords($n->next, 2,   3,  4));
    %i = (%i, $c->setBits ($n->top,  5));
    %i = (%i, $c->setBits ($n->enable, 1));
   }
  if (1)                                                                        # Leaves
   {my $n = $t->nodes->{2}{1};
    %i = (%i, $c->setWords($n->keys,  2,  4,  6));
    %i = (%i, $c->setWords($n->data, 22, 44, 66));
   }
  if (1)
   {my $n = $t->nodes->{2}{2};
    %i = (%i, $c->setWords($n->keys, 13, 15, 17));
    %i = (%i, $c->setWords($n->data, 31, 51, 71));
   }
  if (1)
   {my $n = $t->nodes->{2}{3};
    %i = (%i, $c->setWords($n->keys, 22, 24, 26));
    %i = (%i, $c->setWords($n->data, 22, 42, 62));
   }
  if (1)
   {my $n = $t->nodes->{2}{4};
    %i = (%i, $c->setWords($n->keys, 33, 35, 37));
    %i = (%i, $c->setWords($n->data, 33, 53, 73));
   }

# Find the value 22 corresponding to key 2

# if (my $s = $c->simulate({%i}, svg=>q(tree), spaceDx=>2, spaceDy=>2, newChange=>1,  borderDx=>4, borderDy=>4))  # Fails in 6 hours
# if (my $s = $c->simulate({%i}, svg=>q(tree), svg =>12, gsx=>1, gsy=>1, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 90 minutes
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>10, gsx=>2, gsy=>1, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 3h15
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>9,  gsx=>1, gsy=>2, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 2h18
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>7,  gsx=>1, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 3h40
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>7,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>4, log=>1))  # 3h40
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>6,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>4, log=>1, placeFirst=>1))  # 30 minutes
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  # 1h46
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>6, spaceDy=>6))  # 2h43
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>20, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  # 1h52
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>8))  #
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>4))  #
# if (my $s = $c->simulate({%i}, svg=>q(tree), png =>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>12, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8))  # 3h48
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  # 2h41
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>1, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  #
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  # 1m55 Java
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8))  # 3m21
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>20, spaceDy=>8)) #
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>3,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>20, spaceDy=>20)) # 21m
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>3,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>4, borderDy=>100, log=>1, placeFirst=>1, spaceDx=>20, spaceDy=>20)) # 22m
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>3,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>20, spaceDy=>20)) # 22m
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>10, spaceDy=>10)) # 10m
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>2, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>10, spaceDy=>10)) # 8m
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>10, spaceDy=>10)) # 7m
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>6, spaceDy=>10)) # 5m
# if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>6, spaceDy=>8)) # 4m
# if (my $s = $c->simulate({%i}, id=>"2024-04-14_2",  pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>8,  spaceDy=>20))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14_3",  pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>6,  spaceDy=>20))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14_4",  pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>6,  spaceDy=>16))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14_5",  pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>6,  spaceDy=>14))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14_6",  pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>6,  spaceDy=>12))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14_7",  pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>4,  spaceDy=>12))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14_8",  pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>2,  spaceDy=>12))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14_1",  pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>10, spaceDy=>20))  # 14m
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.10", pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9,  spaceDy=>20))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.11", pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>8,  spaceDy=>20))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.12", pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>7,  spaceDy=>20))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.13", pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>6,  spaceDy=>20))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.14", pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9,  spaceDy=>19))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.15", pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9,  spaceDy=>18))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.16", pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9,  spaceDy=>17))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.17", pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9,  spaceDy=>16))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.19", spaceDy=>15, pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.21", spaceDy=>13, pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.22", spaceDy=>12, pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.22", spaceDy=>11, pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.23", spaceDy=>10, pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.18", spaceDy=>16, pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.21", spaceDy=>14, pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.22", spaceDy=>14, pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.23", spaceDy=>14, pngs=>4,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>24, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.20", spaceDy=>14, pngs=>3,  svg=>q(tree), gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.24", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.27", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>8,  borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.28", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>10,  borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.29", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>10,  borderDy=>32, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.30", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>8,   borderDy=>32, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.26", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>10, borderDy=>64, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.25", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.31", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.32", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>40, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.33", pngs=>4, gsx=>3, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.34", pngs=>4, gsx=>4, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.35", pngs=>4, gsx=>3, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.37", pngs=>4, gsx=>3, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.38", pngs=>4, gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.39", pngs=>4, gsx=>1, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.40", pngs=>4, gsx=>2, gsy=>1, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.41", pngs=>4, gsx=>1, gsy=>1, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.43", pngs=>4, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>40, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.44", pngs=>4, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>36, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.46", pngs=>4, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>40, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.45", pngs=>4, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>42, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.36", pngs=>4, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-14.42", pngs=>4, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.01", pngs=>3, gsx=>3, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.02", pngs=>3, gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>48, log=>1, placeFirst=>1, spaceDx=>16, spaceDy=>16, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.03", pngs=>4, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.04", pngs=>4, gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>9, spaceDy=>14, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.05", pngs=>4, gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>16, spaceDy=>16, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.06", pngs=>4, gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>24, spaceDy=>16, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.07", pngs=>4,newChange=>1,borderDx=>16,borderDy=>44,log=>1,placeFirst=>1,spaceDx=>9,spaceDy=>32, svg=>q(tree)))   #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.08", pngs=>4,newChange=>1,borderDx=>16,borderDy=>44,log=>1,placeFirst=>1,spaceDx=>32,spaceDy=>32, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.09", pngs=>4, gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.10", pngs=>4, gsx=>4, gsy=>8, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.11", pngs=>4, gsx=>8, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-17.12", pngs=>4, gsx=>8, gsy=>8, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-19.01", pngs=>3, gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>2, spaceDy=>2, svg=>q(tree)))  # 4m
# if (my $s = $c->simulate({%i}, id=>"2024-04-19.02", pngs=>2, gsx=>4, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, svg=>q(tree)))  # 11m
# if (my $s = $c->simulate({%i}, id=>"2024-04-19.03", pngs=>2, gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-19.04", pngs=>2, gsx=>4, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>8, spaceDy=>8, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-19.05", pngs=>2, gsx=>2, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-19.06", pngs=>3, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-19.07", pngs=>2, gsx=>3, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-19.05", pngs=>2, gsx=>2, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-20.01", pngs=>2, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-20.02", pngs=>2, gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-20.03", pngs=>2, gsx=>2, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>3, spaceDy=>4, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-20.04", pngs=>2, gsx=>2, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>3, spaceDy=>3, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-20.05", pngs=>2, gsx=>2, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>2, spaceDy=>3, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-20.06", pngs=>2, gsx=>2, gsy=>4, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>2, spaceDy=>2, svg=>q(tree)))  #
# if (my $s = $c->simulate({%i}, id=>"2024-04-20.07", pngs=>2, gsx=>2, gsy=>3, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>2, spaceDy=>2, svg=>q(tree)))  #
  if (my $s = $c->simulate({%i}, id=>"2024-04-20.07", pngs=>2, gsx=>2, gsy=>2, newChange=>1,  borderDx=>16, borderDy=>44, log=>1, placeFirst=>1, spaceDx=>2, spaceDy=>2, svg=>q(tree)))  #
   {is_deeply($s->steps,                      46);                              # Steps
    is_deeply($s->bInt($t->data),             22);                              # Data associated with search key 2
    ok($s->checkLevelsMatch);
#   is_deeply($s->length,                 300531);
   }
 }

done_testing();
say STDERR sprintf "Finished in %9.4f seconds",  time - $start;
finish: 1;
