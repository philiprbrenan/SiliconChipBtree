<div>
    <p><a href="https://github.com/philiprbrenan/SiliconChip"><img src="https://github.com/philiprbrenan/SiliconChip/workflows/Test/badge.svg"></a>
</div>

# Name

Silicon::Chip - Design a [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) by combining [logic gates](https://en.wikipedia.org/wiki/Logic_gate) and sub [chips](https://en.wikipedia.org/wiki/Integrated_circuit).

# Synopsis

Create a chip to compare two 4 bit big endian unsigned integers for equality:

    my $B = 4;                                              # Number of bits

    my $c = Silicon::Chip::newChip(title=>"$B Bit Equals"); # Create chip

    $c->input ("a$_")                       for 1..$B;      # First number
    $c->input ("b$_")                       for 1..$B;      # Second number

    $c->nxor  ("e$_", {1=>"a$_", 2=>"b$_"}) for 1..$B;      # Test each bit for equality
    $c->and   ("and", {map{$_=>"e$_"}           1..$B});    # And tests together to get total equality

    $c->name("out", "and");                                 # Output gate

    my $s = $c->simulate({a1=>1, a2=>0, a3=>1, a4=>0,       # Input gate values
                          b1=>1, b2=>0, b3=>1, b4=>0},
                          svg=>q(Equals$B));                # Svg drawing of layout

    is_deeply($s->steps,         3);                        # Three steps
    is_deeply($s->values->{out}, 1);                        # Out is 1 for equals

    my $t = $c->simulate({a1=>1, a2=>1, a3=>1, a4=>0,
                          b1=>1, b2=>0, b3=>1, b4=>0});
    is_deeply($t->values->{out}, 0);                        # Out is 0 for not equals

## Gate level diagram:

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals_1.png">
</div>

## Other examples

Other circuit diagrams can be seen in folder: [lib/Silicon/svg](https://github.com/philiprbrenan/SiliconChip/tree/main/lib/Silicon/svg)

# Description

Design a [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) by combining [logic gates](https://en.wikipedia.org/wiki/Logic_gate) and sub [chips](https://en.wikipedia.org/wiki/Integrated_circuit).

Version 20240331.

The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see [Index](#index).

# Construct

Construct a [Silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) using standard [logic gates](https://en.wikipedia.org/wiki/Logic_gate), components and sub chips combined via buses.

## newChip (%options)

Create a new [chip](https://en.wikipedia.org/wiki/Integrated_circuit).

       Parameter  Description
    1  %options   Options

**Example:**

    if (1)                                                                          
    
     {my $c = Silicon::Chip::newChip(expand=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $c->one ("one");
      $c->zero("zero");
      $c->or  ("or",   [qw(one zero)]);
      $c->and ("and",  [qw(one zero)]);
      $c->output("o1", "or");
      $c->output("o2", "and");
      my $s = $c->simulate({}, svg=>q(oneZero), pngs=>1, gsx=>1, gsy=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps      , 4);
      is_deeply($s->value("o1"), 1);
      is_deeply($s->value("o2"), 0);
      is_deeply($s->length,    156);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/oneZero.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/oneZero_1.png">
</div>

    if (1)                                                                           # Single AND gate
    
     {my $c = Silicon::Chip::newChip;  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $c->input ("i1");
      $c->input ("i2");
      $c->and   ("and1", [qw(i1 i2)]);
      $c->output("o", "and1");
      my $s = $c->simulate({i1=>1, i2=>1}, svg=>q(and), pngs=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps         , 2);
      is_deeply($s->value("and1") , 1);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/and.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/and_1.png">
</div>

    if (1)                                                                           # 4 bit equal 
     {my $B = 4;                                                                    # Number of bits
    
    
      my $c = Silicon::Chip::newChip(title=><<"END");                               # Create chip  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    $B Bit Equals
    END
      $c->input ("a$_")                 for 1..$B;                                  # First number
      $c->input ("b$_")                 for 1..$B;                                  # Second number
    
      $c->nxor  ("e$_", "a$_", "b$_")   for 1..$B;                                  # Test each bit for equality
      $c->and   ("and", {map{$_=>"e$_"}     1..$B});                                # And tests together to get total equality
    
      $c->output("out", "and");                                                     # Output gate
    
      my $s = $c->simulate({a1=>1, a2=>0, a3=>1, a4=>0,                             # Input gate values
                            b1=>1, b2=>0, b3=>1, b4=>0},
                            svg=>q(Equals), pngs=>1, spaceDy=>1);                   # Svg drawing of layout
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,        4);                                               # Steps
      is_deeply($s->value("out"), 1);                                               # Out is 1 for equals
    
      my $t = $c->simulate({a1=>1, a2=>1, a3=>1, a4=>0,
                            b1=>1, b2=>0, b3=>1, b4=>0});
      is_deeply($t->value("out"), 0);                                               # Out is 0 for not equals
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals_1.png">
</div>

## gate($chip, $type, $output, $input1, $input2, %options)

A [logic gate](https://en.wikipedia.org/wiki/Logic_gate) chosen from **possibleTypes**.  The gate type can be used as a method name, so **->gate("and",** can be reduced to **->and(**.

       Parameter  Description
    1  $chip      Chip
    2  $type      Gate type
    3  $output    Output name
    4  $input1    Input from another gate
    5  $input2    Input from another gate
    6  %options   Options

**Example:**

    if (1)                                                                           # Two AND gates driving an OR gate  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     {my $c = newChip;
      $c->input ("i11");
      $c->input ("i12");
      $c->and   ("and1", [qw(i11   i12)]);
      $c->input ("i21");
      $c->input ("i22");
      $c->and   ("and2", [qw(i21   i22 )]);
      $c->or    ("or",   [qw(and1  and2)]);
      $c->output( "o", "or");
      my $s = $c->simulate({i11=>1, i12=>1, i21=>1, i22=>1}, svg=>q(andOr), pngs=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps        , 3);
      is_deeply($s->value("or")  , 1);
         $s  = $c->simulate({i11=>1, i12=>0, i21=>1, i22=>1});
      is_deeply($s->steps        , 3);
      is_deeply($s->value("or")  , 1);
         $s  = $c->simulate({i11=>1, i12=>0, i21=>1, i22=>0});
      is_deeply($s->steps        , 3);
      is_deeply($s->value("o")   , 0);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOr.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOr_1.png">
</div>

## Buses

A bus is an array of bits or an array of arrays of bits

### Bits

An array of bits that can be manipulated via one name.

#### setSizeBits ($chip, $name, $bits, %options)

Set the size of a bits bus.

       Parameter  Description
    1  $chip      Chip
    2  $name      Bits bus name
    3  $bits      Options
    4  %options

**Example:**

    if (1)                                                                           
     {my $c = newChip();
    
      $c->setSizeBits ('i', 2);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $c->setSizeWords('j', 3, 2);
      is_deeply($c->sizeBits,  {i => 2, j_1 => 2, j_2 => 2, j_3 => 2});
      is_deeply($c->sizeWords, {j => [3, 2]});
     }
    

#### bits($chip, $name, $bits, $value, %options)

Create a bus set to a specified number.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $bits      Width in bits of bus
    4  $value     Value of bus
    5  %options   Options

**Example:**

    if (1)                                                                          
     {my $N = 4;
      for my $i(0..2**$N-1)
       {my $c = Silicon::Chip::newChip;
    
        $c->bits      ("c", $N, $i);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        $c->outputBits("o", "c");
    
        my @T = $i == 3 ? (svg=>q(bits), pngs=>1) : ();  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        my $s = $c->simulate({}, @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->steps, 2);
        is_deeply($s->bInt("o"), $i);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/bits.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/bits_1.png">
</div>

#### inputBits   ($chip, $name, $bits, %options)

Create an **input** bus made of bits.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $bits      Width in bits of bus
    4  %options   Options

**Example:**

    if (1)                                                                             
     {my $W = 8;
      my $i = newChip();
    
         $i->inputBits('i', $W);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $i->notBits   (qw(n i));
         $i->outputBits(qw(o n));
    
      my $o = newChip(name=>"outer");
    
         $o->inputBits ('a', $W);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $o->outputBits(qw(A a));
    
         $o->inputBits ('b', $W);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $o->outputBits(qw(B b));
    
      my %i = connectBits($i, 'i', $o, 'A');
      my %o = connectBits($i, 'o', $o, 'b');
      $o->install($i, {%i}, {%o});
    
      my %d = setBits($o, 'a', 0b10110);
      my $s = $o->simulate({%d}, svg=>q(not), pngs=>1, gsx=>1, gsy=>1, minHeight=>2*$W, newChange=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->bInt('B'), 0b11101001);
      is_deeply($s->length,  80);
      is_deeply($s->area,   100);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not_1.png">
</div>

#### outputBits  ($chip, $name, $input, %options)

Create an **output** bus made of bits.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (1)                                                                             
     {my $W = 8;
      my $i = newChip();
         $i->inputBits('i', $W);
         $i->notBits   (qw(n i));
    
         $i->outputBits(qw(o n));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my $o = newChip(name=>"outer");
         $o->inputBits ('a', $W);
    
         $o->outputBits(qw(A a));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $o->inputBits ('b', $W);
    
         $o->outputBits(qw(B b));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my %i = connectBits($i, 'i', $o, 'A');
      my %o = connectBits($i, 'o', $o, 'b');
      $o->install($i, {%i}, {%o});
    
      my %d = setBits($o, 'a', 0b10110);
      my $s = $o->simulate({%d}, svg=>q(not), pngs=>1, gsx=>1, gsy=>1, minHeight=>2*$W, newChange=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->bInt('B'), 0b11101001);
      is_deeply($s->length,  80);
      is_deeply($s->area,   100);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not_1.png">
</div>

    if (1)                                                                               
     {my @B = ((my $W = 4), (my $B = 2));
    
      my $c = newChip();
         $c->inputWords ('i', @B);
         $c->andWords   (qw(and  i));
         $c->andWordsX  (qw(andX i));
         $c-> orWords   (qw( or  i));
         $c-> orWordsX  (qw( orX i));
         $c->notWords   (qw(n    i));
    
         $c->outputBits (qw(And  and));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
         $c->outputBits (qw(AndX andX));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
         $c->outputBits (qw(Or   or));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
         $c->outputBits (qw(OrX  orX));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputWords(qw(N    n));
      my %d = setWords($c, 'i', 0b00, 0b01, 0b10, 0b11);
      my $s = $c->simulate({%d}, svg=>q(andOrWords), pngs=>1, newChange=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, borderDy=>18);
      ok($s->checkLevelsMatch);
    
      is_deeply($s->bInt('And'),  0b1000);
      is_deeply($s->bInt('AndX'), 0b0000);
    
      is_deeply($s->bInt('Or'),  0b1110);
      is_deeply($s->bInt('OrX'), 0b11);
      is_deeply([$s->wInt('N')], [3, 2, 1, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
</div>

#### notBits ($chip, $name, $input, %options)

Create a **not** bus made of bits.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (1)                                                                             
     {my $W = 8;
      my $i = newChip();
         $i->inputBits('i', $W);
    
         $i->notBits   (qw(n i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $i->outputBits(qw(o n));
    
      my $o = newChip(name=>"outer");
         $o->inputBits ('a', $W);
         $o->outputBits(qw(A a));
         $o->inputBits ('b', $W);
         $o->outputBits(qw(B b));
    
      my %i = connectBits($i, 'i', $o, 'A');
      my %o = connectBits($i, 'o', $o, 'b');
      $o->install($i, {%i}, {%o});
    
      my %d = setBits($o, 'a', 0b10110);
      my $s = $o->simulate({%d}, svg=>q(not), pngs=>1, gsx=>1, gsy=>1, minHeight=>2*$W, newChange=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->bInt('B'), 0b11101001);
      is_deeply($s->length,  80);
      is_deeply($s->area,   100);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not_1.png">
</div>

#### andBits ($chip, $name, $input, %options)

**and** a bus made of bits.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (gitHub)                                                                             
     {for my $W(2..8)
       {my $c = newChip(expand=>1);
           $c-> inputBits('i', $W);
    
           $c->   andBits(qw(and  i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

           $c->    orBits(qw(or   i));
           $c->  nandBits(qw(nand i));
           $c->   norBits(qw(nor  i));
           $c->output    (qw(And  and));
           $c->output    (qw(Or   or));
           $c->output    (qw(nAnd nand));
           $c->output    (qw(nOr  nor));
    
        my %d = setBits($c, 'i', 0b1);
        my @T = $W == 8 ? (svg=>q(andOrBits), pngs=>2, spaceDx=>2, spaceDy=>1, minHeight=>20) : ();
        my $s = $c->simulate({%d}, @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->value("And"),  0);
        is_deeply($s->value("Or"),   1);
        is_deeply($s->value("nAnd"), 1);
        is_deeply($s->value("nOr"),  0);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_2.png">
</div>

#### nandBits($chip, $name, $input, %options)

**nand** a bus made of bits.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (gitHub)                                                                             
     {for my $W(2..8)
       {my $c = newChip(expand=>1);
           $c-> inputBits('i', $W);
           $c->   andBits(qw(and  i));
           $c->    orBits(qw(or   i));
    
           $c->  nandBits(qw(nand i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

           $c->   norBits(qw(nor  i));
           $c->output    (qw(And  and));
           $c->output    (qw(Or   or));
           $c->output    (qw(nAnd nand));
           $c->output    (qw(nOr  nor));
    
        my %d = setBits($c, 'i', 0b1);
        my @T = $W == 8 ? (svg=>q(andOrBits), pngs=>2, spaceDx=>2, spaceDy=>1, minHeight=>20) : ();
        my $s = $c->simulate({%d}, @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->value("And"),  0);
        is_deeply($s->value("Or"),   1);
        is_deeply($s->value("nAnd"), 1);
        is_deeply($s->value("nOr"),  0);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_2.png">
</div>

#### orBits  ($chip, $name, $input, %options)

**or** a bus made of bits.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Options
    4  %options

**Example:**

    if (gitHub)                                                                             
     {for my $W(2..8)
       {my $c = newChip(expand=>1);
           $c-> inputBits('i', $W);
           $c->   andBits(qw(and  i));
    
           $c->    orBits(qw(or   i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

           $c->  nandBits(qw(nand i));
           $c->   norBits(qw(nor  i));
           $c->output    (qw(And  and));
           $c->output    (qw(Or   or));
           $c->output    (qw(nAnd nand));
           $c->output    (qw(nOr  nor));
    
        my %d = setBits($c, 'i', 0b1);
        my @T = $W == 8 ? (svg=>q(andOrBits), pngs=>2, spaceDx=>2, spaceDy=>1, minHeight=>20) : ();
        my $s = $c->simulate({%d}, @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->value("And"),  0);
        is_deeply($s->value("Or"),   1);
        is_deeply($s->value("nAnd"), 1);
        is_deeply($s->value("nOr"),  0);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_2.png">
</div>

#### norBits ($chip, $name, $input, %options)

**nor** a bus made of bits.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Options
    4  %options

**Example:**

    if (gitHub)                                                                             
     {for my $W(2..8)
       {my $c = newChip(expand=>1);
           $c-> inputBits('i', $W);
           $c->   andBits(qw(and  i));
           $c->    orBits(qw(or   i));
           $c->  nandBits(qw(nand i));
    
           $c->   norBits(qw(nor  i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

           $c->output    (qw(And  and));
           $c->output    (qw(Or   or));
           $c->output    (qw(nAnd nand));
           $c->output    (qw(nOr  nor));
    
        my %d = setBits($c, 'i', 0b1);
        my @T = $W == 8 ? (svg=>q(andOrBits), pngs=>2, spaceDx=>2, spaceDy=>1, minHeight=>20) : ();
        my $s = $c->simulate({%d}, @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->value("And"),  0);
        is_deeply($s->value("Or"),   1);
        is_deeply($s->value("nAnd"), 1);
        is_deeply($s->value("nOr"),  0);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_2.png">
</div>

### Words

An array of arrays of bits that can be manipulated via one name.

#### setSizeWords($chip, $name, $words, $bits, %options)

Set the size of a bits bus.

       Parameter  Description
    1  $chip      Chip
    2  $name      Bits bus name
    3  $words     Words
    4  $bits      Bits per word
    5  %options   Options

**Example:**

    if (1)                                                                           
     {my $c = newChip();
      $c->setSizeBits ('i', 2);
    
      $c->setSizeWords('j', 3, 2);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply($c->sizeBits,  {i => 2, j_1 => 2, j_2 => 2, j_3 => 2});
      is_deeply($c->sizeWords, {j => [3, 2]});
     }
    

#### words   ($chip, $name, $bits, @values)

Create a word bus set to specified numbers.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $bits      Width in bits of each word
    4  @values    Values of words

**Example:**

    if (1)                                                                           # Internal input gate   
     {my @n = qw(3 2 1 2 3);
      my $c = newChip();
    
         $c->words('i', 2, @n);                                                     # Input  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputWords(qw(o i));                                                  # Output
    
      my $s = $c->simulate({}, svg=>q(words), pngs=>1, minHeight=>10);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  2);
      is_deeply([$s->wInt("i")], [@n]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words_1.png">
</div>

#### inputWords  ($chip, $name, $words, $bits, %options)

Create an **input** bus made of words.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $words     Width in words of bus
    4  $bits      Width in bits of each word on bus
    5  %options   Options

**Example:**

    if (1)                                                                                
     {my @b = ((my $W = 4), (my $B = 3));
    
      my $c = newChip();
    
         $c->inputWords ('i',      @b);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputWords(qw(o i));
    
      my %d = setWords($c, 'i', 0b000, 0b001, 0b010, 0b011);
      my $s = $c->simulate({%d}, svg=>q(words2), pngs=>1, newChange=>1, minHeight=>12);
      ok($s->checkLevelsMatch);
      is_deeply([$s->wInt('o')], [0..3]);
      is_deeply([$s->wordXToInteger('o')], [10, 12, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
</div>

#### outputWords ($chip, $name, $input, %options)

Create an **output** bus made of words.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (1)                                                                                
     {my @b = ((my $W = 4), (my $B = 3));
    
      my $c = newChip();
         $c->inputWords ('i',      @b);
    
         $c->outputWords(qw(o i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my %d = setWords($c, 'i', 0b000, 0b001, 0b010, 0b011);
      my $s = $c->simulate({%d}, svg=>q(words2), pngs=>1, newChange=>1, minHeight=>12);
      ok($s->checkLevelsMatch);
      is_deeply([$s->wInt('o')], [0..3]);
      is_deeply([$s->wordXToInteger('o')], [10, 12, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
</div>

#### notWords($chip, $name, $input, %options)

Create a **not** bus made of words.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (1)                                                                               
     {my @B = ((my $W = 4), (my $B = 2));
    
      my $c = newChip();
         $c->inputWords ('i', @B);
         $c->andWords   (qw(and  i));
         $c->andWordsX  (qw(andX i));
         $c-> orWords   (qw( or  i));
         $c-> orWordsX  (qw( orX i));
    
         $c->notWords   (qw(n    i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits (qw(And  and));
         $c->outputBits (qw(AndX andX));
         $c->outputBits (qw(Or   or));
         $c->outputBits (qw(OrX  orX));
         $c->outputWords(qw(N    n));
      my %d = setWords($c, 'i', 0b00, 0b01, 0b10, 0b11);
      my $s = $c->simulate({%d}, svg=>q(andOrWords), pngs=>1, newChange=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, borderDy=>18);
      ok($s->checkLevelsMatch);
    
      is_deeply($s->bInt('And'),  0b1000);
      is_deeply($s->bInt('AndX'), 0b0000);
    
      is_deeply($s->bInt('Or'),  0b1110);
      is_deeply($s->bInt('OrX'), 0b11);
      is_deeply([$s->wInt('N')], [3, 2, 1, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
</div>

#### andWords($chip, $name, $input, %options)

**and** a bus made of words to produce a single word.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (1)                                                                               
     {my @B = ((my $W = 4), (my $B = 2));
    
      my $c = newChip();
         $c->inputWords ('i', @B);
    
         $c->andWords   (qw(and  i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->andWordsX  (qw(andX i));
         $c-> orWords   (qw( or  i));
         $c-> orWordsX  (qw( orX i));
         $c->notWords   (qw(n    i));
         $c->outputBits (qw(And  and));
         $c->outputBits (qw(AndX andX));
         $c->outputBits (qw(Or   or));
         $c->outputBits (qw(OrX  orX));
         $c->outputWords(qw(N    n));
      my %d = setWords($c, 'i', 0b00, 0b01, 0b10, 0b11);
      my $s = $c->simulate({%d}, svg=>q(andOrWords), pngs=>1, newChange=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, borderDy=>18);
      ok($s->checkLevelsMatch);
    
      is_deeply($s->bInt('And'),  0b1000);
      is_deeply($s->bInt('AndX'), 0b0000);
    
      is_deeply($s->bInt('Or'),  0b1110);
      is_deeply($s->bInt('OrX'), 0b11);
      is_deeply([$s->wInt('N')], [3, 2, 1, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
</div>

    if (1)                                                                                
     {my @b = ((my $W = 4), (my $B = 3));
    
      my $c = newChip();
         $c->inputWords ('i',      @b);
         $c->outputWords(qw(o i));
    
      my %d = setWords($c, 'i', 0b000, 0b001, 0b010, 0b011);
      my $s = $c->simulate({%d}, svg=>q(words2), pngs=>1, newChange=>1, minHeight=>12);
      ok($s->checkLevelsMatch);
      is_deeply([$s->wInt('o')], [0..3]);
      is_deeply([$s->wordXToInteger('o')], [10, 12, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
</div>

#### andWordsX   ($chip, $name, $input, %options)

**and** a bus made of words by and-ing the corresponding bits in each word to make a single word.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (1)                                                                               
     {my @B = ((my $W = 4), (my $B = 2));
    
      my $c = newChip();
         $c->inputWords ('i', @B);
         $c->andWords   (qw(and  i));
    
         $c->andWordsX  (qw(andX i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c-> orWords   (qw( or  i));
         $c-> orWordsX  (qw( orX i));
         $c->notWords   (qw(n    i));
         $c->outputBits (qw(And  and));
         $c->outputBits (qw(AndX andX));
         $c->outputBits (qw(Or   or));
         $c->outputBits (qw(OrX  orX));
         $c->outputWords(qw(N    n));
      my %d = setWords($c, 'i', 0b00, 0b01, 0b10, 0b11);
      my $s = $c->simulate({%d}, svg=>q(andOrWords), pngs=>1, newChange=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, borderDy=>18);
      ok($s->checkLevelsMatch);
    
      is_deeply($s->bInt('And'),  0b1000);
      is_deeply($s->bInt('AndX'), 0b0000);
    
      is_deeply($s->bInt('Or'),  0b1110);
      is_deeply($s->bInt('OrX'), 0b11);
      is_deeply([$s->wInt('N')], [3, 2, 1, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
</div>

#### orWords ($chip, $name, $input, %options)

**or** a bus made of words to produce a single word.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (1)                                                                               
     {my @B = ((my $W = 4), (my $B = 2));
    
      my $c = newChip();
         $c->inputWords ('i', @B);
         $c->andWords   (qw(and  i));
         $c->andWordsX  (qw(andX i));
    
         $c-> orWords   (qw( or  i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c-> orWordsX  (qw( orX i));
         $c->notWords   (qw(n    i));
         $c->outputBits (qw(And  and));
         $c->outputBits (qw(AndX andX));
         $c->outputBits (qw(Or   or));
         $c->outputBits (qw(OrX  orX));
         $c->outputWords(qw(N    n));
      my %d = setWords($c, 'i', 0b00, 0b01, 0b10, 0b11);
      my $s = $c->simulate({%d}, svg=>q(andOrWords), pngs=>1, newChange=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, borderDy=>18);
      ok($s->checkLevelsMatch);
    
      is_deeply($s->bInt('And'),  0b1000);
      is_deeply($s->bInt('AndX'), 0b0000);
    
      is_deeply($s->bInt('Or'),  0b1110);
      is_deeply($s->bInt('OrX'), 0b11);
      is_deeply([$s->wInt('N')], [3, 2, 1, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
</div>

    if (1)                                                                                
     {my @b = ((my $W = 4), (my $B = 3));
    
      my $c = newChip();
         $c->inputWords ('i',      @b);
         $c->outputWords(qw(o i));
    
      my %d = setWords($c, 'i', 0b000, 0b001, 0b010, 0b011);
      my $s = $c->simulate({%d}, svg=>q(words2), pngs=>1, newChange=>1, minHeight=>12);
      ok($s->checkLevelsMatch);
      is_deeply([$s->wInt('o')], [0..3]);
      is_deeply([$s->wordXToInteger('o')], [10, 12, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
</div>

#### orWordsX($chip, $name, $input, %options)

**or** a bus made of words by or-ing the corresponding bits in each word to make a single word.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of bus
    3  $input     Name of inputs
    4  %options   Options

**Example:**

    if (1)                                                                               
     {my @B = ((my $W = 4), (my $B = 2));
    
      my $c = newChip();
         $c->inputWords ('i', @B);
         $c->andWords   (qw(and  i));
         $c->andWordsX  (qw(andX i));
         $c-> orWords   (qw( or  i));
    
         $c-> orWordsX  (qw( orX i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->notWords   (qw(n    i));
         $c->outputBits (qw(And  and));
         $c->outputBits (qw(AndX andX));
         $c->outputBits (qw(Or   or));
         $c->outputBits (qw(OrX  orX));
         $c->outputWords(qw(N    n));
      my %d = setWords($c, 'i', 0b00, 0b01, 0b10, 0b11);
      my $s = $c->simulate({%d}, svg=>q(andOrWords), pngs=>1, newChange=>1, placeFirst=>1, spaceDx=>4, spaceDy=>4, borderDy=>18);
      ok($s->checkLevelsMatch);
    
      is_deeply($s->bInt('And'),  0b1000);
      is_deeply($s->bInt('AndX'), 0b0000);
    
      is_deeply($s->bInt('Or'),  0b1110);
      is_deeply($s->bInt('OrX'), 0b11);
      is_deeply([$s->wInt('N')], [3, 2, 1, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
</div>

## Connect

Connect input buses to other buses.

### connectInput($chip, $in, $to, %options)

Connect a previously defined input gate to the output of another gate on the same chip. This allows us to define a set of gates on the chip without having to know, first, all the names of the gates that will provide input to these gates.

       Parameter  Description
    1  $chip      Chip
    2  $in        Input gate
    3  $to        Gate to connect input gate to
    4  %options   Options

**Example:**

    if (1)                                                                          # Internal input gate   
     {my $c = newChip();
         $c->input ('i');                                                           # Input
         $c->input ('j');                                                           # Internal input which we will connect to later
         $c->output(qw(o j));                                                       # Output
    
    
         $c->connectInput(qw(j i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
    
      my $s = $c->simulate({i=>1}, svg=>q(connectInput), pngs=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  1);
      is_deeply($s->value("j"), undef);
      is_deeply($s->value("o"), 1);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInput.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInput_1.png">
</div>

    if (1)                                                                           # Internal input gate   
     {my @n = qw(3 2 1 2 3);
      my $c = newChip();
         $c->words('i', 2, @n);                                                     # Input
         $c->outputWords(qw(o i));                                                  # Output
      my $s = $c->simulate({}, svg=>q(words), pngs=>1, minHeight=>10);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  2);
      is_deeply([$s->wInt("i")], [@n]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words_1.png">
</div>

### connectInputBits($chip, $in, $to, %options)

Connect a previously defined input bit bus to another bit bus provided the two buses have the same size.

       Parameter  Description
    1  $chip      Chip
    2  $in        Input gate
    3  $to        Gate to connect input gate to
    4  %options   Options

**Example:**

    if (1)                                                                          
     {my $N = 5; my $B = 5;
      my $c = newChip();
      $c->bits      ('a', $B, $N);
      $c->inputBits ('i', $N);
      $c->outputBits(qw(o i));
    
      $c->connectInputBits(qw(i a));                                                # The input gates will get squeezed out  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my $s = $c->simulate({}, svg=>q(connectInputBits), pngs=>1, newChange=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  2);
      is_deeply($s->levels, 1);
      is_deeply($s->bInt("o"), $N);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInputBits.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInputBits_1.png">
</div>

### connectInputWords   ($chip, $in, $to, %options)

Connect a previously defined input word bus to another word bus provided the two buses have the same size.

       Parameter  Description
    1  $chip      Chip
    2  $in        Input gate
    3  $to        Gate to connect input gate to
    4  %options   Options

**Example:**

    if (1)                                                                          
     {my $W = 6; my $B = 5;
      my $c = newChip();
      $c->words      ('a',     $B, 1..$W);
      $c->inputWords ('i', $W, $B);
      $c->outputWords(qw(o i));
    
      $c->connectInputWords(qw(i a));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my $s = $c->simulate({}, svg=>q(connectInputWords), pngs=>1, newChange=>1, borderDy=>16);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      ok($s->checkLevelsMatch);
      is_deeply($s->steps, 2);
      is_deeply([$s->wInt("o")], [1..$W]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInputWords.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInputWords_1.png">
</div>

## Install

Install a chip within a chip as a sub chip.

### install ($chip, $subChip, $inputs, $outputs, %options)

Install a [chip](https://en.wikipedia.org/wiki/Integrated_circuit) within another [chip](https://en.wikipedia.org/wiki/Integrated_circuit) specifying the connections between the inner and outer [chip](https://en.wikipedia.org/wiki/Integrated_circuit).  The same [chip](https://en.wikipedia.org/wiki/Integrated_circuit) can be installed multiple times as each [chip](https://en.wikipedia.org/wiki/Integrated_circuit) description is read only.

       Parameter  Description
    1  $chip      Outer chip
    2  $subChip   Inner chip
    3  $inputs    Inputs of inner chip to to outputs of outer chip
    4  $outputs   Outputs of inner chip to inputs of outer chip
    5  %options   Options

**Example:**

    if (1)                                                                            # Install one chip inside another chip, specifically one chip that performs NOT is installed once to flip a value
     {my $i = newChip(name=>"not");
         $i-> inputBits('i',     1);
         $i->   notBits(qw(n i));
         $i->outputBits(qw(o n));
    
      my $o = newChip(name=>"outer");
         $o->inputBits('i', 1); $o->outputBits(qw(n i));
         $o->inputBits('I', 1); $o->outputBits(qw(N I));
    
      my %i = connectBits($i, 'i', $o, 'n');
      my %o = connectBits($i, 'o', $o, 'I');
    
      $o->install($i, {%i}, {%o});  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my %d = $o->setBits('i', 1);
      my $s = $o->simulate({%d}, svg=>q(notb1), pngs=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  2);
      is_deeply($s->values, {"(not 1 n_1)"=>0, "i_1"=>1, "N_1"=>0 });
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notb1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notb1_1.png">
</div>

# Visualize

Visualize the [chip](https://en.wikipedia.org/wiki/Integrated_circuit) in various ways.

## print   ($chip, %options)

Dump the [logic gates](https://en.wikipedia.org/wiki/Logic_gate) present on a [chip](https://en.wikipedia.org/wiki/Integrated_circuit).

       Parameter  Description
    1  $chip      Chip
    2  %options   Gates

**Example:**

    if (1)                                                                           
     {my $c = Silicon::Chip::newChip(title=>"And gate");
      $c->input ("i1");
      $c->input ("i2");
      $c->and   ("and1", [qw(i1 i2)]);
      $c->output("o", "and1");
      my $s = $c->simulate({i1=>1, i2=>1}, svg=>"andGate", pngs=>1, gsx=>1, gsy=>1);
      ok($s->checkLevelsMatch);
    
    
      is_deeply($c->print, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    i1                              :     input                           i1
    i2                              :     input                           i2
    and1                            :     and                             i1 i2
    o                               :     output                          and1
    END
    
    
      is_deeply($s->print, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    i1                              :   1 input                           i1
    i2                              :   1 input                           i2
    and1                            :   1 and                             i1 i2
    o                               :   1 output                          and1
    END
     }
    

## Silicon::Chip::Simulation::print($sim, %options)

Print simulation results as text.

       Parameter  Description
    1  $sim       Simulation
    2  %options   Options

**Example:**

    if (1)                                                                           
     {my $c = Silicon::Chip::newChip(title=>"And gate");
      $c->input ("i1");
      $c->input ("i2");
      $c->and   ("and1", [qw(i1 i2)]);
      $c->output("o", "and1");
      my $s = $c->simulate({i1=>1, i2=>1}, svg=>"andGate", pngs=>1, gsx=>1, gsy=>1);
      ok($s->checkLevelsMatch);
    
      is_deeply($c->print, <<END);
    i1                              :     input                           i1
    i2                              :     input                           i2
    and1                            :     and                             i1 i2
    o                               :     output                          and1
    END
    
      is_deeply($s->print, <<END);
    i1                              :   1 input                           i1
    i2                              :   1 input                           i2
    and1                            :   1 and                             i1 i2
    o                               :   1 output                          and1
    END
     }
    

## GDS2

Graphic Design System Layout for a chip which can be visualized using KLayout.

# Basic Circuits

Some well known basic circuits.

## n   ($c, $i)

Gate name from single index.

       Parameter  Description
    1  $c         Gate name
    2  $i         Bit number

**Example:**

    if (1)                                                                           
    
     {is_deeply( n(a,1),   "a_1");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      is_deeply(nn(a,1,2), "a_1_2");
     }
    

## nn  ($c, $i, $j)

Gate name from double index.

       Parameter  Description
    1  $c         Gate name
    2  $i         Word number
    3  $j         Bit number

**Example:**

    if (1)                                                                           
     {is_deeply( n(a,1),   "a_1");
    
      is_deeply(nn(a,1,2), "a_1_2");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

     }
    

## Comparisons

Compare unsigned binary integers of specified bit widths.

### compareEq   ($chip, $output, $a, $b, %options)

Compare two unsigned binary integers of a specified width returning **1** if they are equal else **0**.

       Parameter  Description
    1  $chip      Chip
    2  $output    Name of component also the output bus
    3  $a         First integer
    4  $b         Second integer
    5  %options   Options

**Example:**

    if (1)                                                                            # Compare unsigned integers
     {my $B = 2;
    
      my $c = Silicon::Chip::newChip(title=><<"END");
    $B Bit Compare Equal
    END
      $c->inputBits($_, $B) for qw(a b);                                            # First and second numbers
    
      $c->compareEq(qw(o a b));                                                     # Compare equals  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $c->output   (qw(out o));                                                     # Comparison result
    
      for   my $i(0..2**$B-1)                                                       # Each possible number
       {for my $j(0..2**$B-1)                                                       # Each possible number
         {my %a = $c->setBits('a', $i);                                             # Number a
          my %b = $c->setBits('b', $j);                                             # Number b
    
          my @T = $i == 1 && $j==1 ? (svg=>q(CompareEq), pngs=>1) : ();
          my $s = $c->simulate({%a, %b}, @T);                                       # Svg drawing of layout
          ok($s->checkLevelsMatch) if @T;
          is_deeply($s->value("out"), $i == $j ? 1 : 0);                            # Equal
          is_deeply($s->steps, 3);                                                  # Number of steps to stability
         }
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareEq.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareEq_1.png">
</div>

### compareGt   ($chip, $output, $a, $b, %options)

Compare two unsigned binary integers and return **1** if the first integer is more than **b** else **0**.

       Parameter  Description
    1  $chip      Chip
    2  $output    Name of component also the output bus
    3  $a         First integer
    4  $b         Second integer
    5  %options   Options

**Example:**

    if (gitHub)                                                                      # Compare 8 bit unsigned integers 'a' > 'b' - the pins used to input 'a' must be alphabetically less than those used for 'b'
     {my $B = 3;
      my $c = Silicon::Chip::newChip(title=><<END);
    $B Bit Compare more than
    END
      $c->inputBits($_, $B) for qw(a b);                                            # First and second numbers
    
      $c->compareGt(qw(o a b));                                                     # Compare more than  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $c->output   (qw(out o));                                                     # Comparison result
    
      for   my $i(0..2**$B-1)                                                       # Each possible number
       {for my $j(0..2**$B-1)                                                       # Each possible number
         {#$i = 2; $j = 1;
          my %a = $c->setBits('a', $i);                                             # Number a
          my %b = $c->setBits('b', $j);                                             # Number b
          my $T = $i==2&&$j==1;
          my @T = $T ? (svg=>q(CompareGt), pngs=>1, spaceDx=>1, borderDy=>2) : ();  # Svg drawing of layout
          my $s = $c->simulate({%a, %b}, @T);                                       # Svg drawing of layout
          ok($s->checkLevelsMatch) if @T;
          is_deeply($s->value("out"), $i > $j ? 1 : 0);                             # More than
          is_deeply($s->steps, 8);                                                  # Number of steps to stability
         }
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareGt.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareGt_1.png">
</div>

### compareLt   ($chip, $output, $a, $b, %options)

Compare two unsigned binary integers **a**, **b** of a specified width. Output **out** is **1** if **a** is less than **b** else **0**.

       Parameter  Description
    1  $chip      Chip
    2  $output    Name of component also the output bus
    3  $a         First integer
    4  $b         Second integer
    5  %options   Options

**Example:**

    if (1)                                                                           # Compare 8 bit unsigned integers 'a' < 'b' - the pins used to input 'a' must be alphabetically less than those used for 'b'
     {my $B = 3;
      my $c = Silicon::Chip::newChip(title=><<"END");
    $B Bit Compare Less Than
    END
      $c->inputBits($_, $B) for qw(a b);                                            # First and second numbers
    
      $c->compareLt(qw(o a b));                                                     # Compare less than  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $c->output   (qw(out o));                                                     # Comparison result
    
      for   my $i(0..2**$B-1)                                                       # Each possible number
       {for my $j(0..2**$B-1)                                                       # Each possible number
         {my %a = $c->setBits('a', $i);                                             # Number a
          my %b = $c->setBits('b', $j);                                             # Number b
          my $T = $i==2&&$j==1;
          my @T = $T ? (svg=>q(CompareLt), pngs=>1, spaceDx=>1, borderDy=>2) : ();  # Svg drawing of layout
          my $s = $c->simulate({%a, %b}, @T);                                       # Svg drawing of layout
          ok($s->checkLevelsMatch) if @T;
          is_deeply($s->value("out"), $i < $j ? 1 : 0);                             # More than
          is_deeply($s->steps, 8);                                                  # Number of steps to stability
         }
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareLt.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareLt_1.png">
</div>

### chooseFromTwoWords  ($chip, $output, $a, $b, $choose, %options)

Choose one of two words based on a bit.  The first word is chosen if the bit is **0** otherwise the second word is chosen.

       Parameter  Description
    1  $chip      Chip
    2  $output    Name of component also the chosen word
    3  $a         The first word
    4  $b         The second word
    5  $choose    The choosing bit
    6  %options   Options

**Example:**

    if (1)                                                                          
     {my $B = 4;
    
      my $c = newChip();
         $c->inputBits('a', $B);                                                    # First word
         $c->inputBits('b', $B);                                                    # Second word
         $c->input    ('c');                                                        # Chooser
    
         $c->chooseFromTwoWords(qw(o a b c));                                       # Generate gates  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits('out', 'o');                                                # Result
    
      my %a = setBits($c, 'a', 0b0011);
      my %b = setBits($c, 'b', 0b1100);
    
    
      my $s = $c->simulate({%a, %b, c=>1}, svg=>q(chooseFromTwoWords), pngs=>1, minHeight=>18, spaceDy=>2);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  9);
      is_deeply($s->bInt('out'), 0b1100);
    
      my $t = $c->simulate({%a, %b, c=>0});
      is_deeply($t->steps,               9);
      is_deeply($t->bInt('out'), 0b0011);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/chooseFromTwoWords.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/chooseFromTwoWords_1.png">
</div>

### enableWord  ($chip, $output, $a, $enable, %options)

Output a word or zeros depending on a choice bit.  The first word is chosen if the choice bit is **1** otherwise all zeroes are chosen.

       Parameter  Description
    1  $chip      Chip
    2  $output    Name of component also the chosen word
    3  $a         The first word
    4  $enable    The second word
    5  %options   The choosing bit

**Example:**

    if (1)                                                                          
     {my $B = 4;
    
      my $c = newChip();
         $c->inputBits ('a', $B);                                                   # Word
         $c->input     ('c');                                                       # Choice bit
    
         $c->enableWord(qw(o a c));                                                 # Generate gates  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits(qw(out o));                                                 # Result
    
      my %a = setBits($c, 'a', 3);
    
    
      my $s = $c->simulate({%a, c=>1}, svg=>q(enableWord), pngs=>1, spaceDy=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      ok($s->checkLevelsMatch);
      is_deeply($s->steps,       4);
      is_deeply($s->bInt('out'), 3);
    
      my $t = $c->simulate({%a, c=>0});
      is_deeply($t->steps,       4);
      is_deeply($t->bInt('out'), 0);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/enableWord.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/enableWord_1.png">
</div>

## Masks

Point masks and monotone masks. A point mask has a single **1** in a sea of **0**s as in **00100**.  A monotone mask has zero or more **0**s followed by all **1**s as in: **00111**.

### pointMaskToInteger  ($chip, $output, $input, %options)

Convert a mask **i** known to have at most a single bit on - also known as a **point mask** - to an output number **a** representing the location in the mask of the bit set to **1**. If no such bit exists in the point mask then output number **a** is **0**.

       Parameter  Description
    1  $chip      Chip
    2  $output    Output name
    3  $input     Input mask
    4  %options   Options

**Example:**

    if (gitHub)                                                                     
     {my $B = 4;
      my $N = 2**$B-1;
    
      my $c = Silicon::Chip::newChip(title=><<"END");
    $B bits point mask to integer
    END
      $c->inputBits         (qw(    i), $N);                                        # Mask with no more than one bit on
    
      $c->pointMaskToInteger(qw(o   i));                                            # Convert  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $c->outputBits        (qw(out o));                                            # Mask with no more than one bit on
    
     for my $i(0..$N)                                                               # Each position of mask
       {my %i = setBits($c, 'i', $i ? 1<<($i-1) : 0);                               # Point in each position with zero representing no position
        my $T = $i == 5;
    
        my @T = $T ? (svg=>q(pointMaskToInteger), pngs=>2, newChange=>1, gsx=>3, gsy=>3, spaceDx=>2, spaceDy=>2, newChange=>1, borderDy=>4) : ();  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        my $s = $c->simulate(\%i, @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->steps, 6);
        my %o = $s->values->%*;                                                     # Output bits
        my $n = eval join '', '0b', map {$o{n(o,$_)}} reverse 1..$B;                # Output bits as number
        is_deeply($n, $i);
        is_deeply($s->levels, 2) if $T;
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/pointMaskToInteger.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/pointMaskToInteger_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/pointMaskToInteger_2.png">
</div>

### integerToPointMask  ($chip, $output, $input, %options)

Convert an integer **i** of specified width to a point mask **m**. If the input integer is **0** then the mask is all zeroes as well.

       Parameter  Description
    1  $chip      Chip
    2  $output    Output name
    3  $input     Input mask
    4  %options   Options

**Example:**

    if (gitHub)                                                                     
     {my $B = 3;
      my $N = 2**$B-1;
    
      my $c = Silicon::Chip::newChip(title=><<"END");
    $B bit integer to $N bit monotone mask.
    END
         $c->inputBits         (qw(  i), $B);                                       # Input bus
    
         $c->integerToPointMask(qw(m i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits        (qw(o m));
    
      for my $i(0..$N)                                                              # Each position of mask
       {my %i = setBits($c, 'i', $i);
    
        my @T = $i == 5 ? (svg=>q(integerToPointMask), pngs=>2, placeFirst=>1):();  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        my $s = $c->simulate(\%i, @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->steps, 9);
    
        my $r = $s->bInt('o');                                                      # Mask values
        is_deeply($r, $i ? 1<<($i-1) : 0);                                          # Expected mask
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/integerToPointMask.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/integerToPointMask_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/integerToPointMask_2.png">
</div>

### monotoneMaskToInteger   ($chip, $output, $input, %options)

Convert a monotone mask **i** to an output number **r** representing the location in the mask of the bit set to **1**. If no such bit exists in the point then output in **r** is **0**.

       Parameter  Description
    1  $chip      Chip
    2  $output    Output name
    3  $input     Input mask
    4  %options   Options

**Example:**

    if (gitHub)                                                                     
     {my $B = 4;
      my $N = 2**$B-1;
    
      my $c = Silicon::Chip::newChip(title=><<"END");
    $N bit monotone mask to $B bit integer
    END
         $c->inputBits            ('i',     $N);
    
         $c->monotoneMaskToInteger(qw(m i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits           (qw(o m));
    
      for my $i(0..$N-1)                                                            # Each monotone mask
       {my %i = setBits($c, 'i', $i > 0 ? 1<<$i-1 : 0);
    
        my @T = $i == 5 ? (svg=>q(monotoneMaskToInteger), pngs=>2, placeFirst=>1) : ();  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        my $s = $c->simulate(\%i, @T);
        ok($s->checkLevelsMatch) if @T;
    
        is_deeply($s->steps, 9);
        is_deeply($s->bInt('m'), $i);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToInteger.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToInteger_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToInteger_2.png">
</div>

### monotoneMaskToPointMask ($chip, $output, $input, %options)

Convert a monotone mask **i** to a point mask **o** representing the location in the mask of the first bit set to **1**. If the monotone mask is all **0**s then point mask is too.

       Parameter  Description
    1  $chip      Chip
    2  $output    Output name
    3  $input     Input mask
    4  %options   Options

**Example:**

    if (gitHub)                                                                     
     {my $B = 4;
    
      my $c = newChip();
         $c->inputBits('m', $B);                                                    # Monotone mask
    
         $c->monotoneMaskToPointMask(qw(o m));                                      # Generate gates  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits('out', 'o');                                                # Point mask
    
      for my $i(0..$B)
       {my %m = $c->setBits('m', eval '0b'.(1 x $i).('0' x ($B-$i)));
    
        my @T = $i == 2 ? (svg=>q(monotoneMaskToPointMask), pngs=>1) : ();  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        my $s = $c->simulate({%m},  @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->steps,  3) if @T;
        is_deeply($s->bInt('out'), $i ? (1<<($B-1)) / (1<<($i-1)) : 0);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToPointMask.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToPointMask_1.png">
</div>

### integerToMonotoneMask   ($chip, $output, $input, %options)

Convert an integer **i** of specified width to a monotone mask **m**. If the input integer is **0** then the mask is all zeroes.  Otherwise the mask has **i-1** leading zeroes followed by all ones thereafter.

       Parameter  Description
    1  $chip      Chip
    2  $output    Output name
    3  $input     Input mask
    4  %options   Options

**Example:**

    if (gitHub)                                                                     
     {my $B = 4;
      my $N = 2**$B-1;
    
      my $c = Silicon::Chip::newChip(title=><<"END");
    Convert $B bit integer to $N bit monotone mask
    END
         $c->inputBits            ('i', $B);                                        # Input gates
    
         $c->integerToMonotoneMask(qw(m i));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits           (qw(o m));                                        # Output gates
    
      for my $i(0..$N)                                                              # Each position of mask
       {my %i = setBits($c, 'i', $i);                                               # The number to convert
        my $s = $c->simulate(\%i);
        is_deeply($s->steps, 19);
        is_deeply($s->bInt('o'), $i > 0 ? ((1<<$N)-1)>>($i-1)<<($i-1) : 0);         # Expected mask
       }
     }
    

### chooseWordUnderMask ($chip, $output, $input, $mask, %options)

Choose one of a specified number of words **w**, each of a specified width, using a point mask **m** placing the selected word in **o**.  If no word is selected then **o** will be zero.

       Parameter  Description
    1  $chip      Chip
    2  $output    Output
    3  $input     Inputs
    4  $mask      Mask
    5  %options   Options

**Example:**

    if (1)                                                                            
     {my $B = 3; my $W = 4;
    
      my $c = Silicon::Chip::newChip(title=><<"END");
    Choose one of $W words of $B bits
    END
         $c->inputWords         ('w',       $W, $B);
         $c->inputBits          ('m',       $W);
    
         $c->chooseWordUnderMask(qw(W w m));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits         (qw(o W));
    
      my %i = setWords($c, 'w', 0b000, 0b001, 0b010, 0b0100);
      my %m = setBits ($c, 'm', 1<<2);                                              # Choose the third word
    
      my $s = $c->simulate({%i, %m}, svg=>q(choose), pngs=>2);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  6);
      is_deeply($s->bInt('o'), 0b010);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_2.png">
</div>

### findWord($chip, $output, $key, $words, %options)

Choose one of a specified number of words **w**, each of a specified width, using a key **k**.  Return a point mask **o** indicating the locations of the key if found or or a mask equal to all zeroes if the key is not present.

       Parameter  Description
    1  $chip      Chip
    2  $output    Found point mask
    3  $key       Key
    4  $words     Words to search
    5  %options   Options

**Example:**

    if (gitHub)                                                                     
     {my $B = 3; my $W = 2**$B-1;
    
      my $c = Silicon::Chip::newChip(title=><<END);
    Search $W words of $B bits
    END
         $c->inputBits ('k',       $B);                                             # Search key
         $c->inputWords('w',       2**$B-1, $B);                                    # Words to search
    
         $c->findWord  (qw(m k w));                                                 # Find the word  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

         $c->outputBits(qw(M m));                                                   # Output mask
    
      my %w = setWords($c, 'w', reverse 1..$W);
    
      for my $k(0..$W)                                                              # Each possible key
       {my %k = setBits($c, 'k', $k);
    
        my @T = $k == 3 ? (svg=>q(findWord), pngs=>3) : ();  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

        my $s = $c->simulate({%k, %w}, @T);
        ok($s->checkLevelsMatch) if @T;
        is_deeply($s->steps,  7);
        is_deeply($s->bInt('M'),$k ? 2**($W-$k) : 0);
       }
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/findWord.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/findWord_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/findWord_2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/findWord_3.png">
</div>

# Simulate

Simulate the behavior of the [chip](https://en.wikipedia.org/wiki/Integrated_circuit) given a set of values on its input gates.

## setBits ($chip, $name, $value, %options)

Set an array of input gates to a number prior to running a simulation.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of input gates
    3  $value     Number to set to
    4  %options   Options

**Example:**

    if (1)                                                                           # Compare two 4 bit unsigned integers 'a' > 'b' - the pins used to input 'a' must be alphabetically less than those used for 'b'
     {my $B = 4;                                                                    # Number of bits
      my $c = Silicon::Chip::newChip(title=><<"END", expand=>1);
    $B Bit Compare Greater Than
    END
      $c->inputBits("a", $B);                                                       # First number
      $c->inputBits("b", $B);                                                       # Second number
      $c->nxor (n(e,$_), n(a,$_), n(b,$_)) for 1..$B-1;                             # Test each bit for equality
      $c->gt   (n(g,$_), n(a,$_), n(b,$_)) for 1..$B;                               # Test each bit pair for greater
    
      for my $b(2..$B)
       {$c->and(n(c,$b), [(map {n(e, $_)} 1..$b-1), n(g,$b)], undef, debug=>1);     # Greater on one bit and all preceding bits are equal
       }
    
      $c->or    ("or",  [n(g,1), (map {n(c, $_)} 2..$B)]);                          # Any set bit indicates that 'a' is more than 'b'
      $c->output("out", "or");                                                      # Output 1 if a > b else 0
    
    
      my %a = $c->setBits('a', 0);                                                  # Number a  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my %b = $c->setBits('b', 0);                                                  # Number b  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my $s = $c->simulate({%a, %b, n(a,2)=>1, n(b,2)=>1}, svg=>q(gt), pngs=>1, gsx=>2, gsy=>2, spaceDx=>1, borderDy=>1, minHeight=>18, newChange=>1); # Compare two numbers a, b to see if a > b
      ok($s->checkLevelsMatch);
      is_deeply($s->value("out"), 0);
      is_deeply($s->levels,    1);
      is_deeply($s->length, 1832);
    
      my $t = $c->simulate({%a, %b, n(a,2)=>1});
      is_deeply($t->value("out"), 1);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/gt.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/gt_1.png">
</div>

    if (1)                                                                            
     {my $B = 3; my $W = 4;
    
      my $c = Silicon::Chip::newChip(title=><<"END");
    Choose one of $W words of $B bits
    END
         $c->inputWords         ('w',       $W, $B);
         $c->inputBits          ('m',       $W);
         $c->chooseWordUnderMask(qw(W w m));
         $c->outputBits         (qw(o W));
    
      my %i = setWords($c, 'w', 0b000, 0b001, 0b010, 0b0100);
    
      my %m = setBits ($c, 'm', 1<<2);                                              # Choose the third word  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my $s = $c->simulate({%i, %m}, svg=>q(choose), pngs=>2);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  6);
      is_deeply($s->bInt('o'), 0b010);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_2.png">
</div>

## setWords($chip, $name, @values)

Set an array of arrays of gates to an array of numbers prior to running a simulation.

       Parameter  Description
    1  $chip      Chip
    2  $name      Name of input gates
    3  @values    Number of bits in each array element

**Example:**

    if (1)                                                                            
     {my $B = 3; my $W = 4;
    
      my $c = Silicon::Chip::newChip(title=><<"END");
    Choose one of $W words of $B bits
    END
         $c->inputWords         ('w',       $W, $B);
         $c->inputBits          ('m',       $W);
         $c->chooseWordUnderMask(qw(W w m));
         $c->outputBits         (qw(o W));
    
    
      my %i = setWords($c, 'w', 0b000, 0b001, 0b010, 0b0100);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      my %m = setBits ($c, 'm', 1<<2);                                              # Choose the third word
    
      my $s = $c->simulate({%i, %m}, svg=>q(choose), pngs=>2);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  6);
      is_deeply($s->bInt('o'), 0b010);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_2.png">
</div>

## connectBits ($oc, $o, $ic, $i, %options)

Create a connection list connecting a set of output bits on the one chip to a set of input bits on another chip.

       Parameter  Description
    1  $oc        First chip
    2  $o         Name of gates on first chip
    3  $ic        Second chip
    4  $i         Names of gates on second chip
    5  %options   Options

**Example:**

    if (1)                                                                            # Install one chip inside another chip, specifically one chip that performs NOT is installed once to flip a value
     {my $i = newChip(name=>"not");
         $i-> inputBits('i',     1);
         $i->   notBits(qw(n i));
         $i->outputBits(qw(o n));
    
      my $o = newChip(name=>"outer");
         $o->inputBits('i', 1); $o->outputBits(qw(n i));
         $o->inputBits('I', 1); $o->outputBits(qw(N I));
    
    
      my %i = connectBits($i, 'i', $o, 'n');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my %o = connectBits($i, 'o', $o, 'I');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $o->install($i, {%i}, {%o});
      my %d = $o->setBits('i', 1);
      my $s = $o->simulate({%d}, svg=>q(notb1), pngs=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  2);
      is_deeply($s->values, {"(not 1 n_1)"=>0, "i_1"=>1, "N_1"=>0 });
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notb1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notb1_1.png">
</div>

## connectWords($oc, $o, $ic, $i, $words, $bits, %options)

Create a connection list connecting a set of words on the outer chip to a set of words on the inner chip.

       Parameter  Description
    1  $oc        First chip
    2  $o         Name of gates on first chip
    3  $ic        Second chip
    4  $i         Names of gates on second chip
    5  $words     Number of words to connect
    6  $bits      Options
    7  %options

**Example:**

    if (1)                                                                           # Install one chip inside another chip, specifically one chip that performs NOT is installed three times sequentially to flip a value
     {my $i = newChip(name=>"not");
         $i-> inputWords('i', 1, 1);
         $i->   notWords(qw(n i));
         $i->outputWords(qw(o n));
    
      my $o = newChip(name=>"outer");
         $o->inputWords('i', 1, 1); $o->output(nn('n', 1, 1), nn('i', 1, 1));
         $o->inputWords('I', 1, 1); $o->output(nn('N', 1, 1), nn('I', 1, 1));
    
    
      my %i = connectWords($i, 'i', $o, 'n', 1, 1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    
      my %o = connectWords($i, 'o', $o, 'I', 1, 1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      $o->install($i, {%i}, {%o});
      my %d = $o->setWords('i', 1);
      my $s = $o->simulate({%d}, svg=>q(notw1), pngs=>1);
      ok($s->checkLevelsMatch);
    
      is_deeply($s->steps,  2);
      is_deeply($s->values, { "(not 1 n_1_1)" => 0, "i_1_1" => 1, "N_1_1" => 0 });
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notw1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notw1_1.png">
</div>

## Silicon::Chip::Simulation::value($simulation, $name, %options)

Get the value of a gate as seen in a simulation.

       Parameter    Description
    1  $simulation  Chip
    2  $name        Gate
    3  %options     Options

**Example:**

    if (1)                                                                          # Internal input gate   
     {my $c = newChip();
         $c->input ('i');                                                           # Input
         $c->input ('j');                                                           # Internal input which we will connect to later
         $c->output(qw(o j));                                                       # Output
    
         $c->connectInput(qw(j i));
    
      my $s = $c->simulate({i=>1}, svg=>q(connectInput), pngs=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  1);
      is_deeply($s->value("j"), undef);
      is_deeply($s->value("o"), 1);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInput.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInput_1.png">
</div>

    if (1)                                                                           # Internal input gate   
     {my @n = qw(3 2 1 2 3);
      my $c = newChip();
         $c->words('i', 2, @n);                                                     # Input
         $c->outputWords(qw(o i));                                                  # Output
      my $s = $c->simulate({}, svg=>q(words), pngs=>1, minHeight=>10);
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,  2);
      is_deeply([$s->wInt("i")], [@n]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words_1.png">
</div>

## Silicon::Chip::Simulation::bInt ($simulation, $output, %options)

Represent the state of bits in the simulation results as an unsigned binary integer.

       Parameter    Description
    1  $simulation  Chip
    2  $output      Name of gates on bus
    3  %options     Options

**Example:**

    if (1)                                                                             
     {my $W = 8;
      my $i = newChip();
         $i->inputBits('i', $W);
         $i->notBits   (qw(n i));
         $i->outputBits(qw(o n));
    
      my $o = newChip(name=>"outer");
         $o->inputBits ('a', $W);
         $o->outputBits(qw(A a));
         $o->inputBits ('b', $W);
         $o->outputBits(qw(B b));
    
      my %i = connectBits($i, 'i', $o, 'A');
      my %o = connectBits($i, 'o', $o, 'b');
      $o->install($i, {%i}, {%o});
    
      my %d = setBits($o, 'a', 0b10110);
      my $s = $o->simulate({%d}, svg=>q(not), pngs=>1, gsx=>1, gsy=>1, minHeight=>2*$W, newChange=>1);
      ok($s->checkLevelsMatch);
      is_deeply($s->bInt('B'), 0b11101001);
      is_deeply($s->length,  80);
      is_deeply($s->area,   100);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not_1.png">
</div>

## Silicon::Chip::Simulation::wInt ($simulation, $output, %options)

Represent the state of words in the simulation results as an array of unsigned binary integer.

       Parameter    Description
    1  $simulation  Chip
    2  $output      Name of gates on bus
    3  %options     Options

**Example:**

    if (1)                                                                                
     {my @b = ((my $W = 4), (my $B = 3));
    
      my $c = newChip();
         $c->inputWords ('i',      @b);
         $c->outputWords(qw(o i));
    
      my %d = setWords($c, 'i', 0b000, 0b001, 0b010, 0b011);
      my $s = $c->simulate({%d}, svg=>q(words2), pngs=>1, newChange=>1, minHeight=>12);
      ok($s->checkLevelsMatch);
      is_deeply([$s->wInt('o')], [0..3]);
      is_deeply([$s->wordXToInteger('o')], [10, 12, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
</div>

## Silicon::Chip::Simulation::wordXToInteger   ($simulation, $output, %options)

Represent the state of words in the simulation results as an array of unsigned binary integer.

       Parameter    Description
    1  $simulation  Chip
    2  $output      Name of gates on bus
    3  %options     Options

**Example:**

    if (1)                                                                                
     {my @b = ((my $W = 4), (my $B = 3));
    
      my $c = newChip();
         $c->inputWords ('i',      @b);
         $c->outputWords(qw(o i));
    
      my %d = setWords($c, 'i', 0b000, 0b001, 0b010, 0b011);
      my $s = $c->simulate({%d}, svg=>q(words2), pngs=>1, newChange=>1, minHeight=>12);
      ok($s->checkLevelsMatch);
      is_deeply([$s->wInt('o')], [0..3]);
      is_deeply([$s->wordXToInteger('o')], [10, 12, 0]);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
</div>

## Silicon::Chip::Simulation::checkLevelsMatch ($simulation, %options)

Check that the specified number of levels matches that specified by the pngs parameter.  The pngs paramneter tells us howmany drawings to make - one per level - ideally this should match the actual number of levels.

       Parameter    Description
    1  $simulation  Simulation
    2  %options     Options

**Example:**

    if (1)                                                                          
     {my $N = 2;
      my $c = Silicon::Chip::newChip;
      $c->input (qw(  i));
      $c->not   (qw(n i));
      $c->output(qw(o n));
      my $s = $c->simulate({i=>1}, svg=>q(gdsTest), pngs=>1);
      ok($s->checkLevelsMatch);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/gdsTest.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/gdsTest_1.png">
</div>

## simulate($chip, $inputs, %options)

Simulate the action of the [logic gates](https://en.wikipedia.org/wiki/Logic_gate) on a [chip](https://en.wikipedia.org/wiki/Integrated_circuit) for a given set of inputs until the output value of each [logic gate](https://en.wikipedia.org/wiki/Logic_gate) stabilizes.  Draw the simulated circuit using the timeing information to determine the layout of the gates.

       Parameter  Description
    1  $chip      Chip
    2  $inputs    Hash of input names to values
    3  %options   Options

**Example:**

    if (1)                                                                           # 4 bit equal 
     {my $B = 4;                                                                    # Number of bits
    
      my $c = Silicon::Chip::newChip(title=><<"END");                               # Create chip
    $B Bit Equals
    END
      $c->input ("a$_")                 for 1..$B;                                  # First number
      $c->input ("b$_")                 for 1..$B;                                  # Second number
    
      $c->nxor  ("e$_", "a$_", "b$_")   for 1..$B;                                  # Test each bit for equality
      $c->and   ("and", {map{$_=>"e$_"}     1..$B});                                # And tests together to get total equality
    
      $c->output("out", "and");                                                     # Output gate
    
    
      my $s = $c->simulate({a1=>1, a2=>0, a3=>1, a4=>0,                             # Input gate values  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

                            b1=>1, b2=>0, b3=>1, b4=>0},
                            svg=>q(Equals), pngs=>1, spaceDy=>1);                   # Svg drawing of layout
      ok($s->checkLevelsMatch);
      is_deeply($s->steps,        4);                                               # Steps
      is_deeply($s->value("out"), 1);                                               # Out is 1 for equals
    
    
      my $t = $c->simulate({a1=>1, a2=>1, a3=>1, a4=>0,  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

                            b1=>1, b2=>0, b3=>1, b4=>0});
      is_deeply($t->value("out"), 0);                                               # Out is 0 for not equals
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals_1.png">
</div>

    if (1)                                                                          
     {my $N = 2;
      my $c = Silicon::Chip::newChip;
      $c->input (n('i', $_))                              for 1..$N;
      $c->xor   (n("x", $_),   n('i', $_-1), n('i', $_))  for 2..$N;
      $c->and   ('a',    [map {n('x', $_)}                    2..$N]);
      $c->output('o',  'a');
      my %a = map {(n('i', $_)=> $_ % 2)} 1..$N;
    
      my $s = $c->simulate({%a}, svg=>q(square1), pngs=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

      ok($s->checkLevelsMatch);
     }
    

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/square1.png">
</div>

<div>
    <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/square1_1.png">
</div>

# Hash Definitions

## Silicon::Chip Definition

Kept going until nothing changed in the simulation

### Output fields

#### Gate

Definition of gate. Capital G because of a slight default in [Data::Table::Text::updateDocumentation](https://metacpan.org/pod/Data%3A%3ATable%3A%3AText%3A%3AupdateDocumentation) that reports a duplicate attribute if we use lowercase g.

#### area

Area of chip

#### bottomUp

Normally the gates are laid out top down but sometimes it is better to lay them out bottom up

#### changeStep

True if we are stepping from one change level to the next

#### changed

Last time this gate changed

#### chip

Chip being simulated

#### expand

Expand gates so that they never have more than two inputs

#### fibers

Fibers after collapse

#### gates

Gates in chip

#### h

Height of gate

#### height

Height of chip in cells

#### inPlay

Squares in play for collapsing

#### inputs

Outputs of outer chip to inputs of inner chip

#### installs

Chips installed within the chip

#### io

Whether an input/output gate or not

#### layout

Layout

#### length

Total length of wiring on chip in cells

#### levels

Number of levels of wiring

#### mask

Masks for chip if they have been produced

#### name

Name assigned to gate - or a number if no name was specified

#### options

Options used to perform simulation

#### output

Output pins as an array of pin names.  The first pin name is used as the name of the gate unless an overriding name=>option has been supplied. Output gate names are unique across the chip.  When a sub chip is installed we rename the copied gates to maintain this invariant.

#### outputs

Outputs of inner chip to inputs of outer chip

#### positions

Positions array

#### positionsArray

Position array

#### positionsHash

Position hash

#### seq

Sequence number for this gate

#### sizeBits

Sizes of bit buses

#### sizeWords

Sizes of word buses

#### steps

Number of steps to reach stability

#### thickness

Width of the thickest fiber bundle

#### title

Title if known

#### type

Gate type

#### values

Values of every output at point of stability

#### w

Width of gate

#### width

Width of chip in cells

#### wiring

Wiring

#### x

X position of left upper corner of gate

#### y

Y position of left upper corner of gate

# Private Methods

## AUTOLOAD($chip, @options)

Autoload by [logic gate](https://en.wikipedia.org/wiki/Logic_gate) name to provide a more readable way to specify the [logic gates](https://en.wikipedia.org/wiki/Logic_gate) on a [chip](https://en.wikipedia.org/wiki/Integrated_circuit).

       Parameter  Description
    1  $chip      Chip
    2  @options   Options

## Silicon::Chip::LayoutLinear::draw   ($layout, %options)

Draw a mask for the gates.

       Parameter  Description
    1  $layout    Layout
    2  %options   Options

## gds2($chip, $layout, $wiring, %options)

Draw the chip using GDS2

       Parameter  Description
    1  $chip      Chip
    2  $layout    Layout
    3  $wiring    Wiring
    4  %options   Options

# Index

1 [andBits](#andbits) - **and** a bus made of bits.

2 [andWords](#andwords) - **and** a bus made of words to produce a single word.

3 [andWordsX](#andwordsx) - **and** a bus made of words by and-ing the corresponding bits in each word to make a single word.

4 [AUTOLOAD](#autoload) - Autoload by [logic gate](https://en.wikipedia.org/wiki/Logic_gate) name to provide a more readable way to specify the [logic gates](https://en.wikipedia.org/wiki/Logic_gate) on a [chip](https://en.wikipedia.org/wiki/Integrated_circuit).

5 [bits](#bits) - Create a bus set to a specified number.

6 [chooseFromTwoWords](#choosefromtwowords) - Choose one of two words based on a bit.

7 [chooseWordUnderMask](#choosewordundermask) - Choose one of a specified number of words **w**, each of a specified width, using a point mask **m** placing the selected word in **o**.

8 [compareEq](#compareeq) - Compare two unsigned binary integers of a specified width returning **1** if they are equal else **0**.

9 [compareGt](#comparegt) - Compare two unsigned binary integers and return **1** if the first integer is more than **b** else **0**.

10 [compareLt](#comparelt) - Compare two unsigned binary integers **a**, **b** of a specified width.

11 [connectBits](#connectbits) - Create a connection list connecting a set of output bits on the one chip to a set of input bits on another chip.

12 [connectInput](#connectinput) - Connect a previously defined input gate to the output of another gate on the same chip.

13 [connectInputBits](#connectinputbits) - Connect a previously defined input bit bus to another bit bus provided the two buses have the same size.

14 [connectInputWords](#connectinputwords) - Connect a previously defined input word bus to another word bus provided the two buses have the same size.

15 [connectWords](#connectwords) - Create a connection list connecting a set of words on the outer chip to a set of words on the inner chip.

16 [enableWord](#enableword) - Output a word or zeros depending on a choice bit.

17 [findWord](#findword) - Choose one of a specified number of words **w**, each of a specified width, using a key **k**.

18 [gate](#gate) - A [logic gate](https://en.wikipedia.org/wiki/Logic_gate) chosen from **possibleTypes**.

19 [gds2](#gds2) - Draw the chip using GDS2

20 [inputBits](#inputbits) - Create an **input** bus made of bits.

21 [inputWords](#inputwords) - Create an **input** bus made of words.

22 [install](#install) - Install a [chip](https://en.wikipedia.org/wiki/Integrated_circuit) within another [chip](https://en.wikipedia.org/wiki/Integrated_circuit) specifying the connections between the inner and outer [chip](https://en.wikipedia.org/wiki/Integrated_circuit).

23 [integerToMonotoneMask](#integertomonotonemask) - Convert an integer **i** of specified width to a monotone mask **m**.

24 [integerToPointMask](#integertopointmask) - Convert an integer **i** of specified width to a point mask **m**.

25 [monotoneMaskToInteger](#monotonemasktointeger) - Convert a monotone mask **i** to an output number **r** representing the location in the mask of the bit set to **1**.

26 [monotoneMaskToPointMask](#monotonemasktopointmask) - Convert a monotone mask **i** to a point mask **o** representing the location in the mask of the first bit set to **1**.

27 [n](#n) - Gate name from single index.

28 [nandBits](#nandbits) - **nand** a bus made of bits.

29 [newChip](#newchip) - Create a new [chip](https://en.wikipedia.org/wiki/Integrated_circuit).

30 [nn](#nn) - Gate name from double index.

31 [norBits](#norbits) - **nor** a bus made of bits.

32 [notBits](#notbits) - Create a **not** bus made of bits.

33 [notWords](#notwords) - Create a **not** bus made of words.

34 [orBits](#orbits) - **or** a bus made of bits.

35 [orWords](#orwords) - **or** a bus made of words to produce a single word.

36 [orWordsX](#orwordsx) - **or** a bus made of words by or-ing the corresponding bits in each word to make a single word.

37 [outputBits](#outputbits) - Create an **output** bus made of bits.

38 [outputWords](#outputwords) - Create an **output** bus made of words.

39 [pointMaskToInteger](#pointmasktointeger) - Convert a mask **i** known to have at most a single bit on - also known as a **point mask** - to an output number **a** representing the location in the mask of the bit set to **1**.

40 [print](#print) - Dump the [logic gates](https://en.wikipedia.org/wiki/Logic_gate) present on a [chip](https://en.wikipedia.org/wiki/Integrated_circuit).

41 [setBits](#setbits) - Set an array of input gates to a number prior to running a simulation.

42 [setSizeBits](#setsizebits) - Set the size of a bits bus.

43 [setSizeWords](#setsizewords) - Set the size of a bits bus.

44 [setWords](#setwords) - Set an array of arrays of gates to an array of numbers prior to running a simulation.

45 [Silicon::Chip::LayoutLinear::draw](#silicon-chip-layoutlinear-draw) - Draw a mask for the gates.

46 [Silicon::Chip::Simulation::bInt](#silicon-chip-simulation-bint) - Represent the state of bits in the simulation results as an unsigned binary integer.

47 [Silicon::Chip::Simulation::checkLevelsMatch](#silicon-chip-simulation-checklevelsmatch) - Check that the specified number of levels matches that specified by the pngs parameter.

48 [Silicon::Chip::Simulation::print](#silicon-chip-simulation-print) - Print simulation results as text.

49 [Silicon::Chip::Simulation::value](#silicon-chip-simulation-value) - Get the value of a gate as seen in a simulation.

50 [Silicon::Chip::Simulation::wInt](#silicon-chip-simulation-wint) - Represent the state of words in the simulation results as an array of unsigned binary integer.

51 [Silicon::Chip::Simulation::wordXToInteger](#silicon-chip-simulation-wordxtointeger) - Represent the state of words in the simulation results as an array of unsigned binary integer.

52 [simulate](#simulate) - Simulate the action of the [logic gates](https://en.wikipedia.org/wiki/Logic_gate) on a [chip](https://en.wikipedia.org/wiki/Integrated_circuit) for a given set of inputs until the output value of each [logic gate](https://en.wikipedia.org/wiki/Logic_gate) stabilizes.

53 [words](#words) - Create a word bus set to specified numbers.

# Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via **cpan**:

    sudo cpan install Silicon::Chip

# Author

[philiprbrenan@gmail.com](mailto:philiprbrenan@gmail.com)

[http://prb.appaapps.com](http://prb.appaapps.com)

# Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.
