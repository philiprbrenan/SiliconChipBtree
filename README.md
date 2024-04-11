<div>
    <p><a href="https://github.com/philiprbrenan/SiliconChipBtree"><img src="https://github.com/philiprbrenan/SiliconChipBtree/workflows/Test/badge.svg"></a>
</div>

# Name

Silicon::Chip::Btree - Implement a B-Tree as a silicon chip.

See:

<div>
    <p><a href="http://prb.appaapps.com/zesal/pitchdeck/pitchDeck.html">the pitch deck</a>
</div>

for the reasons why you might want to get involved with this project.

# Synopsis

# Description

Implement a B-Tree as a silicon chip.

Version 20240331.

The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see [Index](#index).

# B-Tree

Create a Btree as a Silicon Chip.

## newBtreeNodeCompare ($chip, $id, $output, $enable, $find, $keys, $data, $next, $top, $N, $B, %options)

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

**Example:**

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
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/btreeNode.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/btreeNode_1.png">
</div>

## newBtreeNode($chip, $output, $find, $K, $B, %options)

Create a new B-Tree node. The node is activated only when its preset id appears on its enable bus otherwise it produces zeroes regardless of its inputs.

       Parameter  Description
    1  $chip      Chip
    2  $output    Name prefix for node
    3  $find      Key to find
    4  $K         Maximum number of keys in a node
    5  $B         Size of key in bits
    6  %options   Options

**Example:**

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
    

## newBtree($chip, $output, $find, $keys, $levels, $bits, %options)

Create a new B-Tree of a specified name

       Parameter  Description
    1  $chip      Chip
    2  $output    Name
    3  $find      Key to find
    4  $keys      Maximum number of keys in a node
    5  $levels    Maximum number of levels in the tree
    6  $bits      Number of bits in a key
    7  %options   Options

**Example:**

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
      if (my $s = $c->simulate({%i}, svg=>q(tree), pngs=>4,  gsx=>2, gsy=>5, newChange=>1,  borderDx=>4, borderDy=>32, log=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4))  #
       {is_deeply($s->steps,                      46);                              # Steps
        is_deeply($s->bInt($t->data),             22);                              # Data associated with search key 2
        ok($s->checkLevelsMatch);
    #   is_deeply($s->length,                 300531);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/svg/tree.svg">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree_2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree_3.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipBtree/lib/Silicon/Chip/png/tree_4.png">
</div>

# Hash Definitions

## Silicon::Chip::Btree Definition

Node in B-Tree

### Output fields

#### chip

Chip containing tree

#### data

Data associated with matched key is any otherwise zeroes

#### found

**1** if a match was found for the input key otherwise **0**

#### nodes

Nodes in tree

# Index

1 [newBtree](#newbtree) - Create a new B-Tree of a specified name

2 [newBtreeNode](#newbtreenode) - Create a new B-Tree node.

3 [newBtreeNodeCompare](#newbtreenodecompare) - Create a new B-Tree node.

# Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via **cpan**:

    sudo cpan install Silicon::Chip::Btree

# Author

[philiprbrenan@gmail.com](mailto:philiprbrenan@gmail.com)

[http://prb.appaapps.com](http://prb.appaapps.com)

# Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.
