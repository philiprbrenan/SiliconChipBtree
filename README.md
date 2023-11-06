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

A node in a B-Tree containing keys, data and links to other nodes. Nodes only produce output when their preset id is present on their enable bus.  This makes it possible for one node to select another node for further processing of the key being sought.

## newBtreeNode($chip, $id, $enable, $output, $find, $keys, $data, $next, $top, $N, $B, %options)

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

**Example:**

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
    

<div>
    <img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipBtree/main/lib/Silicon/Chip/svg/btreeNode.svg">
</div>

# Index

1 [newBtreeNode](#newbtreenode) - Create a new B-Tree node.

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
