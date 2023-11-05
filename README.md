<div>
    <p><a href="https://github.com/philiprbrenan/SiliconChipBtree"><img src="https://github.com/philiprbrenan/SiliconChipBtree/workflows/Test/badge.svg"></a>
</div>

# Name

Silicon::Chip::Btree - Implement a B-Tree as a silicon chip.

# Synopsis

# Description

Implement a B-Tree as a silicon chip.

Version 20231101.

The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see [Index](#index).

# Btree Node

A node in a B-Tree containing keys, data and links to other nodes

## newBtreeNode($chip, $output, $find, $keys, $data, $next, $top, $N, $B, %options)

Create a new B-Tree node

        Parameter  Description
     1  $chip      Chip
     2  $output    Output name
     3  $find      Key to find
     4  $keys      Keys to search
     5  $data      Data corresponding to keys
     6  $next      Next links
     7  $top       Top next link
     8  $N         Maximum number of keys in a node
     9  $B         Size of key in bits
    10  %options   Options

**Example:**

    if (1)
     {my $B = 3;
      my $N = 3;
      my $c = Silicon::Chip::newChip;

         $c->inputBits ("find",     $B);                                            # Input into B-Tree node
         $c->inputWords("keys", $N, $B);
         $c->inputWords("data", $N, $B);
         $c->inputWords("next", $N, $B);
         $c->inputBits ("top",      $B);


         $c->newBtreeNode(qw(out find keys data next top), $N, $B);                 # B-Tree node  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


         $c->output    ("found",     "out.found");                                  # Results returned from B-Tree node
         $c->outputBits("dataFound", "out.dataFound", $B);
         $c->outputBits("nextLink",  "out.nextLink",  $B);

      my sub test($)                                                                # Find keys in a node
       {my ($find) = @_;

        my %f = setBits ("find", $B,     $find);
        my %t = setBits ("top",  $B,     $N+1);
        my %k = setWords("keys", $N, $B, 1..$N);
        my %d = setWords("data", $N, $B, 1..$N);
        my %n = setWords("next", $N, $B, 1..$N);
        my $s = $c->simulate({%f, %k, %d, %n, %t}, svg=>"svg/btreeNode_${N}_$B");

        is_deeply($s->steps,                          9);
        is_deeply($s->values->{found},                1);
        is_deeply($s->bitsToInteger("dataFound", $B), $find);
        is_deeply($s->bitsToInteger("nextLink",  $B), $find+1);
       }
      test($_) for 1..$N;
     }

# Index

1 [newBtreeNode](#newbtreenode) - Create a new B-Tree node

# Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via **cpan**:

    sudo cpan install Silicon::Chip

# Author

[philiprbrenan@gmail.com](mailto:philiprbrenan@gmail.com)

[http://www.appaapps.com](http://www.appaapps.com)

# Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.
