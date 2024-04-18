#!/usr/bin/perl -I/home/phil/perl/cpan/SvgSimple/lib/ -I/home/phil/perl/cpan/SiliconChipLayout/lib/ -I/home/phil/perl/cpan/SiliconChipWiring/lib/ -I/home/phil/perl/cpan/Math-Intersection-Circle-Line/lib
#-------------------------------------------------------------------------------
# Design a silicon chip by combining gates and sub chips.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2023
#-------------------------------------------------------------------------------
# Possibly apply gsx/y spaceDx/y to individual gates.
use v5.34;
package Silicon::Chip;
our $VERSION = 20240331;                                                        # Version
use warnings FATAL => qw(all);
use strict;
use Carp qw(confess carp cluck);
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Silicon::Chip::Layout;
use Silicon::Chip::Wiring;
use Svg::Simple;
use GDS2;
use Time::HiRes qw(time);

makeDieConfess;

my sub maxSimulationSteps {100}                                                 # Maximum simulation steps
my sub gateNotIO          {0}                                                   # Not an input or output gate
my sub gateInternalInput  {1}                                                   # Input gate on an internal chip
my sub gateInternalOutput {2}                                                   # Output gate on an internal chip
my sub gateExternalInput  {3}                                                   # Input gate on the external chip
my sub gateExternalOutput {4}                                                   # Output gate on the external chip
my sub gateOuterInput     {5}                                                   # Input gate on the external chip connecting to the outer world
my sub gateOuterOutput    {6}                                                   # Output gate on the external chip connecting to the outer world

my $possibleTypes = q(and|continue|fanOut|gt|input|lt|nand|nor|not|nxor|one|or|output|xor|zero); # Substitute: possible gate types

sub debugMask {0}                                                               # Adds a grid and fiber names to a mask to help debug fibers if true.

#D1 Construct                                                                   # Construct a L<silicon> L<chip> using standard L<lgs>, components and sub chips combined via buses.

sub newChip(%)                                                                  # Create a new L<chip>.
 {my (%options) = @_;                                                           # Options
  lll $options{name} if $options{log} and $options{name};                       # Title
  !@_ or !ref($_[0]) or confess "Call as a sub not as a method";
  genHash(__PACKAGE__,                                                          # Chip description
    name      => $options{name}//$options{title} // "Unnamed chip: ".timeStamp, # Name of chip
    gates     => $options{gates} // {},                                         # Gates in chip
    installs  => $options{installs} // [],                                      # Chips installed within the chip
    title     => $options{title},                                               # Title if known
    sizeBits  => {},                                                            # Sizes of bit buses
    sizeWords => {},                                                            # Sizes of word buses
    expand    => $options{expand} // 1,                                         # Expand gates so that they never have more than two inputs
   );
 }

my $gateSeq = 0;                                                                # Gate sequence number - this allows us to display the gates in the order they were defined to simplify the understanding of drawn layouts

my sub nextGateNumber($)                                                        # Numbers for gates
 {my ($chip) = @_;                                                              # Chip
  ++$gateSeq                                                                    # Sequence number of gate
 }

my sub newGate($$$$$%)                                                          # Make a L<lg>.
 {my ($chip, $type, $name, $output, $inputs, %options) = @_;                    # Chip, gate type, name, output name or array, input names to output from another gate
  @_ >= 4 or confess "Four or more parameters";

  my $n = nextGateNumber $chip;                                                 # Sequence number of gate
  my $outs = ref($output) ? $output : [$output];                                # Array of output pins

  my $g = genHash(__PACKAGE__."::Gate",                                         # Gate
   type     => $type,                                                           # Gate type
   name     => $name // $n,                                                     # Name assigned to gate - or a number if no name was specified
   output   => $outs,                                                           # Output pins as an array of pin names.  The first pin name is used as the name of the gate unless an overriding name=>option has been supplied. Output gate names are unique across the chip.  When a sub chip is installed we rename the copied gates to maintain this invariant.
   inputs   => $inputs,                                                         # Input names to driving outputs. Input names are unique only to the gate they are on.
   io       => gateNotIO,                                                       # Whether an input/output gate or not
   seq      => $n,                                                              # Sequence number for this gate
  );
 }

my sub validateName($$%)                                                        # Confirm that a component name looks like a variable name and has not already been used
 {my ($chip, $output, %options) = @_;                                           # Chip, name, options

  my $gates = $chip->gates;                                                     # Gates implementing the chip

  $output =~ m(\A[a-z][a-z0-9_.:]*\Z|\A\d+\Z)i or confess <<"END";              # User gates should start with a letter, system assigned ones with a number
Invalid gate name: '$output'
END

  $$gates{$output} and confess <<"END";
Gate: '$output' has already been specified
END
  1
 }

sub gate($$$;$$%)                                                               # A L<lg> chosen from B<possibleTypes>.  The gate type can be used as a method name, so B<-E<gt>gate("and",> can be reduced to B<-E<gt>and(>.
 {my ($chip, $type, $output, $input1, $input2, %options) = @_;                  # Chip, gate type, output name, input from another gate, input from another gate, options
  @_ >= 3 or confess "Three or more parameters";
  my $gates = $chip->gates;                                                     # Gates implementing the chip

  my $inputs;                                                                   # Input hash mapping used to accept outputs from other gates as inputs for this gate

  my $name = $options{name} // ref($output) ? $$output[0] :  $output;           # The name of the gate is either the specified option or the name of the first output pin.
  my $outs = ref($output) ? $output                       : [$output];          # Array of output pins
  validateName $chip, $name;                                                    # Validate the name of the gate.

  if ($type =~ m(\A(input)\Z)i)                                                 # Input gates input to themselves unless they have been connected to an output gate during sub chip expansion
   {@_> 3 and confess <<"END";
No input hash allowed for input gate: '$name'
END
    $inputs = {$name=>$name};                                                   # Convert convenient scalar name to hash for consistency with gates in general
   }
  elsif ($type =~ m(\A(one|zero)\Z)i)                                           # Input gates input to themselves unless they have been connected to an output gate during sub chip expansion
   {@_> 3 and confess <<"END";
No input hash allowed for '$type' gate: '$name'
END
    $inputs = {};                                                               # Convert convenient scalar name to hash for consistency with gates in general
   }
  elsif ($type =~ m(\A(output)\Z)i)                                             # Output has one optional scalar value naming its input if known at this point
   {if (defined($input1))
     {ref($input1) and confess <<"END";
Scalar input name required for input on output gate: '$name'
END
      $inputs = {$name=>$input1};                                               # Convert convenient scalar name to hash for consistency with gates in general
     }
   }
  elsif ($type =~ m(\A(continue|not)\Z)i)                                       # These gates have one input expressed as a name rather than a hash
   {!defined($input1) and confess "Input name required for gate: '$name'\n";
    $type =~ m(\Anot\Z)i and ref($input1) =~ m(hash)i and confess <<"END";
Scalar input name required for: '$name'
END
    $inputs = {$name=>$input1};                                                 # Convert convenient scalar name to hash for consistency with gates in general
   }
  elsif ($type =~ m(\A(nxor|xor|gt|ngt|lt|nlt)\Z)i)                             # These gates must have exactly two inputs expressed as a hash mapping input pin name to connection to a named gate.  These operations are associative.
   {!defined($input1) and confess <<"END" =~ s/\n/ /gsr;
Input one required for gate: '$name'
END
    !defined($input2) and confess <<"END" =~ s/\n/ /gsr;
Input two required for gate: '$name'
END
    ref($input1) and confess <<"END" =~ s/\n/ /gsr;
Input one must be the name of the connecting gate.
END
    ref($input2) and confess <<"END" =~ s/\n/ /gsr;
Input two must be the name of the connecting gate.
END
    $inputs = {1=>$input1, 2=>$input2};                                         # Construct the inputs hash expected in general for these two input gates
   }
  elsif ($type =~ m(\A(and|nand|nor|or)\Z)i)                                    # These gates must have two or more inputs expressed as a hash mapping input pin name to connection to a named gate.  These operations are associative.
   {!defined($input1) and confess <<"END" =~ s/\n/ /gsr;
Input hash or array required for gate: '$name'
END
    if (ref($input1) =~ m(hash)i)
     {$inputs = $input1;
     }
    elsif (ref($input1) =~ m(array)i)
     {$inputs = {map {$_=>$$input1[$_]} keys @$input1};
     }
    else
     {confess <<"END" =~ s/\n/ /gsr;
Inputs must be either a hash of input gate
names to output gate names or an array of input gate name for gate: '$name'
END
     }
    keys(%$inputs) == 0 and confess <<"END";                                    # Check we have at least one input
Must have at least one input for gate $name
END
    if (keys(%$inputs) == 1)                                                    # Simplify degenerate gates
     {$type = $type =~ m(\A(and|or)\Z) ? "continue": "not";
     }
    elsif ($chip->expand and keys(%$inputs) > 2)                                # Expand large gates into two input gates
     {my @i = map {$$inputs{$_}} sort keys %$inputs;                            # Input pin names
      my $n = int(@i / 2);
      my ($a, $b) = map {nextGateNumber $chip} 1..2;                            # Divide gate into two subgates
      my $t = $type =~ s/\An//r;                                                # Base gate type, eg nand->and
      my $s = $options{type} // $type;                                          # Only perform the not at the final gate in the tree of 2 input gates representing the one multi input gate
      __SUB__->($chip, $t, $a,      [@i[0 .. $n-1]], undef, %options, type=>$t);# Left sub tree of gates
      __SUB__->($chip, $t, $b,      [@i[$n..$#i]],   undef, %options, type=>$t);# Right sub tree of gates
      __SUB__->($chip, $s, $output, [$a, $b],        undef, %options, type=>$t);# Join left and right sub trees of gates, possibly to make the root of the tree of gates.
      $inputs = {1=>$a, 2=>$b};                                                 # Inputs combining left and right sub trees
     }
   }
  elsif ($type =~ m(\Afanout\Z)i)                                               # One input pin to one or more output pins so that wires never share start cells.  They never share a finish cell because only one connection is permitted to each input pin.
   {!defined($input1) and confess <<"END" =~ s/\n/ /gsr;
Input required for gate: '$name'
END
    if (ref($output) !~ m(array)i)
     {confess <<"END" =~ s/\n/ /gsr;
FanOut must have an array of output pins
END
     }

    $inputs = {1=>$input1};                                                     # Construct the inputs hash expected in general for these two input gates
   }
  else                                                                          # Unknown gate type
   {confess <<"END" =~ s/\n/ /gsr;
Unknown gate type: '$type' for gate: '$name',
possible types are: '$possibleTypes
END
   }

  $chip->gates->{$name} = newGate($chip, $type, $name, $outs, $inputs);         # Construct gate, save it and return it
 }

our $AUTOLOAD;                                                                  # The method to be autoloaded appears here. This allows us to have gate names like 'or' and 'and' without overwriting the existing Perl operators with these names.

sub AUTOLOAD($@)                                                                #P Autoload by L<lg> name to provide a more readable way to specify the L<lgs> on a L<chip>.
 {my ($chip, @options) = @_;                                                    # Chip, options
  my $type = $AUTOLOAD =~ s(\A.*::) ()r;
  if ($type !~ m(\A($possibleTypes|DESTROY)\Z))                                 # Select autoload requests we can process as gate names
   {confess <<"END" =~ s/\n/ /gsr;
Unknown method: '$type'
END
   }
  &gate($chip, $type, @options) if $type =~ m(\A($possibleTypes)\Z);
 }

my sub cloneGate($$)                                                            # Clone a L<lg> on a L<chip>.
 {my ($chip, $gate) = @_;                                                       # Chip, gate
  my %i = $gate->inputs ? $gate->inputs->%* : ();                               # Copy inputs
  newGate($chip, $gate->type, $gate->name, [$gate->output->@*], {%i})
 }

my sub getGate($$)                                                              # Details of a named gate or confess if no such gate
 {my ($chip, $name) = @_;                                                       # Chip, gate name
  my $g = $chip->gates->{$name};                                                # Gate details
  $g or confess "No such gate as $name\n";
  $g
 }

my sub renameGateInputs($$$)                                                    # Rename the inputs of a L<lg> on a L<chip>.
 {my ($chip, $gate, $name) = @_;                                                # Chip, gate, prefix name
  for my $p(qw(inputs))
   {my %i;
    my $i = $gate->inputs;
    for my $n(sort keys %$i)
     {$i{$n} = sprintf "(%s %s)", $name, $$i{$n};
     }
    $gate->inputs = \%i;
   }
  $gate
 }

my sub renameGateOutputs($$$)                                                    # Rename the inputs of a L<lg> on a L<chip>.
 {my ($chip, $gate, $name) = @_;                                                # Chip, gate, prefix name
  for my $o($gate->output->@*)
   {$o = sprintf "(%s %s)", $name, $o;
   }
  $gate
 }

my sub renameGate($$$)                                                          # Rename a L<lg> on a L<chip> by adding a prefix.
 {my ($chip, $gate, $name) = @_;                                                # Chip, gate, prefix name
  $gate->name = sprintf "(%s %s)", $name, $gate->name;
  $gate
 }

#D2 Buses                                                                       # A bus is an array of bits or an array of arrays of bits

#D3 Bits                                                                        # An array of bits that can be manipulated via one name.

my sub sizeBits($$%)                                                            # Size of a bits bus.
 {my ($chip, $name, %options) = @_;                                             # Chip, bits bus name, options
  return $options{bits} if defined($options{bits});
  my $s = $chip->sizeBits->{$name};
  defined($s) or confess "No bit bus named ".dump($name)."\n";
  $s
 }

sub setSizeBits($$$%)                                                           # Set the size of a bits bus.
 {my ($chip, $name, $bits, %options) = @_;                                      # Chip, bits bus name, options
  @_ >= 3 or confess "Three or more parameters";
  defined($chip->sizeBits->{$name}) and confess <<"END";
A bit bus with name: $name has already been defined
END
  $chip->sizeBits->{$name} = $bits;
  $chip
 }

sub bits($$$$%)                                                                 # Create a bus set to a specified number.
 {my ($chip, $name, $bits, $value, %options) = @_;                              # Chip, name of bus, width in bits of bus, value of bus, options
  @_ >= 4 or confess "Four or more parameters";
  my @b = reverse split //, sprintf "%0${bits}b", $value;                       # Bits needed
  for my $b(1..@b)                                                              # Generate constant
   {my $v = $b[$b-1];                                                           # Bit value
    $chip->one (n($name, $b)) if     $v;                                        # Set 1
    $chip->zero(n($name, $b)) unless $v;                                        # Set 0
   }
  setSizeBits($chip, $name, $bits);                                             # Record bus width
 }

sub inputBits($$$%)                                                             # Create an B<input> bus made of bits.
 {my ($chip, $name, $bits, %options) = @_;                                      # Chip, name of bus, width in bits of bus, options
  @_ >= 3 or confess "Three or more parameters";
  setSizeBits($chip, $name, $bits);                                             # Record bus width
  map {$chip->input(n($name, $_))} 1..$bits;                                    # Bus of input gates
 }

sub outputBits($$$%)                                                            # Create an B<output> bus made of bits.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my $bits = sizeBits($chip, $input, %options);
  map {$chip->output(n($name, $_), n($input, $_))} 1..$bits;                    # Bus of output gates
  setSizeBits($chip, $name, $bits);                                             # Record bus width
 }

sub notBits($$$%)                                                               # Create a B<not> bus made of bits.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my $bits = sizeBits($chip, $input, %options);
  map {$chip->not(n($name, $_), n($input, $_))} 1..$bits;                       # Bus of not gates
  setSizeBits($chip, $name, $bits);                                             # Record bus width
 }

sub andBits($$$%)                                                               # B<and> a bus made of bits.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my $bits = sizeBits($chip, $input, %options);
  $chip->and($name, {map {($_=>n($input, $_))} 1..$bits});                      # Combine inputs in one B<and> gate
  setSizeBits($chip, $name, $bits);                                             # Record bus width
 }

sub nandBits($$$%)                                                              # B<nand> a bus made of bits.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my $bits = sizeBits($chip, $input, %options);
  $chip->nand($name, {map {($_=>n($input, $_))} 1..$bits});                     # Combine inputs in one B<nand> gate
  setSizeBits($chip, $name, $bits);                                             # Record bus width
 }

sub orBits($$$%)                                                                # B<or> a bus made of bits.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, options
  @_ >= 3 or confess "Three or more parameters";
  my $bits = sizeBits($chip, $input, %options);
  $chip->or($name,  {map {($_=>n($input, $_))} 1..$bits});                      # Combine inputs in one B<or> gate
  setSizeBits($chip, $name, $bits);                                             # Record bus width
 }

sub norBits($$$%)                                                               # B<nor> a bus made of bits.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, options
  @_ >= 3 or confess "Three or more parameters";
  my $bits = sizeBits($chip, $input, %options);
  $chip->nor($name,  {map {($_=>n($input, $_))} 1..$bits});                     # Combine inputs in one B<nor> gate
  setSizeBits($chip, $name, $bits);                                             # Record bus width
 }

#D3 Words                                                                       # An array of arrays of bits that can be manipulated via one name.

my sub sizeWords($$%)                                                           # Size of a words bus.
 {my ($chip, $name, %options) = @_;                                             # Chip, word bus name, options
  my $s = $chip->sizeWords->{$name};
  my $w = $options{bits}  // $$s[0];
  my $b = $options{words} // $$s[1];
  defined($w) or confess "No words width specified or defaulted for $name";
  defined($b) or confess "No bits width specified or defaulted for $name";
  ($w, $b)
 }

sub setSizeWords($$$$%)                                                         # Set the size of a bits bus.
 {my ($chip, $name, $words, $bits, %options) = @_;                              # Chip, bits bus name, words, bits per word, options
  @_ >= 4 or confess "Four or more parameters";
  defined($chip->sizeWords->{$name}) and confess <<"END";
A word bus with name: $name has already been defined
END
  $chip->sizeWords->{$name} = [$words, $bits];                                  # Word bus size
  setSizeBits($chip, n($name, $_), $bits) for 1..$words;                        # Size of bit bus for each word in the word bus
  $chip
 }

sub words($$$@)                                                                 # Create a word bus set to specified numbers.
 {my ($chip, $name, $bits, @values) = @_;                                       # Chip, name of bus,  width in bits of each word, values of words
  @_ >= 3 or confess "Three or more parameters";
  for my $w(1..@values)                                                         # Each value to put on the bus
   {my $value = $values[$w-1];                                                  # Each value to put on the bus
    my @b = reverse split //, sprintf "%0${bits}b", $value;                     # Bits needed
    for my $b(1..@b)                                                            # Generate constant
     {my $v = $b[$b-1];                                                         # Bit value
      $chip->one (nn($name, $w, $b)) if     $v;                                 # Set 1
      $chip->zero(nn($name, $w, $b)) unless $v;                                 # Set 0
     }
   }
  setSizeWords($chip, $name, scalar(@values), $bits);                           # Record bus width
 }

sub inputWords($$$$%)                                                           # Create an B<input> bus made of words.
 {my ($chip, $name, $words, $bits, %options) = @_;                              # Chip, name of bus, width in words of bus, width in bits of each word on bus, options
  @_ >= 4 or confess "Four or more parameters";
  for my $w(1..$words)                                                          # Each word on the bus
   {map {$chip->input(nn($name, $w, $_))} 1..$bits;                             # Bus of input gates
   }
  setSizeWords($chip, $name, $words, $bits);                                    # Record bus size
 }

sub outputWords($$$%)                                                           # Create an B<output> bus made of words.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my ($words, $bits) = sizeWords($chip, $input);
  for my $w(1..$words)                                                          # Each word on the bus
   {map {$chip->output(nn($name, $w, $_), nn($input, $w, $_))} 1..$bits;        # Bus of output gates
   }
  setSizeWords($chip, $name, $words, $bits);                                    # Record bus size
 }

sub notWords($$$%)                                                              # Create a B<not> bus made of words.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my ($words, $bits) = sizeWords($chip, $input, %options);
  for my $w(1..$words)                                                          # Each word on the bus
   {map {$chip->not(nn($name, $w, $_), nn($input, $w, $_))} 1..$bits;           # Bus of not gates
   }
  setSizeWords($chip, $name, $words, $bits);                                    # Record bus size
 }

sub andWords($$$%)                                                              # B<and> a bus made of words to produce a single word.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my ($words, $bits) = sizeWords($chip, $input, %options);
  for my $w(1..$words)                                                          # Each word on the bus
   {$chip->andBits(n($name, $w), n($input, $w));                                # Combine inputs using B<and> gates
   }
  setSizeBits($chip, $name, $words);                                            # Record bus size
 }

sub andWordsX($$$%)                                                             # B<and> a bus made of words by and-ing the corresponding bits in each word to make a single word.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my ($words, $bits) = sizeWords($chip, $input, %options);
  for my $b(1..$bits)                                                           # Each word on the bus
   {$chip->and(n($name, $b), {map {($_=>nn($input, $_, $b))} 1..$words});       # Combine inputs using B<and> gates
   }
  setSizeBits($chip, $name, $bits);                                             # Record bus size
 }

sub orWords($$$%)                                                               # B<or> a bus made of words to produce a single word.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my ($words, $bits) = sizeWords($chip, $input, %options);
  for my $w(1..$words)                                                          # Each word on the bus
   {$chip->orBits(n($name, $w), n($input, $w));                                 # Combine inputs using B<or> gates
   }
  setSizeBits($chip, $name, $words);                                            # Record bus size
 }

sub orWordsX($$$%)                                                              # B<or> a bus made of words by or-ing the corresponding bits in each word to make a single word.
 {my ($chip, $name, $input, %options) = @_;                                     # Chip, name of bus, name of inputs, options
  @_ >= 3 or confess "Three or more parameters";
  my ($words, $bits) = sizeWords($chip, $input, %options);
  for my $b(1..$bits)                                                           # Each word on the bus
   {$chip->or(n($name, $b), {map {($_=>nn($input, $_, $b))} 1..$words});        # Combine inputs using B<or> gates
   }
  setSizeBits($chip, $name, $bits);                                             # Record bus size
 }

#D2 Connect                                                                     # Connect input buses to other buses.

sub connectInput($$$%)                                                          # Connect a previously defined input gate to the output of another gate on the same chip. This allows us to define a set of gates on the chip without having to know, first, all the names of the gates that will provide input to these gates.
 {my ($chip, $in, $to, %options) = @_;                                          # Chip, input gate, gate to connect input gate to, options
  @_ >= 3 or confess "Three or more parameters";
  my $gates = $chip->gates;
  my $i = $$gates{$in};
  defined($i) or confess "No definition of input gate $in";
  $i->type =~ m(\Ainput\Z) or confess "No definition of input gate $in";
  $i->inputs = {1=>$to};
  $chip
 }

sub connectInputBits($$$%)                                                      # Connect a previously defined input bit bus to another bit bus provided the two buses have the same size.
 {my ($chip, $in, $to, %options) = @_;                                          # Chip, input gate, gate to connect input gate to, options
  @_ >= 3 or confess "Three or more parameters";
  my $I = sizeBits($chip, $in);
  my $T = sizeBits($chip, $to);
  $I == $T or confess <<"END" =~ s/\n(.)/ $1/gsr;
Mismatched bits bus width: input has $I bits but output has $T bits.
END
  connectInput($chip, n($in, $_), n($to, $_)) for 1..$I;
  $chip
 }

sub connectInputWords($$$%)                                                     # Connect a previously defined input word bus to another word bus provided the two buses have the same size.
 {my ($chip, $in, $to, %options) = @_;                                          # Chip, input gate, gate to connect input gate to, options
  @_ >= 3 or confess "Three or more parameters";
  my ($iw, $ib) = sizeWords($chip, $in);
  my ($tw, $tb) = sizeWords($chip, $to);
  $iw == $tw or confess <<"END" =~ s/\n(.)/ $1/gsr;
Mismatched words bus: input has $iw words but output has $tw words
END
  $ib == $tb or confess <<"END" =~ s/\n(.)/ $1/gsr;
Mismatched bits width of words bus: input has $ib bits but output has $tb bits
END
  connectInputBits($chip, n($in, $_), n($to, $_)) for 1..$iw;
  $chip
 }

#D2 Install                                                                     # Install a chip within a chip as a sub chip.

sub install($$$$%)                                                              # Install a L<chip> within another L<chip> specifying the connections between the inner and outer L<chip>.  The same L<chip> can be installed multiple times as each L<chip> description is read only.
 {my ($chip, $subChip, $inputs, $outputs, %options) = @_;                       # Outer chip, inner chip, inputs of inner chip to to outputs of outer chip, outputs of inner chip to inputs of outer chip, options
  @_ >= 4 or confess "Four or more parameters";
  my $c = genHash(__PACKAGE__."::Install",                                      # Installation of a chip within a chip
    chip    => $subChip,                                                        # Chip being installed
    inputs  => $inputs,                                                         # Outputs of outer chip to inputs of inner chip
    outputs => $outputs,                                                        # Outputs of inner chip to inputs of outer chip
   );
  push $chip->installs->@*, $c;                                                 # Install chip
  $c
 }

my sub getGates($%)                                                             # Get the L<lgs> of a L<chip> and all it installed sub chips.
 {my ($chip, %options) = @_;                                                    # Chip, options

  my %outerGates;
  for my $g(sort {$a->seq <=> $b->seq} values $chip->gates->%*)                 # Copy gates from outer chip
   {my $G = $outerGates{$g->name} = cloneGate($chip, $g);
    if    ($G->type =~ m(\Ainput\Z)i)  {$G->io = gateExternalInput}             # Input gate on outer chip
    elsif ($G->type =~ m(\Aoutput\Z)i) {$G->io = gateExternalOutput}            # Output gate on outer chip
   }

  my @installs = $chip->installs->@*;                                           # Each sub chip used in this chip

  for my $install(keys @installs)                                               # Each sub chip
   {my $s = $installs[$install];                                                # Sub chip installed in this chip
    my $n = $s->chip->name;                                                     # Name of sub chip
    my $innerGates = __SUB__->($s->chip);                                       # Gates in sub chip

    for my $G(sort {$$innerGates{$a}->seq <=> $$innerGates{$b}->seq}
              keys  %$innerGates)                                               # Each gate in sub chip on definition order
     {my $g = $$innerGates{$G};                                                 # Gate in sub chip
      my $o = $g->name;                                                         # Name of gate
      my $copy = cloneGate $chip, $g;                                           # Clone gate from chip description
      my $newGateName = sprintf "$n %d", $install+1;                            # Rename gates to prevent name collisions from the expansions of the definitions of the inner chips

      if ($copy->type =~ m(\Ainput\Z)i)                                         # Input gate on inner chip - connect to corresponding output gate on containing chip
       {my $in = $copy->name;                                                   # Name of input gate on inner chip
        my $o  = $s->inputs->{$in};
           $o or confess <<"END";
No connection specified to inner input gate: '$in' on sub chip: '$n'
END
        my $O  = $outerGates{$o};
           $O or confess <<"END" =~ s(\n) ( )gsr;
No outer output gate '$o' to connect to inner input gate: '$in'
on sub chip: '$n'
END
        my $ot = $O->type;
        my $on = $O->name;
           $ot =~ m(\Aoutput\Z)i or confess <<"END" =~ s(\n) ( )gsr;
Output gate required for connection to: '$in' on sub chip $n,
not: '$ot' gate: '$on'
END
        $copy->inputs = {1 => $o};                                              # Connect inner input gate to outer output gate
        renameGate $chip, $copy, $newGateName;                                  # Add chip name to gate to disambiguate it from any other gates
        $copy->io = gateInternalInput;                                          # Mark this as an internal input gate
       }

      elsif ($copy->type =~ m(\Aoutput\Z)i)                                     # Output gate on inner chip - connect to corresponding input gate on containing chip
       {my $on = $copy->name;                                                 # Name of output gate on outer chip
        my $i  = $s->outputs->{$on};
           $i or confess <<"END";
No connection specified to inner output gate: '$on' on sub chip: '$n'
END
        my $I  = $outerGates{$i};
           $I or confess <<"END";
No outer input gate: '$i' to connect to inner output gate: $on on sub chip: '$n'
END
        my $it = $I->type;
        my $in = $I->name;
           $it =~ m(\Ainput\Z)i or confess <<"END" =~ s(\n) ( )gsr;
Input gate required for connection to '$in' on sub chip '$n',
not gate '$in' of type '$it'
END
        renameGateInputs $chip, $copy, $newGateName;
        renameGate       $chip, $copy, $newGateName;
        $I->inputs = {11 => $copy->name};                                       # Connect inner output gate to outer input gate
        $copy->io  = gateInternalOutput;                                        # Mark this as an internal output gate
       }
      else                                                                      # Rename all other gate inputs
       {renameGateInputs  $chip, $copy, $newGateName;
        renameGateOutputs $chip, $copy, $newGateName;
        renameGate        $chip, $copy, $newGateName;
       }

      $outerGates{$copy->name} = $copy;                                         # Install gate with new name now it has been connected up
     }
   }
  \%outerGates                                                                  # Return all the gates in the chip extended by its sub chips
 }

my sub outPins($%)                                                              # Map output pins to gates
 {my ($chip, %options) = @_;                                                    # Chip, options
  my $gates = $chip->gates;                                                     # Gates on chip

  my %pins;
  for my $G(sort keys %$gates)                                                  # Find all outputs
   {my $g = $$gates{$G};                                                        # Address gate
    my @o = $g->output->@*;                                                     # Output pins
    for my $i(keys @o)                                                          # Index output pins
     {$pins{$o[$i]} = [$g, $i];                                                 # Gate and number of output pin on gate
     }
   }
 %pins                                                                          # Pin names to gate descriptions
}

my sub inPins($%)                                                               # Map output pins to input pins. After fanout there is only ever one wire from/to each pin making the structure built by this routine redundantly deep - the second layer will always have just one key.
 {my ($chip, %options) = @_;                                                    # Chip, options
  my $gates = $chip->gates;                                                     # Gates on chip

  my %pins;
  for my $G(sort keys %$gates)                                                  # Find all outputs
   {my $g = $$gates{$G};                                                        # Address gate
    next if $g->type =~ m(\Ainput\Z);                                           # Input gates are not considered as targets
    my %o = $g->inputs->%*;                                                     # Output pins
    for my $i(keys %o)                                                          # Index output pins
     {my $o = $o{$i};                                                           # Output pin driving this input
      my $j = $g->name.q(@).$o;                                                 # Make the input pin name unique by prefixing the gate name.
      $pins{$o}{$j} = [$g, $i];                                                 # The input pins driven by the output pins of each gate.
     }
   }
 %pins                                                                          # Pin names to gate descriptions
}

my sub inPinsAfterFan($%)                                                       # Map output pins to input pins after fanout guarantees a bijection between the two.
 {my ($chip, %options) = @_;                                                    # Chip, options
  my $gates = $chip->gates;                                                     # Gates on chip

  my %pins;
  for my $G(sort keys %$gates)                                                  # Find all outputs
   {my $g = $$gates{$G};                                                        # Address gate
    next if $g->type =~ m(\Ainput\Z);                                           # Input gates are not considered as targets
    my %o = $g->inputs->%*;                                                     # Output pins
    for my $i(keys %o)                                                          # Index output pins
     {my $o = $o{$i};                                                           # Output pin driving this input
      my $j = $g->name.q(@).$o;                                                 # Make the input pin name unique by prefixing the gate name.
      $pins{$o} and confess "Not bijective";
      $pins{$o} = [$g, $i];                                                     # The input pins driven by the output pins of each gate.
     }
   }
 %pins                                                                          # Pin names to gate descriptions
}

my sub checkIO($%)                                                              # Check that each input L<lg> is connected to one output  L<lg>.
 {my ($chip, %options) = @_;                                                    # Chip, options
  my $gates = $chip->gates;                                                     # Gates on chip

  my %outPins = outPins($chip, %options);                                       # Map output pins to gates

  my %o;
  for my $G(sort keys %$gates)                                                  # Find all inputs and outputs
   {my $g = $$gates{$G};                                                        # Address gate
    my $t = $g->type;                                                           # Type of gate
    my %i = $g->inputs->%*;                                                     # Inputs for gate
    for my $i(sort keys %i)                                                     # Each input
     {my $o = $i{$i};                                                           # Output driving input
      defined($o) or  confess <<"END";                                          # No driving output
No output driving input pin '$i' on '$t' gate '$G'
END

      my $O = $outPins{$o}[0];                                                  # Gate driving this input
      defined($O) or  confess <<"END";                                          # No driving output
No output driving input '$o' on '$t' gate '$G'
END
      if ($g->io != gateOuterInput)                                             # The gate must inputs driven by the outputs of other gates
       {$o{$o}++;                                                               # Show that this output has been used
        my $T = $O->type;
        if ($g->type =~ m(\Ainput\Z)i)
         {$O->type =~ m(\Aoutput\Z)i or confess <<"END" =~ s(\n) ( )gsr;
Input gate: '$G' must connect to an output gate on pin: '$i'
not to '$T' gate: '$o'
END
         }
        elsif (!$g->io)                                                         # Not an io gate so it cannot have an input from an output gate
         {$O->type =~ m(\Aoutput\Z) and confess <<"END";
Cannot drive a '$t' gate: '$G' using output gate: '$o'
END
         }
       }
     }
   }

  for my $G(sort keys %$gates)                                                  # Check all inputs and outputs are being used
   {my $g = $$gates{$G};                                                        # Address gate
    next if $g->type =~ m(\Aoutput\Z)i;
    $o{$G} or confess <<"END" =~ s/\n/ /gsr;
Output from gate '$G' is never used
END
   }
 }

my sub addFans($%)                                                              # Add any fanOuts needed ensure that each output pin drives just one input pin to make wiring easier in L<Silicon::Chip::Wiring>.
 {my ($chip, %options) = @_;                                                    # Chip, options
  my %inPins = inPins $chip, %options;                                          # Map output pins to gates
  for my $o(sort keys %inPins)                                                  # Find all inputs and outputs
   {my %b = $inPins{$o}->%*;                                                    # Gates driven by this gate
    my $n = keys %b;                                                            # Number of output gates for the fan
    next unless $n > 1;                                                         # Driving more then one input
    my @b = sort keys %b;                                                       # Branches in this fan
    my ($s, $t) = $b{$b[0]}->@*;                                                # Source and target of fan

    my $o = $s->inputs->{$t};                                                   # The output which should be fanned
    my @n = map {nextGateNumber $chip} 1..$n;                                   # Numbers for fan outputs

    if ($chip->expand)                                                          # Expand the fan out gate into smaller gates
     {my @p = @n;
      while(@p > 2)                                                             # Reduce required outputs in pairs
       {my @q;
        while(@p > 2)                                                           # Maximum of two outputs for each fan
         {my $a = pop @p; my $b = pop @p;
          push @q, my $c = nextGateNumber $chip;                                # Fan out
          $chip->gate('fanOut', [$a, $b], $c, undef, %options);                 # New fan out to replace branches from output
         }
        if (@p)                                                                 # Trailing singleton
         {push @q, my $c = nextGateNumber $chip;                                # Fan out
          $chip->gate('fanOut', [@p], $c, undef, %options);                     # New fan out to replace branches from output
         }
        @p = @q;
       }
      $chip->gate('fanOut', [@p], $o, undef, %options);                         # Connect fan to source
     }
    else                                                                        # Use fan out with more than two outputs
     {$chip->gate('fanOut', [@n], $o);                                          # New fan out to replace branches from output
     }

    for my $b(keys @b)                                                          # Each branch of the fan
     {my ($g, $i) = $b{$b[$b]}->@*;                                             # Gate being driven, input pin of gate
      $g->inputs->{$i} = $n[$b];                                                # Set input pin to a branch of the fan
     }
   }
 }

my sub setOuterGates($$%)                                                       # Set outer  L<lgs> on external chip that connect to the outer world.
 {my ($chip, $gates, %options) = @_;                                            # Chip, gates in chip plus all sub chips as supplied by L<getGates>.

  for my $G(sort keys %$gates)                                                  # Find all inputs and outputs
   {my $g = $$gates{$G};                                                        # Address gate
    next unless $g->io == gateExternalInput;                                    # Input on external chip
    my ($i) = values $g->inputs->%*;
    $g->io = gateOuterInput if $g->name eq $i;                                  # Unconnected input gates reflect back on themselves - this is a short hand way of discovering such gates
   }

  gate: for my $G(sort keys %$gates)                                            # Find all inputs and outputs
   {my $g = $$gates{$G};                                                        # Address gate
    next unless $g->io == gateExternalOutput;                                   # Output on external chip
    for my $H(sort keys %$gates)                                                # Gates driven by this gate
     {next if $G eq $H;
      my %i = $$gates{$H}->inputs->%*;                                          # Inputs to this gate
      for my $I(sort keys %i)                                                   # Each input
       {next gate if $i{$I} eq $G;                                              # Found a gate that accepts input from this gate
       }
     }
    $g->io = gateOuterOutput;                                                   # Does not drive any other gate
   }
 }

my sub removeExcessIO($$%)                                                      # Remove unneeded IO L<lgs> .
 {my ($chip, $gates, %options) = @_;                                            # Chip, gates in chip plus all sub chips as supplied by L<getGates>.

  my %d;                                                                        # Names of gates to delete
  for(;;)                                                                       # Multiple passes until no more gates can be replaced
   {my $changes = 0;

    gate: for my $G(sort keys %$gates)                                          # Find all inputs and outputs
     {my $g = $$gates{$G};                                                      # Address gate
      next unless $g->io;                                                       # Skip non IO gates
      next if     $g->io == gateOuterInput or $g->io == gateOuterOutput;        # Cannot be collapsed
      my ($n) = values $g->inputs->%*;                                          # Name of the gate driving this gate

      for my $H(sort keys %$gates)                                              # Gates driven by this gate
       {next if $G eq $H;
        my $h = $$gates{$H};                                                    # Address gate
        my %i = $h->inputs->%*;                                                 # Inputs
        for my $i(sort keys %i)                                                 # Each input
         {if ($i{$i} eq $G)                                                     # Found a gate that accepts input from this gate
           {my $replace = $h->inputs->{$i};
            $h->inputs->{$i} = $n;                                              # Bypass io gate
            $d{$G}++;                                                           # Delete this gate
            ++$changes;                                                         # Count changes in this pass
           }
         }
       }
     }
    last unless $changes;
   }
  for my $d(sort keys %d)                                                       # Gates to delete
   {delete $$gates{$d};
   }
 }

#D1 Visualize                                                                   # Visualize the L<chip> in various ways.

my sub orderGates($%)                                                           # Order the L<lgs> on a L<chip> so that input L<lg> are first, the output L<lgs> are last and the non io L<lgs> are in between. All L<lgs> are first ordered alphabetically. The non io L<lgs> are then ordered by the step number at which they last changed during simulation of the L<chip>.  This has the effect of placing all the buses in the upper right corner as there are no loops.
 {my ($chip, %options) = @_;                                                    # Chip, options

  my $gates = $chip->gates;                                                     # Gates on chip
  my @i; my @n; my @o;

  for my $G(sort {$$gates{$a}->seq <=> $$gates{$b}->seq} keys %$gates)          # Dump each gate one per line in definition order
   {my $g = $$gates{$G};
    push @i, $G if $g->type =~ m(\Ainput\Z)i;
    push @n, $G if $g->type !~ m(\A(in|out)put\Z)i;
    push @o, $G if $g->type =~ m(\Aoutput\Z)i;
   }

  if (my $c = $options{changed})                                                # Order non IO gates by last change time during simulation if possible
   {@n = sort {($$c{$a}//0) <=> ($$c{$b}//0)} @n;
   }

  (\@i, \@n, \@o)
 }

sub print($%)                                                                   # Dump the L<lgs> present on a L<chip>.
 {my ($chip, %options) = @_;                                                    # Chip, gates, options
  my $gates  = $chip->gates;                                                    # Gates on chip
  my $values = $options{values};                                                # Values of each gate if known
  my @s;
  my ($i, $n, $o) = orderGates $chip, %options;                                 # Gates by type
  for my $G(@$i, @$n, @$o)                                                      # Dump each gate one per line
   {my $g = $$gates{$G};
    my %i = $g->inputs ? $g->inputs->%* : ();

    my $p = sub                                                                 # Instruction name and type
     {my $v = $$values{$G};                                                     # Value if known for this gate
      my $o = $g->name;
      my $t = $g->type;
      return sprintf "%-32s: %3d %-32s", $o, $v, $t if defined($v);             # With value
      return sprintf "%-32s:     %-32s", $o,     $t;                            # Without value
     }->();

    if (my @i = map {$i{$_}} sort keys %i)                                      # Add actual inputs in same line sorted in input pin name
     {$p .= join " ", @i;
     }
    push @s, $p;
   }
  my $s = join "\n", @s, '';                                                    # Representation of gates as text
  owf fpe($options{print}, q(txt)), $s if $options{print};                      # Write representation of gates as text to the named file
  $s
 }

sub Silicon::Chip::Simulation::print($%)                                        # Print simulation results as text.
 {my ($sim, %options) = @_;                                                     # Simulation, options
  $sim->chip->print(%options, values=>$sim->values);
 }

my sub paca(&$$%)                                                               # Arrange the second array to minimize the average value of the function between the two arrays
 {my ($metric, $A, $B, %options) = @_;                                          # Metric function between a pair of elements drawn from each array, the first array, the second array, options
  my $N = @$B / @$A;                                                            # Amount of duplication of A required to reach B
  my @C = map {int($_ / $N)} keys @$B;                                          # Spread out A to match B
  my @p = (undef) x @$B;                                                        # Proposed ordering for B
  for  my $j(keys @$B)                                                          # Place each element of B
   {my $b = $$B[$j];                                                            # Element of B
    my $c; my $D;                                                               # Index of best position
    for my $i(keys @C)                                                          # Each indexed position
     {next if defined $p[$i];                                                   # Position already filled
      my $d = &$metric($$A[$C[$i]], $b);                                        # Distance from b to a
      next unless defined $d;                                                   # Infinity if the metric function returns L<undef>
      next if defined($c) and $d > $D;                                          # Worse then the current best
      $c = $i; $D = $d;                                                         # Closest entry in A for this B so far
     }
    $p[$c] = $j;                                                                # Position as closely as possible
   }
  map {$$B[$_]} @p                                                              # Reorder B to make its entries match those of A as closely as possible
 }

my sub distance($$$$)                                                           # Manhattan distance between two points
 {my ($x, $y, $X, $Y) = @_;                                                     # Start x, start y, end x, end y
  abs($X - $x) + abs($Y - $y)
 }

my sub layoutSquare($%)                                                         # Layout the gates approximately a a square relying on multiple layers abovethe gates to carry the connections.
 {my ($chip, %options) = @_;                                                    # Chip, options
  my $gates      = $chip->gates;                                                # Gates on chip
  my $changed    = $options{changed};                                           # Step at which gate last changed in simulation
  my $values     = $options{values};                                            # Values of each gate if known
  my $route      = $options{route}    // '';                                    # Routing methodology
  my $minHeight  = $options{minHeight};                                         # Minimum Y dimension of chip
  my $newChange  = $options{newChange};                                         # Start a new column every time we reach a new change level
  my $dx         = $options{spaceDx}  // 0;                                     # Spacing in x between gates
  my $dy         = $options{spaceDy}  // 0;                                     # Spacing in y between gates
  my $borderDx   = $options{borderDx} // 2;                                     # Make sure there is some space at the edge of the chip so that gates are not squashed up against it and made difficult to route as a consequence
  my $borderDy   = $options{borderDy} // 2;                                     # Make sure there is some space at the edge of the chip so that gates are not squashed up against it and made difficult to route as a consequence
  my $gsx        = $options{gsx}      // 2;                                     # Integer scale factor to apply to x dimension of gates on the chip - by spreading out the pins we make them more accessible.
  my $gsy        = $options{gsy}      // 2;                                     # Integer scale factor to apply to y dimension of gates on the chip - by spreading out the pins we make them more accessible.
  my $GATE_WIDTH = 2 * $gsx;   ### Improve!  We assume this is the width of all gates but this unlikely to be true in general.
  my $DX         = $GATE_WIDTH + $dx;                                           # Width of each column of gates

  my sub position(%)                                                            # Position of a gate
   {my (%options) = @_;                                                         # Options
    genHash(__PACKAGE__."::LayoutSquarePosition",                               # Details of position
      changed    => $options{changed},                                          # Step at which gate first changed
      x          => $options{x},                                                # X position of left upper corner of gate
      y          => $options{y},                                                # Y position of left upper corner of gate
      h          => $options{height},                                           # Height of gate
      w          => $options{width},                                            # Width of gate
      Gate       => $options{Gate},                                             # Definition of gate. Capital G because of a slight default in L<Data::Table::Text::updateDocumentation> that reports a duplicate attribute if we use lowercase g.
      changeStep => 0,                                                          # True if we are stepping from one change level to the next
      bottomUp   => 0,                                                          # Normally the gates are laid out top down but sometimes it is better to lay them out bottom up
     );
   }

  my @positions;                                                                # Gate positions
  for my $G(sort keys %$gates)                                                  # Gates
   {my $g = $$gates{$G};                                                        # Gate
    my $c = $$changed{$G} // -1;                                                # Change time. Set change time of input gates to -1 to show they were changed before the simulation started.
    my $h = max(scalar(keys $g->inputs->%*), scalar(keys $g->output->@*)) || 1; # Every gate occupies at least one cell vertically
    push @positions, my $p = position(Gate=>$g, changed=>$c,                    # Gates are assumed to be two wide so that the inputs do overlay the outputs
      width=>$GATE_WIDTH, height=>$h*$gsy);
   }

  @positions = sort {$a->changed <=> $b->changed} @positions;                   # Sort so that gates are in temporal order

  my $dimension  = 0;                                                           # Count of all the pins to get an idea of how big the chip will be
     $dimension += $_->h + $dx + $dy for @positions;                            # Each pin
  my $dimensionY = sqrt($dimension);                                            # Approximate Y dimension of the chip assuming we can extend as needed in X which is more conveniebt to work with because monitors tend to have more pixels in X than in Y.
     $dimensionY = int($dimensionY+1);                                          # Round to a convenient integer greater than zero
     $dimensionY = $minHeight // $dimensionY + 2 * $borderDy;                   # Use supplied width if available

  my ($width, $height) = sub                                                    # Position each gate and return the dimensions of the chip in cells
   {my $ni;                                                                     # First non input gate
    for my $p(@positions)                                                       # Place each gate
     {$ni = $p unless defined($ni) or $p->Gate->type =~ m(\Ainput\Z);           # First non input gate
     }

    for my $i(1..$#positions)                                                   # First gate at each new change level
     {my $p = $positions[$i];
      $p->changeStep = $p->changed != $positions[$i-1]->changed;
     }

    my $X = $borderDx; my $Y = $borderDy; my $mY = $Y;                          # Current x,y position, maximum Y. I tried starting a new column every time the "changed" field changes thinking this would induce fewer wiring levels, it did for simple chips but made things slightly worse for Btree.

    for my $p(@positions)                                                       # Place each gate
     {my $g = $p->Gate;
      if ($Y + $p->h > $dimensionY or $ni && $ni == $p or                       # Next column if last column would be overly full.  Gates are assumed to require two columns so we can separate their inputs and outputs.  This is not required for input and output pins so some further improvements might be possible here.
        $newChange && $p->changeStep)                                           # Start a new column every time we reach a new change level
       {$X += $DX; $Y = $borderDy;
       }
      $p->x = $X; $p->y = $Y;                                                   # Position gate
      $Y += $p->h + $dy;                                                        # Position of next chip
      $mY = max $Y, $mY                                                         # Maximum Y position
     }
   ($X + $GATE_WIDTH + $borderDx, $mY)                                          # Chip dimensions
   }->();

#  for my $x(map {$DX * $_} 1..int($width/$DX))                                  # Reorder each column of gates to make each gate as close as possible to the preceding gate from which it derives its inputs
#   {my @a; my @b;                                                               # Preceding column and current column
#    for my $p(@positions)                                                       # Each position
#     {push @a, $p if $p->x == $x - $DX;                                         # Gate is in preceding column
#      push @b, $p if $p->x == $x;                                               # Gate is current column
#     }
#    next unless @a and @b;
#
#    my @c = paca                                                                # Reorder the current column to reduce the wiring needed to reach the next set of gates
#     {my ($p, $q) = @_;
#      my %i = map {$_=>1} values $q->Gate->inputs->%*;                          # Gates driving this gate
#      exists($i{$p->Gate->name}) ? 1 : 0;                                       # Gate is being driven by a gate in the preceding column
#     } \@a, \@b;
#
#    my $Y = 0;
#    for my $p(@c)                                                               # Reposition gates in column to locate them as closely as possible to their driving gates
#     {$p->y = $Y;                                                               # Gate in column
#      $Y += $p->h + $dy;                                                        # Reposition gate
#     }
#   }

  my $l = sub                                                                   # Position each gate on the chip
   {my $l = Silicon::Chip::Layout::new(width=>$width, height=>$height);         # Create chip

    for my $p(@positions)                                                       # Place each gate
     {$l->gate(%$p, w=>$p->w, h=>$p->h, t=>$p->Gate->type, l=>$p->Gate->name);
     }

    $l->svg(%options, file=>$options{svg}) if $options{svg};                    # Draw an svg representation of the gates

    $l
   }->();

  my %outPins = outPins $chip, %options;                                        # Map the output pins to gates

  my @wires = sub                                                               # The wires we need to route
   {my @W;                                                                      # Wire positions and lengths
    my %positions = map {$positions[$_]->Gate->name => $_} keys @positions;     # Index of positioned gates

    for my $p(@positions)                                                       # Place each gate
     {next if $p->Gate->type eq "input";                                        # Draw from inputs to outputs
      my %i = $p->Gate->inputs->%*;                                             # Inputs
      my @i = sort keys %i;                                                     # Inputs

      my @w1; my @w2;                                                           # Two ways of wiring things up
      for my $I(keys @i)                                                        # Each input
       {my $dp = $i{$i[$I]};                                                    # Name of pin driving this input
        my ($dg, $do) = $outPins{$dp}->@*;                                      # Gate and number of driving pin
        my $i  = $positions[$positions{$dg->name}];                             # Position of driving gate
        my $x  = $i->x + $i->w - 1;                                             # Position of output pin
        my $y  = $i->y + $do*$gsy;                                              # Position of driving pin
        my $X  = $p->x;                                                         # Input pin X position
        my $Y1 = $p->y+$p->h-$I*$gsy - 1;                                       # Connect this gates inputs bottom up
        my $Y2 = $p->y+      $I*$gsy;                                           # Connect this gates inputs top  down
        push @w1, [$x, $y, $X, $Y1, abs($X-$x)+abs($Y1-$y)];                    # Wire details bottom up because all our gates are commutative
        push @w2, [$x, $y, $X, $Y2, abs($X-$x)+abs($Y2-$y)];                    # Wire details top down  because all our gates are commutative
       }
      my $l1 = 0; $l1 += $$_[4] for @w1;                                        # Length of wires bottom up
      my $l2 = 0; $l2 += $$_[4] for @w2;                                        # Length of wires top down
      my $bu = $p->bottomUp = $l1 < $l2;                                        # Bottom up is shorter
      push @W, $bu ? @w1 : @w2;
     }
    sort {$$b[4] <=> $$a[4]} @W                                                 # Wires ordered longest to shortest on the basis that short wires are more routable. Run time for short to long routing takes 4 times longer long to short using the tests in this file.
#   sort {$$a[4] <=> $$b[4]} @W                                                 # Wires ordered shortest to longest
   }->();

  my $w = Silicon::Chip::Wiring::new(width=>$width, height=>$height, %options); # Wiring

  for my $p(@wires)                                                             # Place each gate
   {my ($x, $y, $X, $Y) = @$p;                                                  # Draw from inputs to outputs
    $w->wire($x, $y, $X, $Y, %options);                                         # Create the wire
   }
  $w->layout(%options);

  $w->svg(%options, file=>$options{svg})  if $options{svg};                     # Draw an svg representation of the wiring between the gates
  $chip->gds2($l, $w, svg=>$options{svg}) if $options{svg};                     # Draw as GDS2 for transmission to fab.

  genHash(__PACKAGE__."::LayoutSquare",                                         # Details of layout and wiring
    chip           => $chip,                                                    # Chip being masked
    positions      => \@positions,                                              # Positions array
    layout         => $l,                                                       # Layout
    wiring         => $w,                                                       # Wiring
    changed        => $changed,                                                 # Changed at step in simulation
    values         => $values,                                                  # Final values
    height         => $height,                                                  # Height of layout
    width          => $width,                                                   # Width of layout
   );
 }

my sub layoutLinear($%)                                                         # Layout the gates as a fiber bundle collapsed down to as close to the gates as possible.  The returned information is sufficient to draw an svg image of the fiber bundle.
 {my ($chip, %options) = @_;                                                    # Chip, options
  my %gates   = $chip->gates->%*;                                               # Gates on chip
  my $changed = $options{changed};                                              # Step at which gate last changed in simulation
  my $values  = $options{values};                                               # Values of each gate if known

  my @gates = sort {$gates{$a}->seq <=> $gates{$b}->seq} keys %gates;           # Gates in definition order
  if (my $c = $options{changed})                                                # Order non IO gates by last change time during simulation if possible
   {@gates = sort {($$c{$a}//0) <=> ($$c{$b}//0)} @gates;
   }

  my @fibers;                                                                   # Squares of the page, each of which can either be undefined or contain the name of the fiber crossing it from left to right or up and down
  my %corners;                                                                  # Corners of the fibers that we can currently hope to collapse
  my @inPlay;                                                                   # Squares of the page in play
  my @positions;                                                                # Position of each gate indexed by position in layout
  my %positions;                                                                # Position of each gate indexed by gate name
  my $width  = 1;                                                               # Width of page consumed so far until it becomes the page width.
  my $height = 0;                                                               # Height of page consumed so far until it becomes the page height

  for my $i(keys @gates)                                                        # Position each gate
   {my $g = $gates{$gates[$i]};                                                 # Gate details
    my $s = $g->type =~ m(\A(input|one|output|zero)\Z);                         # These gates can be positioned without consuming more horizontal space
    my %i = $g->inputs->%*;                                                     # Inputs hash for gate
    my @i = sort keys %i;                                                       # Connections to each gate in pin order
    my $w = $s ? 1 : scalar(@i);                                                # Width of this gate
    my $n = $g->name;                                                           # Name of gate

    my $x = $width; $x-- if $s;                                                 # Position of gate
    my $y = $i;

    my $p = genHash(__PACKAGE__."::GatePosition",
      name        => $g->name,                                                  # Gate name
      x           => $x,                                                        # Gate x position
      y           => $height,                                                   # Gate y position
      width       => $w,                                                        # Width of gate
      height      => 1,                                                         # Height of gate
##    fiber       => 0,                                                         # Number of fibers running past this gate
      position    => $i,                                                        # Sequence number for this gate on the layout
      type        => $g->type,                                                  # Type of gate
      value       => $$values {$g->name},                                       # Value of gate if known
      changed     => $$changed{$g->name},                                       # Last change time of gate if known
      inputs      => [map {$i{$_}}       @i],                                   # Names of gates driving input pins on this gate
      inputValues => [map {$$values{$i{$_}}} @i],                               # Values on input pins if known
     );

    $positions[$i] = $p;  $positions{$p->name} = $p;                            # Index the gates
    $width += $w unless $s;                                                     # Io gates are tucked in in such way that they do not contribute to the width
    $height++    unless $g->io == gateOuterOutput;                              # Output gates do not contribute to the height of the mask
   }

  for my $i(keys @positions)                                                    # Position output pins along bottom of mask
   {my $p = $positions[$i];
    next unless $gates{$p->name}->io == gateOuterOutput;
    my ($D) = $p->inputs->@*;                                                   # An output gate only has one input so we can safe relocate it next to the single gate that produces that output
    my  $d  = $positions{$D};                                                   # Driving gate
    $p->x = $d->x - 1;                                                          # Reposition output gate
    $p->y = $d->y;
   }

  my %op = outPins $chip;                                                       # Output pin name to chip

  for my $p(@positions)                                                         # Connect gates loosely
   {my $g = $gates{$p->name};                                                   # Detail for this gate
    my @i = $p->inputs->@*;                                                     # Connections to each gate
    for my $i(keys @i)                                                          # Connections to each gate
     {my $D = $i[$i];                                                           # Driving gate name
      my $d = $positions{$op{$D}[0]->name};                                     # Driving gate position
      my $x = $d->x;                                                            # X position of driving gate
      my $y = $d->y;                                                            # Y position of driving gate
      my $X = $p->x+$i;                                                         # X position of input pin to driven gate
      my $Y = $p->y;                                                            # Y position of input pin to driven gate
      $fibers[$_][$y][0] = $D for $x+$d->width..$X;                             # Horizontal line
      $fibers[$X][$_][1] = $D for $y..$Y-1;                                     # Vertical line
      $corners{$X}{$y}++;                                                       # Corner position
      if (!$g->io)                                                              # Mark column as in play
       {for my $j(0..$Y-1)
         {$inPlay[$X][$j] = 1;
         }
       }
     }
   }

  my sub collapseFibers()                                                       # Perform one collapse pass of the fibers returning the number of collapses performed
   {my $changes = 0;                                                            # Number of changes made in this pass

    for   my $i(sort {$a <=> $b} keys %corners)                                 # Examine each corner
     {for my $j(sort {$a <=> $b} keys $corners{$i}->%*)
       {my sub i() {$i}
        my sub j() {$j}
        my sub h($$) :lvalue {my ($i, $j) = @_; return undef unless $i >= 0 and $j >= 0 and $inPlay[$i][$j]; $fibers[$i][$j][0]} # A horizontal element relative to the current corner
        my sub v($$) :lvalue {my ($i, $j) = @_; return undef unless $i >= 0 and $j >= 0 and $inPlay[$i][$j]; $fibers[$i][$j][1]} # A vertical   element relative to the current corner

        my $a = h(i-1, j+0); my sub a() {$a}
        my $b = h(i+0, j+0);
        my $B = v(i+0, j+0);
        my $C = v(i+0, j+1);
        my $D = v(i+0, j-1);
        my $e = h(i+1, j+0);
        next unless defined($a) and defined($b) and defined($B) and defined($C);# Possible corner
        next unless $a eq $b and $b eq $B and $B eq $C;                         # Confirm corner
        next if defined($D) and $D eq $a;                                       # If it is a corner it points north east.
        next if defined($e) and $e eq $a;                                       # If it is a corner it points north east.

        if ($i > 0 and j+1 < $fibers[i]->$#*)                                   # Collapse left along one row
         {my $k; my sub k() :lvalue {$k}                                        # Position of new corner going left
          for my $I(reverse 0..i-1)                                             # Look for an opposite corner
           {last if $j+2 >= $fibers[$I]->$#*;
            my $h = h($I, j);                                                   # Make sure horizontal is occupied with expected bus line
            last   unless defined($h) and $h eq $a;                             # Make sure horizontal is occupied with expected bus line
            last   if  defined h($I, j+1);                                      # Horizontal is occupied so we will not be able to reuse it
            k = $I if !defined v($I, j+1);                                      # Possible opposite because it is not being used vertically
           }

          if (defined(k))                                                       # Reroute through new corner
           {v(i, j)   = undef;                                                  # Remove old upper right corner vertical
            v(k, j)   = a;                                                      # New upper left corner
            my $h = h(k-1, j); my $v = v(i, j+2);
            h(k, j)   = undef unless defined($h) and $h eq a;                   # Situation x: we might, or might not be on a corner here
            v(i, j+1) = undef unless defined($v) and $v eq a;                   # Situation y: we might, or might not be on a corner here
            h(k, j+1) = a;                                                      # New lower left corner
            v(k, j+1) = a;                                                      # New lower left corner
            for my $I(k+1..i)                                                   # Route along lower side
             {h($I, j  ) = undef;                                               # Remove upper side
              h($I, j+1) = a;                                                   # Add lower side
              my $v = v($I, j);                                                 # Crossing a T so we need to move the cross down one
              if (defined($v) and $v eq a)                                      # Crossing a T so we need to move the cross down one
               {v($I, j)   = undef;                                             # Remove upper cross
                v($I, j+1) = a;                                                 # Enable lower cross
               }
             }
            ++$changes;                                                         # Count changes
            $corners{$k}{$j}++;                                                 # Corner position upper left
            $corners{$i}{$j+1}++;                                               # Corner position lower right
            delete $corners{$i}{$j};                                            # Corner has been processed
            next;
           }
         }
#  d        |x           |
# abe       +-+    =>    |
#  c          |y         |
#             +--        +---

        if ($i > 0 and $j < $fibers[i]->$#*)                                    # Collapse down one column
         {my $k; my sub k() :lvalue {$k}                                        # Position of new corner going down
          for my $J(j..scalar($fibers[i-1]->$#*))                               # Look for an opposite corner
           {last unless defined(v(i,   $J)) and v(i,   $J) eq a;                # Make sure vertical is occupied with expected fiber
            last   if   defined(v(i-1, $J)) and v(i-1, $J) ne a;                # Vertical is occupied so we will not be able to reuse it
            k = $J if  !defined(h(i-1, $J));                                    # Possible corner as horizontal is free
           }

          if (defined(k))                                                       # Reroute through new corner
           {h(i,   j) = undef;                                                  # Remove old upper right corner horizontal
            v(i,   j) = undef;                                                  # Remove old upper right corner vertical
            v(i-1, j) = a;                                                      # New upper left corner
            my $h = h(i-2, j); my $v = v(i, k+1);
            h(i-1, j) = undef unless defined($h) and $h eq a;                   # Situation x: we might, or might not be on a corner here
            v(i,   k) = undef unless defined($v) and $v eq a;                   # Situation y: we might, or might not be on a corner here
            h(i-1, k) = a;                                                      # New lower left corner
            v(i-1, k) = a;                                                      # New lower left corner
            h(i, k) = a;                                                        # Add lower right corner
            for my $J(j..k-1)                                                   # Route down opposite side
             {v(i  , $J) = undef;                                               # Remove right side
              v(i-1, $J) = a;                                                   # Add left side
             }
            ++$changes;                                                         # Count changes
            $corners{$i-1}{$j}++;                                               # Corner position upper left
            $corners{$i}{$k}++;                                                 # Corner position lower right
            delete $corners{$i}{$j};                                            # Corner has been processed
            next;
           }
         }
        if (0 and $i > 2 and j+2 < $fibers[i]->$#*)                             # Try diagonally - this does not seem to occur frequently enough to justify substantial the overhead of testing for this possibility
         {my $aa = h($i-0, $j+0); my $AA = v($i-0, $j+0);
          my $bb = h($i-1, $j+0); my $BB = v($i-1, $j+0);
          my $cc = h($i-2, $j+0); my $CC = v($i-2, $j+0);

          my $dd = h($i-0, $j+1); my $DD = v($i-0, $j+1);
          my $ee = h($i-1, $j+1); my $EE = v($i-1, $j+1);
          my $ff = h($i-2, $j+1); my $FF = v($i-2, $j+1);

          my $gg = h($i-0, $j+2); my $GG = v($i-0, $j+2);
          my $hh = h($i-1, $j+2); my $HH = v($i-1, $j+2);
          my $ii = h($i-2, $j+2); my $II = v($i-2, $j+2);

#  c  b  a
#  f  e  d
#  i  h  g
          my sub req($) {my ($r) = @_;  defined($r) and $r eq a}                # Required to be the fiber we are currently working on
          my sub coa($) {my ($r) = @_; !defined($r) or  $r eq a}                # Clear or the current fiber
          my sub cna($) {my ($r) = @_; !defined($r) or  $r ne a}                # Clear or not the current fiber
          my sub clr($) {my ($r) = @_; !defined($r)}                            # Clear

          next unless cna($B);                                                  # Can we reroute through point i?

          next unless req($cc); next unless coa($CC);
          next unless cna($ee); next unless cna($EE);
          next unless clr($ff); next unless coa($FF);
          next unless coa($gg); next unless req($GG);
          next unless coa($hh); next unless cna($HH);
          next unless coa($ii); next unless coa($II);

          h(i-1, j) = undef;                                                    # Side above
          h(i-0, j) = undef                                                     #
          v(i, j+0) = undef;                                                    # Side on right
          v(i, j+1) = undef;                                                    #

          my $h = h(i-3, j); my $v = v(i, j+3);
          h(i-2, j) = undef unless defined($h) and $h eq a;                     # Situation x: we might, or might not be on a corner here
          v(i, j+2) = undef unless defined($v) and $v eq a;                     # Situation y: we might, or might not be on a corner here

          v(i-2,  j+$_) = a for 0..2;                                           # New left side
          h(i-$_, j+2)  = a for 0..2;                                           # New lower side
          ++$changes;                                                           # Count changes
          $corners{$i-2}{$j}++;                                                 # Corner position upper left
          $corners{$i}{$j+2}++;                                                 # Corner position lower right
          delete $corners{$i}{$j};                                              # Corner has been processed
          next;
         }
       }
      delete $corners{$i} if $corners{$i} and !keys($corners{$i}->%*);          # Remove sub hash if empty to speed up subsequent processing
     }

    $changes
   }

  for my $i(1..@positions) {last unless collapseFibers()}                       # Collapse fibers

  my $t = 0;                                                                    # Size of thickest bundle
  for   my $i(keys @fibers)
   {my $c = 0;
    for my $j(keys $fibers[$i]->@*)
     {++$c if defined $fibers[$i][$j][0];                                       # Only horizontal fibers count to the total thickness
     }
   $t = $c if $c > $t;
  }

  my $layout = genHash(__PACKAGE__."::LayoutLinear",                            # Details of layout
    chip           => $chip,                                                    # Chip being masked
    positionsArray => \@positions,                                              # Position array
    positionsHash  => \%positions,                                              # Position hash
    fibers         => \@fibers,                                                 # Fibers after collapse
    inPlay         => \@inPlay,                                                 # Squares in play for collapsing
    height         => $height,                                                  # Height of drawing
    width          => $width,                                                   # Width of drawing
    levels         => 1,                                                        # Gates and wiring at the same lavel
    steps          => $options{steps},                                          # Steps in simulation
    thickness      => $t,                                                       # Width of the thickest fiber bundle
   );

  $layout->draw(%options);                                                      # Draw the layout
 }

sub Silicon::Chip::LayoutLinear::draw($%)                                       #P Draw a mask for the gates.
 {my ($layout, %options) = @_;                                                  # Layout, options
  my $chip      = $layout->chip;                                                # Chip being masked
  my %gates     = $chip->gates->%*;                                             # Gates on chip
  my @fibers    = $layout->fibers->@*;                                          # Squares of the page, each of which can either be undefined or contain the name of the fiber crossing it from left to right or up and down
  my @inPlay    = $layout->inPlay->@*;                                          # Squares available for collapsing
  my @positions = $layout->positionsArray->@*;                                  # Position of each gate indexed by position in layout
  my %positions = $layout->positionsHash ->%*;                                  # Position of each gate indexed by gate name
  my $width     = $layout->width;                                               # Width of mask
  my $height    = $layout->height;                                              # Height of mask
  my $steps     = $layout->steps;                                               # Number of steps to equilibrium
  my $thickness = $layout->thickness;                                           # Thickness of fiber bundle

  my sub ts() {$height/64} my sub tw() {&ts/16} my sub tl() {1.25 * ts}         # Font sizes for titles
  my sub Ts() {2*ts}       my sub Tw() {2*tw}   my sub Tl() {2*tl}

  my sub fs() {1/6}        my sub fw() {&fs/16} my sub fl() {1.25 * fs}         # Font sizes for gates
  my sub Fs() {2*fs}       my sub Fw() {2*fw}   my sub Fl() {2*fl}

  my @defaults = (defaults=>                                                    # Default values
   {stroke_width => fw,
    font_size    => fs,
    fill         => q(transparent)});

  my $svg = Svg::Simple::new(@defaults, %options, grid=>debugMask ? 1 : 0);     # Draw each gate via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

  if (0)                                                                        # Show squares in play with a small number of rectangles
   {my @i = map {$_ ? [@$_] : $_} @inPlay;                                      # Deep copy
    for   my $i(keys @i)                                                        # Each row
     {for my $j(keys $i[$i]->@*)                                                # Each column
       {if ($i[$i][$j])                                                         # Found a square in play
         {my $w = 1;                                                            # Width of rectangle
          for my $I($i+1..$#inPlay)                                             # Extend as far as possible to the right
           {if ($i[$I][$j])
             {++$w;
              $i[$I][$j] = undef;                                               # Show that this square has been written - safe because we did a deep copy earlier
             }
           }
          $svg->rect(x=>$i, y=>$j, width=>$w, height=>1,
            fill=>"mistyrose", stroke=>"transparent");
         }
       }
     }
   }

  my $py = 0;
  my sub wt($;$)                                                                # Write titles on following lines
   {my ($t, $T) = @_;                                                           # Value, title to write
    if (defined($t))                                                            # Value to write
     {$py += Tl;                                                                # Position to write at
      my $s = $t; $s .= " $T" if $T;                                            # Text to write
      $svg->text(x => $width, y => $py, cdata => $s,                            # Write text
        fill=>"darkGreen", text_anchor=>"end", stroke_width=>Tw, font_size=>Ts);
     }
   }

  wt($chip->title);                                                             # Title if known
  wt($steps,     "steps");                                                      # Number of steps taken if known
  wt($thickness, "thick");                                                      # Thickness of bundle
  wt($width,     "wide");                                                       # Width of page
  wt($height,    "high");                                                       # Height of page

  for my $p(@positions)                                                         # Draw each gate
   {my $g = $gates{$p->name};                                                   # Gate details
    my $x = $p->x; my $y = $p->y; my $w = $p->width; my $h = $p->height;
    my $inPin  = $g->io == gateOuterInput;                                      # Input pin for chip
    my $outPin = $g->io == gateOuterOutput;                                     # Output pin for chip

    my $c = sub                                                                 # Color of gate
     {return "red"  if $inPin;
      return "blue" if $outPin;
      "green"
     }->();

    my $io = $inPin || $outPin;                                                 # Input/Output pin on chip

    $svg->circle(cx => $x+1/2, cy=>$y+1/2, r=>1/2,  stroke=>$c) if  $io;        # Circle for io pin
    $svg->rect(x=>$x, y=>$y, width=>$w, height=>$h, stroke=>$c) if !$io;        # Rectangle for non io gate

    if (defined(my $v = $p->value))                                             # Value of gate if known
     {$svg->text(
       x                 => $p->x,
       y                 => $p->y,
       fill              =>"black",
       stroke_width      => Fw,
       font_size         => Fs,
       text_anchor       => "start",
       dominant_baseline => "hanging",
       cdata             => $v ? "1" : "0");
     }

    if (defined(my $t = $p->changed) and !$io)                                  # Gate change time if known for a non io gate
     {$svg->text(
       x                 => $p->x + $p->width,
       y                 => $p->y + 1,
       fill              => "darkBlue",
       stroke_width      => fw,
       font_size         => fs,
       text_anchor       => "end",
       cdata             => $t+1);
     }

    my sub ot($$$$)                                                             # Output svg text
     {my ($dy, $fill, $pos, $text) = @_;
      $svg->text(x                 => $p->x+$p->width/2,
                 y                 => $p->y+$dy,
                 fill              => $fill,
                 text_anchor       => "middle",
                 dominant_baseline => $pos,
                 cdata             => $text);
      }

    ot(5/12, "red",      "auto",    $p->type);                                  # Type of gate
    ot(7/12, "darkblue", "hanging", $p->name);

    my @i = $p->inputValues->@*;

    for my $i(keys @i)                                                          # Draw input values to each pin on the gate
     {next if $io;
      my $v = $p->inputValues->[$i];
      if (defined($v))
       {$svg->text(
          x                 => $p->x + $i + 1/2,
          y                 => $p->y,
          fill              => "darkRed",
          stroke_width      => fw,
          font_size         => fs,
          text_anchor       => "middle",
          dominant_baseline => "hanging",
          cdata             => $v ? "1" : "0");
       }
     }
   }

  if (debugMask)                                                                # Show fiber names - useful when debugging bus lines
   {for my $i(keys @fibers)
     {for my $j(keys $fibers[$i]->@*)
       {if (defined(my $n = $fibers[$i][$j][0]))                                # Horizontal
         {$svg->text(
            x                 => $i+1/2,
            y                 => $j+1/2,
            fill              =>"black",
            stroke_width      => fw,
            font_size         => fs,
            text_anchor       => 'middle',
            dominant_baseline => 'auto',
            cdata             => $n,
           )# if $n eq "a4" || $n eq "a4";
         }
        if (defined(my $n = $fibers[$i][$j][1]))                                # Vertical
         {$svg->text(
            x                 => $i+1/2,
            y                 => $j+1/2,
            fill              =>"red",
            stroke_width      => fw,
            font_size         => fs,
            text_anchor       => 'middle',
            dominant_baseline => 'hanging',
            cdata             => $n,
           )# if $n eq "a4" || $n eq "a4";
         }
       }
     }
   }

  if (1)                                                                        # Show fiber lines
   {my @h = (stroke =>"darkgreen", stroke_width => Fw);                         # Fiber lines horizontal
    my @v = (stroke =>"darkgreen", stroke_width => Fw);                         # Fiber lines vertical
    my @f = @fibers;
    my @i = @inPlay;
    my @H; my @V;                                                               # Straight line cells

    for my $i(keys @f)
     {for my $j(keys $f[$i]->@*)
       {my $h = $f[$i][$j][0];                                                  # Horizontal
        my $v = $f[$i][$j][1];                                                  # Vertical

        if (defined($h) and defined($v) and $h eq $v)                           # Cross
         {my $l = !$i[$i-1][$j]     || ($i[$i-1][$j] && ($f[$i-1][$j][0]//'') eq $h); # Left horizontal
          my $r =                       $i[$i+1][$j] && ($f[$i+1][$j][0]//'') eq $h;  # Right horizontal
          my $a = $j >  0           &&  $i[$i][$j-1] && ($f[$i][$j-1][1]//'') eq $h;  # Vertically above
          my $b = $j >= $f[$i]->$#* || ($i[$i][$j+1] && ($f[$i][$j+1][1]//'') eq $h); # Vertically below

#     | A     --+   |C       D
#     +--     B |   +--    --+--
#                   |        |

          my $D = $l && $r && $b;
          my $C = $a && $r && $b;
          my $A = $a && $r;
          my $B = $l && $b;

          my @B = my @A = (r=>    Fw, fill=>"darkRed");                         # Fiber connections
          my @C =         (r=>1.5*Fw, fill=>"darkRed");

          if ($C)
           {$svg->line(x1=>$i+1/2,   y1=>$j,     x2=>$i+1/2, y2=>$j+1,   @h);
            $svg->line(x1=>$i+1/2,   y1=>$j+1/2, x2=>$i+1,   y2=>$j+1/2, @h);
            $svg->circle(cx=>$i+1/2, cy=>$j+1/2, @C);
           }
          elsif ($D)
           {$svg->line(x1=>$i,       y1=>$j+1/2, x2=>$i+1,   y2=>$j+1/2, @h);
            $svg->line(x1=>$i+1/2,   y1=>$j+1/2, x2=>$i+1/2, y2=>$j+1,   @h);
            $svg->circle(cx=>$i+1/2, cy=>$j+1/2, @C);
           }
          elsif ($A)                                                            # Draw corners
           {$svg->line  (x1=>$i+1/2, y1=>$j,     x2=>$i+1,   y2=>$j+1/2, @h);
            $svg->circle(cx=>$i+1/2, cy=>$j,     @A);
            $svg->circle(cx=>$i+1,   cy=>$j+1/2, @A);
           }
          elsif ($B)
           {$svg->line  (x1=>$i,     y1=>$j+1/2, x2=>$i+1/2, y2=>$j+1, @h);
            $svg->circle(cx=>$i,     cy=>$j+1/2, @B);
            $svg->circle(cx=>$i+1/2, cy=>$j+1,   @B);
           }
         }
        else                                                                    # Straight
         {$H[$i][$j] = $h;                                                      # Horizontal
          $V[$i][$j] = $v;                                                      # Vertical
         }
       }
     }

    my @hc = (stroke => "darkgreen", stroke_width => Fw);                       # Horizontal line color
    my @vc = (stroke => "darkgreen", stroke_width => Fw);                       # Vertical   line color

    for my $i(keys @f)                                                          # Draw horizontal and vertical bars with a minimal number of lines otherwise the svg files get very big
     {for my $j(keys $f[$i]->@*)
       {if (defined(my $h = $H[$i][$j]))                                        # Horizontal
         {my $e = $i;
          for my $I($i..$#f)                                                    # Go as far right as possible
           {my $H = \$H[$I][$j];
            last unless $$H and $$H eq $h;                                      # Still in line
            $$H = undef;                                                        # Erase line as no longer needed
            $e  = $I;                                                           # Current known end of the line
           }
          $svg->line(x1=>$i, y1=>$j+1/2, x2=>$e+1, y2=>$j+1/2, @hc);            # Draw horizontal line
         }
        if (defined(my $v = $V[$i][$j]))                                        # Vertical
         {my $e = $j;
          for my $J($j..$f[$i]->$#*)                                            # Go as far down as possible
           {my $V = \$V[$i][$J];
            last unless $$V and $$V eq $v;                                      # Still in line
            $$V = undef;                                                        # Erase line as no longer needed
            $e  = $J;                                                           # Current known end of the line
           }
          $svg->line(x1=>$i+1/2, y1=>$j, x2=>$i+1/2, y2=>$e+1, @vc);            # Draw vertical line
         }
       }
     }
   }

  my $t = $svg->print;                                                          # Text of svg
  my $f = $options{svg};                                                        # Svg file
  return owf(fpe(q(svg), $f, q(svg)), $t) if $f;                                # Draw bundle as an svg drawing
  $t
 }

my %drawMask;                                                                   # Track masks drawn so we can complain about duplicates

my sub drawMask($%)                                                             # Draw a mask for the gates.
 {my ($chip, %options) = @_;                                                    # Chip, options
  my $s = $options{svg};
  $drawMask{$s}++ and confess <<"END" =~ s/\n(.)/ $1/gsr;                       # Complain about duplicate mask names
Duplicate mask name: $s specified
END

  my $layout = $options{layout} // '';                                          # Mask layout
  if ($layout =~ m(\Alinear\Z)i)                                                # Draw mask
   {return layoutLinear($chip, %options);                                       # Linear layout
   }
  else
   {return layoutSquare($chip, %options);                                       # Square layout
   }
 }

#D2 GDS2                                                                        # Graphic Design System Layout for a chip which can be visualized using KLayout.

sub gds2($$$%)                                                                  #P Draw the chip using GDS2
 {my ($chip, $layout, $wiring, %options) = @_;                                  # Chip, layout, wiring, options
  my $delta  = 1/4;                                                             # Offset from edge of each gate cell
  my $wireWidth  = 1/4;                                                         # Width of a wire

  confess "gdsOut required" unless my $outGds = $options{svg};                  # Output file required
  my $outFile = createEmptyFile(fpe qw(gds), $outGds, qw(gds));                 # Create output file to make any folders needed

  my $g = new GDS2(-fileName=>">$outFile");                                     # Draw as Graphics Design System 2
  $g->printInitLib(-name=>$outGds);
  $g->printBgnstr (-name=>$outGds);

# This code to layout the gates ought to be moved to Silicon::Chip::Layout
  my @l = $layout->gates->@*;                                                   # Layout the gates level
  for my $l(@l)
   {my ($x, $y, $h, $w, $n) = @$l{qw(x y h w l)};
    $g->printBoundary(-layer=>0, -xy=>[$x, $y,  $x+$w-3/4, $y,  $x+$w-3/4, $y+$h-3/4, $x, $y + $h-3/4]);
    $g->printText(-string=>$n,   -xy=>[$x+$w/2, $y+$h/2], -font=>3) if $n;      # Y coordinate
   }

  $wiring->gds2(block=>$g);                                                     # Draw wiring

  $g->printEndstr;
  $g->printEndlib();                                                            # Close the library
 }

#D1 Basic Circuits                                                              # Some well known basic circuits.

sub n(*$)                                                                       # Gate name from single index.
 {my ($c, $i) = @_;                                                             # Gate name, bit number
  !@_ or !ref($_[0]) or confess <<"END";
Call as a sub not as a method
END
  "${c}_$i"
 }

sub nn(*$$)                                                                     # Gate name from double index.
 {my ($c, $i, $j) = @_;                                                         # Gate name, word number, bit number
  !@_ or !ref($_[0]) or confess confess <<"END";
Call as a sub not as a method
END
 "${c}_${i}_$j"
 }

#D2 Comparisons                                                                 # Compare unsigned binary integers of specified bit widths.

sub compareEq($$$$%)                                                            # Compare two unsigned binary integers of a specified width returning B<1> if they are equal else B<0>.
 {my ($chip, $output, $a, $b, %options) = @_;                                   # Chip, name of component also the output bus, first integer, second integer, options
  @_ >= 4 or confess "Four or more parameters";
  my $o  = $output;
  my $A = sizeBits($chip, $a);
  my $B = sizeBits($chip, $b);
  $A == $B or confess <<"END" =~ s/\n(.)/ $1/gsr;
Input $a has width $A but input $b has width $B
END
  $chip->nxor(n("$o.e", $_), n($a, $_), n($b, $_)) for 1..$B;                   # Test each bit pair for equality
  $chip->andBits($o, "$o.e", bits=>$B);                                         # All bits must be equal

  $chip
 }

sub compareGt($$$$%)                                                            # Compare two unsigned binary integers and return B<1> if the first integer is more than B<b> else B<0>.
 {my ($chip, $output, $a, $b, %options) = @_;                                   # Chip, name of component also the output bus, first integer, second integer, options
  @_ >= 4 or confess "Four or more parameters";
  my $o  = $output;
  my $A = sizeBits($chip, $a);
  my $B = sizeBits($chip, $b);
  $A == $B or confess <<"END" =~ s/\n(.)/ $1/gsr;
Input $a has width $A but input $b has width $B
END
  $chip->nxor (n("$o.e", $_), n($a, $_), n($b, $_)) for 2..$B;                  # Test all but the lowest bit pair for equality
  $chip->gt   (n("$o.g", $_), n($a, $_), n($b, $_)) for 1..$B;                  # Test each bit pair for more than

  for my $b(2..$B)                                                              # More than on one bit and all preceding bits are equal
   {$chip->and(n("$o.c", $b),
     {(map {$_=>n("$o.e", $_)} $b..$B), ($b-1)=>n("$o.g", $b-1)});
   }

  $chip->or   ($o, {$B=>n("$o.g", $B),  (map {($_-1)=>n("$o.c", $_)} 2..$B)});  # Any set bit indicates that B<a> is more than B<b>

  $chip
 }

sub compareLt($$$$%)                                                            # Compare two unsigned binary integers B<a>, B<b> of a specified width. Output B<out> is B<1> if B<a> is less than B<b> else B<0>.
 {my ($chip, $output, $a, $b, %options) = @_;                                   # Chip, name of component also the output bus, first integer, second integer, options
  @_ >= 4 or confess "Four or more parameters";

  my $A = sizeBits($chip, $a);
  my $B = sizeBits($chip, $b);
  $A == $B or confess <<"END" =~ s/\n(.)/ $1/gsr;
Input $a has width $A but input $b has width $B
END

  my $o = $output;

  $chip->nxor (n("$o.e", $_), n($a, $_), n($b, $_)) for 2..$B;                  # Test all but the lowest bit pair for equality
  $chip->lt   (n("$o.l", $_), n($a, $_), n($b, $_)) for 1..$B;                  # Test each bit pair for less than

  for my $b(2..$B)                                                              # More than on one bit and all preceding bits are equal
   {$chip->and(n("$o.c", $b),
     {(map {$_=>n("$o.e", $_)} $b..$B), ($b-1)=>n("$o.l", $b-1)});
   }

  $chip->or   ($o, {$B=>n("$o.l", $B),  (map {($_-1)=>n("$o.c", $_)} 2..$B)});  # Any set bit indicates that B<a> is less than B<b>

  $chip
 }

sub chooseFromTwoWords($$$$$%)                                                  # Choose one of two words based on a bit.  The first word is chosen if the bit is B<0> otherwise the second word is chosen.
 {my ($chip, $output, $a, $b, $choose, %options) = @_;                          # Chip, name of component also the chosen word, the first word, the second word, the choosing bit, options
  @_ >= 5 or confess "Five or more parameters";
  my $o = $output;

  my $A = sizeBits($chip, $a);
  my $B = sizeBits($chip, $b);
  $A == $B or confess <<"END" =~ s/\n(.)/ $1/gsr;
Input $a has width $A but input $b has width $B
END

  $chip->not("$o.n", $choose);                                                  # Not of the choosing bit
  for my $i(1..$B)
   {$chip->and(n("$o.a", $i), [n($a, $i),     "$o.n"       ]);                  # Choose first word
    $chip->and(n("$o.b", $i), [n($b, $i),     $choose      ]);                  # Choose second word
    $chip->or (n($o,     $i), [n("$o.a", $i), n("$o.b", $i)]);                  # Or results of choice
   }
  setSizeBits($chip, $o, $B);                                                   # Record bus size

  $chip
 }

sub enableWord($$$$%)                                                           # Output a word or zeros depending on a choice bit.  The first word is chosen if the choice bit is B<1> otherwise all zeroes are chosen.
 {my ($chip, $output, $a, $enable, %options) = @_;                              # Chip, name of component also the chosen word, the first word, the second word, the choosing bit, options
  @_ >= 4 or confess "Four or more parameters";
  my $o = $output;
  my $B = sizeBits($chip, $a);

  for my $i(1..$B)                                                              # Choose each bit of input word
   {$chip->and(n($o, $i), [n($a, $i), $enable]);
   }
  setSizeBits($chip, $o, $B);                                                   # Record bus size
  $chip
 }

#D2 Masks                                                                       # Point masks and monotone masks. A point mask has a single B<1> in a sea of B<0>s as in B<00100>.  A monotone mask has zero or more B<0>s followed by all B<1>s as in: B<00111>.

sub pointMaskToInteger($$$%)                                                    # Convert a mask B<i> known to have at most a single bit on - also known as a B<point mask> - to an output number B<a> representing the location in the mask of the bit set to B<1>. If no such bit exists in the point mask then output number B<a> is B<0>.
 {my ($chip, $output, $input, %options) = @_;                                   # Chip, output name, input mask, options
  @_ >= 3 or confess "Three or more parameters";
  my $B = sizeBits($chip, $input);                                              # Bits in input bus
  my $I = containingPowerOfTwo($B);                                             # Bits in integer
  my $i = $input;                                                               # The bits in the input mask
  my $o = $output;                                                              # The name of the output bus

  my %b;
  for my $b(1..$B)                                                              # Bits in mask to bits in resulting number
   {my $s = sprintf "%b", $b;
    for my $p(1..length($s))
     {$b{$p}{$b}++ if substr($s, -$p, 1);
     }
   }

  for my $b(sort keys %b)
   {$chip->or(n($o, $b), {map {$_=>n($i, $_)} sort keys $b{$b}->%*});           # Bits needed to drive a bit in the resulting number
   }
  setSizeBits $chip, $o, $I;                                                    # Size of resulting integer
  $chip
 }

sub integerToPointMask($$$%)                                                    # Convert an integer B<i> of specified width to a point mask B<m>. If the input integer is B<0> then the mask is all zeroes as well.
 {my ($chip, $output, $input, %options) = @_;                                   # Chip, output name, input mask, options
  @_ >= 3 or confess "Three or more parameters";
  my $bits = sizeBits($chip, $input);                                           # Size of input integer in bits
  my $B = 2**$bits-1;
  my $o = $output;                                                              # Output mask

  $chip->notBits("$o.n", $input);                                               # Not of each input

  for my $b(1..$B)                                                              # Each bit of the mask
   {my @s = reverse split //, sprintf "%0${bits}b", $b;                         # Bits for this point in the mask
    my %a;
    for my $i(1..@s)
     {$a{$i} = n($s[$i-1] ? 'i' : "$o.n", $i);                                  # Combination of bits to enable this mask bit
     }
    $chip->and(n($output, $b), {%a});                                           # And to set this point in the mask
   }
  setSizeBits($chip, $output, $B);                                              # Size of output bus

  $chip
 }

sub monotoneMaskToInteger($$$%)                                                 # Convert a monotone mask B<i> to an output number B<r> representing the location in the mask of the bit set to B<1>. If no such bit exists in the point then output in B<r> is B<0>.
 {my ($chip, $output, $input, %options) = @_;                                   # Chip, output name, input mask, options
  @_ >= 3 or confess "Three or more parameters";
  my $B = sizeBits($chip, $input);
  my $I = containingPowerOfTwo($B);
  my $o = $output;

  my %b;
  for my $b(1..$B)
   {my $s = sprintf "%b", $b;
    for my $p(1..length($s))
     {$b{$p}{$b}++ if substr($s, -$p, 1);
     }
   }
  $chip->not     (n("$o.n", $_), n($input, $_)) for 1..$B-1;                    # Not of each input
  $chip->continue(n("$o.a", 1),  n($input, 1));
  $chip->and     (n("$o.a", $_), [n("$o.n", $_-1), n('i', $_)]) for 2..$B;      # Look for trailing edge

  for my $b(sort keys %b)
   {$chip->or    (n($o, $b), [map {n("$o.a", $_)} sort keys $b{$b}->%*]);       # Bits needed to drive a bit in the resulting number
   }
  setSizeBits($chip, $o, $I);

  $chip
 }

sub monotoneMaskToPointMask($$$%)                                               # Convert a monotone mask B<i> to a point mask B<o> representing the location in the mask of the first bit set to B<1>. If the monotone mask is all B<0>s then point mask is too.
 {my ($chip, $output, $input, %options) = @_;                                   # Chip, output name, input mask, options
  @_ >= 3 or confess "Three or more parameters";
  my $o = $output;
  my $bits = sizeBits($chip, $input);
  $chip->continue(n($o, 1), n($input, 1));                                      # The first bit in the monotone mask matches the first bit of the point mask
  for my $b(2..$bits)
   {$chip->xor(n($o, $b), n($input, $b-1), n($input, $b));                      # Detect transition
   }
  setSizeBits($chip, $o, $bits);

  $chip
 }

sub integerToMonotoneMask($$$%)                                                 # Convert an integer B<i> of specified width to a monotone mask B<m>. If the input integer is B<0> then the mask is all zeroes.  Otherwise the mask has B<i-1> leading zeroes followed by all ones thereafter.
 {my ($chip, $output, $input, %options) = @_;                                   # Chip, output name, input mask, options
  @_ >= 3 or confess "Three or more parameters";
  my $I = sizeBits($chip, $input);
  my $B = 2**$I-1;
  my $o = $output;

  $chip->notBits("$o.n", $input);                                               # Not of each input

  for my $b(1..$B)                                                              # Each bit of the mask
   {my @s = (reverse split //, sprintf "%0${I}b", $b);                          # Bits for this point in the mask
    my %a;
    for  my $i(1..@s)
     {$a{$i} = n($s[$i-1] ? $input : "$o.n", $i);                               # Choose either the input bit or the not of the input but depending on the number being converted to binary
     }
    $chip->and(n("$o.a", $b), {%a});                                            # Set at this point and beyond
    $chip-> or(n($o, $b), [map {n("$o.a", $_)} 1..$b]);                         # Set mask
   }
  setSizeBits($chip, $o, $B);
  $chip
 }

sub chooseWordUnderMask($$$$%)                                                  # Choose one of a specified number of words B<w>, each of a specified width, using a point mask B<m> placing the selected word in B<o>.  If no word is selected then B<o> will be zero.
 {my ($chip, $output, $input, $mask, %options) = @_;                            # Chip, output, inputs, mask, options
  @_ >= 3 or confess "Three or more parameters";
  my $o = $output;

  my ($words, $bits) = sizeWords($chip, $input);
  my ($mi)           = sizeBits ($chip, $mask);
  $mi == $words or confess <<"END" =~ s/\n(.)/ $1/gsr;
Mask width $mi does not match number of words $words.
END

  for   my $w(1..$words)                                                        # And each bit of each word with the mask
   {for my $b(1..$bits)                                                         # Bits in each word
     {$chip->and(nn("$o.a", $w, $b), [n($mask, $w), nn($input, $w, $b)]);
     }
   }

  for   my $b(1..$bits)                                                         # Bits in each word
   {$chip->or(n($o, $b), [map {nn("$o.a", $_, $b)} 1..$words]);
   }
  setSizeBits($chip, $o, $bits);

  $chip
 }

sub findWord($$$$%)                                                             # Choose one of a specified number of words B<w>, each of a specified width, using a key B<k>.  Return a point mask B<o> indicating the locations of the key if found or or a mask equal to all zeroes if the key is not present.
 {my ($chip, $output, $key, $words, %options) = @_;                             # Chip, found point mask, key, words to search, options
  @_ >= 4 or confess "Four or more parameters";
  my $o = $output;
  my ($W, $B) = sizeWords($chip, $words);
  my $bits    = sizeBits ($chip, $key);
  $B == $bits or confess <<"END" =~ s/\n(.)/ $1/gsr;
Number of bits in each word $B differs from words in key $bits.
END
  for   my $w(1..$W)                                                            # Input words
   {$chip->compareEq(n($o, $w), n($words, $w), $key);                           # Compare each input word with the key to make a mask
   }
  setSizeBits($chip, $o, $W);

  $chip
 }

#D1 Simulate                                                                    # Simulate the behavior of the L<chip> given a set of values on its input gates.

my sub setBit($*$%)                                                             # Set a single bit
 {my ($chip, $name, $value, %options) = @_;                                     # Chip, name of input gates, number to set to, options
  @_ >= 3 or confess "Three or more parameters";
  my $g = getGate($chip, $name);
  my $t = $g->type;
  $g->io == gateOuterInput or confess <<"END" =~ s/\n(.)/ $1/gsr;
Only outer input gates are setable. Gate $name is of type $t
END
  my %i = ($name => $value ? $value : 0);
  %i
 }

sub setBits($*$%)                                                               # Set an array of input gates to a number prior to running a simulation.
 {my ($chip, $name, $value, %options) = @_;                                     # Chip, name of input gates, number to set to, options
  @_ >= 3 or confess "Three or more parameters";
  my $bits = sizeBits($chip, $name);                                            # Size of bus
  my $W = 2**$bits;
  $value >= 0 or confess <<"END";
Value $value is less than 0
END
  $value < $W or confess <<"END";
Value $value is greater then or equal to $W
END
  my @b = reverse split //,  sprintf "%0${bits}b", $value;
  my %i = map {n($name, $_) => $b[$_-1]} 1..$bits;
  %i
 }

sub setWords($$@)                                                               # Set an array of arrays of gates to an array of numbers prior to running a simulation.
 {my ($chip, $name, @values) = @_;                                              # Chip, name of input gates, number of bits in each array element, numbers to set to
  @_ >= 3 or confess "Three or more parameters";
  my ($words, $bits) = sizeWords($chip, $name);
  my %i;
  my $M = 2**$bits-1;                                                           # Maximum we can store in a word of this many bits
  for   my $w(1..$words)                                                        # Each word
   {my $n = shift @values;
    $n >= 0 or confess <<"END";
Value $n is less than 0
END
    $n <= $M or confess <<"END";
 "Value $n is greater then or equal to $M";
END
    my @b = split //,  sprintf "%0${bits}b", $n;
    for my $b(1..$bits)                                                         # Each bit
     {$i{nn($name, $w, $b)} = $b[-$b];
     }
   }
  %i
 }

sub connectBits($*$*%)                                                          # Create a connection list connecting a set of output bits on the one chip to a set of input bits on another chip.
 {my ($oc, $o, $ic, $i, %options) = @_;                                         # First chip, name of gates on first chip, second chip, names of gates on second chip, options
  @_ >= 4 or confess "Four or more parameters";
  my %c;
  my $O = sizeBits($oc, $o);
  my $I = sizeBits($ic, $i);
  $O == $I or confess <<"END";
Mismatch between size of bus $o at $O and bus $i at $I
END

  for my $b(1..$I)                                                              # Bit to connect
   {$c{n($o, $b)} = n($i, $b);                                                  # Connect bits
   }
  %c                                                                            # Connection list
 }

sub connectWords($*$*$$%)                                                       # Create a connection list connecting a set of words on the outer chip to a set of words on the inner chip.
 {my ($oc, $o, $ic, $i, $words, $bits, %options) = @_;                          # First chip, name of gates on first chip, second chip, names of gates on second chip, number of words to connect, options
  @_ >= 6 or confess "Six or more parameters";
  my %c;
  for   my $w(1..$bits)                                                         # Word to connect
   {for my $b(1..$bits)                                                         # Bit to connect
     {$c{nn($o, $w, $b)} = nn($i, $w, $b);                                      # Connection list
     }
   }
  %c                                                                            # Connection list
 }

my sub merge($%)                                                                # Merge a L<chip> and all its sub L<chips> to make a single L<chip>.
 {my ($chip, %options) = @_;                                                    # Chip, options

  my $gates = getGates $chip;                                                   # Gates implementing the chip and all of its sub chips

  setOuterGates ($chip, $gates);                                                # Set the outer gates which are to be connected to in the real word
  removeExcessIO($chip, $gates);                                                # By pass and then remove all interior IO gates as they are no longer needed

  my $c = newChip %$chip, %options, gates=>$gates, installs=>[];                # Create the new chip with all installs expanded
  #print($c, %options)     if $options{print};                                  # Print the gates
  #printSvg ($c, %options) if $options{svg};                                    # Draw the gates using svg
  checkIO $c;                                                                   # Check all inputs are connected to valid gates and that all outputs are used

  addFans $c;                                                                   # Add any fanOut gates needed to ensure that all wires start and end on unique points to simplify the wiring diagram
  $c
 }

sub Silicon::Chip::Simulation::value($$%)                                       # Get the value of a gate as seen in a simulation.
 {my ($simulation, $name, %options) = @_;                                       # Chip, gate, options
  @_ >= 2 or confess "Two or more parameters";
  $simulation->values->{$name}                                                  # Value of gate
 }

my sub checkInputs($$%)                                                         # Check that an input value has been provided for every input pin on the chip.
 {my ($chip, $inputs, %options) = @_;                                           # Chip, inputs, hash of final values for each gate, options

  for my $g(values $chip->gates->%*)                                            # Each gate on chip
   {if   ($g->io == gateOuterInput)                                             # Outer input gate
     {my ($i) = values $g->inputs->%*;                                          # Inputs
      if (!defined($$inputs{$i}))                                               # Check we have a corresponding input
       {my $n = $g->name;
        confess "No input value for input gate: $n\n";
       }
     }
   }
 }

sub Silicon::Chip::Simulation::bInt($$%)                                        # Represent the state of bits in the simulation results as an unsigned binary integer.
 {my ($simulation, $output, %options) = @_;                                     # Chip, name of gates on bus, options
  @_ >= 2 or confess "Two or more parameters";
  my $B = sizeBits($simulation->chip, $output);
  my %v = $simulation->values->%*;
  my @b;
  for my $b(1..$B)                                                              # Bits
   {push @b, $v{n $output, $b};
   }

  eval join '', '0b', reverse @b;                                               # Convert to number
 }

sub Silicon::Chip::Simulation::wInt($$%)                                        # Represent the state of words in the simulation results as an array of unsigned binary integer.
 {my ($simulation, $output, %options) = @_;                                     # Chip, name of gates on bus, options
  @_ >= 2 or confess "Two or more parameters";
  my ($words, $bits) = sizeWords($simulation->chip, $output);
  my %v = $simulation->values->%*;
  my @w;
  for my $w(1..$words)                                                          # Words
   {my @b;
    for my $b(1..$bits)                                                         # Bits
     {push @b, $v{nn $output, $w, $b};
     }

    push @w,  eval join '', '0b', reverse @b;                                   # Convert to number
   }
  @w
 }

sub Silicon::Chip::Simulation::wordXToInteger($$%)                              # Represent the state of words in the simulation results as an array of unsigned binary integer.
 {my ($simulation, $output, %options) = @_;                                     # Chip, name of gates on bus, options
  @_ >= 2 or confess "Two or more parameters";
  my ($words, $bits) = sizeWords($simulation->chip, $output);
  my %v = $simulation->values->%*;
  my @w;
  for my $b(1..$bits)                                                           # Bits
   {my @b;
    for my $w(1..$words)                                                        # Words
     {push @b, $v{nn $output, $w, $b};
     }

    push @w,  eval join '', '0b', reverse @b;                                   # Convert to number
   }
  @w
 }

my sub simulationStep($$%)                                                      # One step in the simulation of the L<chip> after expansion of inner L<chips>.
 {my ($chip, $values, %options) = @_;                                           # Chip, current value of each gate, options
  my $gates = $chip->gates;                                                     # Gates on chip
  my %changes;                                                                  # Changes made

  for my $G(sort {$$gates{$a}->seq <=> $$gates{$b}->seq} keys %$gates)          # Each gate in sub chip on definition order to get a repeatable order
   {my $g = $$gates{$G};                                                        # Address gate
    my $t = $g->type;                                                           # Gate type
    my $n = $g->name;                                                           # Gate name
    my %i = $g->inputs->%*;                                                     # Inputs to gate
    my @i = map {$$values{$i{$_}}} sort keys %i;                                # Values of inputs to gates in input pin name order

    my $u = 0;                                                                  # Number of undefined inputs
    for my $i(@i)
     {++$u unless defined $i;
     }

    if ($u == 0)                                                                # All inputs defined
     {my $r;                                                                    # Result of gate operation
      if ($t =~ m(\Aand|nand\Z)i)                                               # Elaborate and B<and> and B<nand> gates
       {my $z = grep {!$_} @i;                                                  # Count zero inputs
        $r = $z ? 0 : 1;
        $r = !$r if $t =~ m(\Anand\Z)i;
       }
      elsif ($t =~ m(\A(input)\Z)i)                                             # An B<input> gate takes its value from the list of inputs or from an output gate in an inner chip
       {if (my @i = values $g->inputs->%*)                                      # Get the value of the input gate from the current values
         {my $n = $i[0];
             $r = $$values{$n};
         }
        else
         {confess "No driver for input gate: $n\n";
         }
       }
      elsif ($t =~ m(\A(continue|nor|not|or|output)\Z)i)                        # Elaborate B<not>, B<or> or B<output> gate. A B<continue> gate places its single input unchanged on its output
       {my $o = grep {$_} @i;                                                   # Count one inputs
        $r = $o ? 1 : 0;
        $r = $r ? 0 : 1 if $t =~ m(\Anor|not\Z)i;
       }
      elsif ($t =~ m(\A(nxor|xor)\Z)i)                                          # Elaborate B<xor>
       {@i == 2 or confess "$t gate: '$n' must have exactly two inputs\n";
        $r = $i[0] ^ $i[1] ? 1 : 0;
        $r = $r ? 0 : 1 if $t =~ m(\Anxor\Z)i;
       }
      elsif ($t =~ m(\A(gt|ngt)\Z)i)                                            # Elaborate B<a> more than B<b> - the input pins are assumed to be sorted by name with the first pin as B<a> and the second as B<b>
       {@i == 2 or confess "$t gate: '$n' must have exactly two inputs\n";
        $r = $i[0] > $i[1] ? 1 : 0;
        $r = $r ? 0 : 1 if $t =~ m(\Angt\Z)i;
       }
      elsif ($t =~ m(\A(lt|nlt)\Z)i)                                            # Elaborate B<a> less than B<b> - the input pins are assumed to be sorted by name with the first pin as B<a> and the second as B<b>
       {@i == 2 or confess "$t gate: '$n' must have exactly two inputs\n";
        $r = $i[0] < $i[1] ? 1 : 0;
        $r = $r ? 0 : 1 if $t =~ m(\Anlt\Z)i;
       }
      elsif ($t =~ m(\Aone\Z)i)                                                 # One
       {@i == 0 or confess "$t gate: '$n' must have no inputs\n";
        $r = 1;
       }
      elsif ($t =~ m(\Azero\Z)i)                                                # Zero
       {@i == 0 or confess "$t gate: '$n' must have no inputs\n";
        $r = 0;
       }
      elsif ($t =~ m(\AfanOut\Z)i)                                              # Fanout
       {$r = $i[0];
        for my $o($g->output->@*)                                               # Fan onput to each output pin if not already set
         {$changes{$o} = $r unless defined($$values{$o}) and $$values{$o} == $r;
         }
       }
      else                                                                      # Unknown gate type
       {confess "Need implementation for '$t' gates";
       }
      $changes{$G} = $r unless defined($$values{$G}) and $$values{$G} == $r;    # Value computed by this gate
     }
   }
  %changes
 }

sub Silicon::Chip::Simulation::checkLevelsMatch($%)                             # Check that the specified number of levels matches that specified by the pngs parameter.  The pngs paramneter tells us howmany drawings to make - one per level - ideally this should match the actual number of levels.
 {my ($simulation, %options) = @_;                                              # Simulation, options
  my $log    = $options{log} // 0;                                              # Logging required
  my $levels = $simulation->levels // 0;                                        # Levels actual
  my $pngs   = $simulation->options->{pngs} // 0;                               # Levels expected
  my $T = $levels == $pngs;                                                     # Confirm pngs is levels
  cluck "Levels=>$levels does not match pngs=>$pngs" unless $T;                 # Complain if requested
  $T                                                                            # Return pngs is levels
 }

sub simulate($$%)                                                               # Simulate the action of the L<lgs> on a L<chip> for a given set of inputs until the output value of each L<lg> stabilizes.  Draw the simulated circuit using the timeing information to determine the layout of the gates.
 {my ($chip, $inputs, %options) = @_;                                           # Chip, Hash of input names to values, options
  my $pngs   = $options{pngs} // 0;                                             # Number of png images requested
  my $log = $options{log} // 0;                                                 # Logging level
  @_ >= 2 or confess "Two or more parameters";

  lll "Simulate\n", dump(\%options) if $log;                                    # Log options used

  my $c = merge($chip, %options);                                               # Merge all the sub chips to make one chip with no sub chips
  checkInputs($c, $inputs);                                                     # Confirm that there is an input value for every input to the chip
  my %values = %$inputs;                                                        # The current set of values contains just the inputs at the start of the simulation
  my %changed;                                                                  # Last step on which this gate changed.  We use this to order the gates on layout

  my $T = maxSimulationSteps;                                                   # Maximum steps
  for my $t(0..$T)                                                              # Steps in time
   {my %changes = simulationStep $c, \%values;                                  # Changes made

    if (!keys %changes)                                                         # Keep going until nothing changes
     {my $mask;                                                                 # Create mask from simulation if requested
      if ($options{svg})                                                        # Layout the gates
       {$mask = drawMask $c, values=>\%values, changed=>\%changed,
          steps=>$t, %options;
       }

      my ($area, $height, $length, $levels, $width) = sub                       # Details of layout if known
       {return (undef) x 4 unless $mask && ref($mask);                          # Svg contains details about dimensions of chip
        my $length = $mask->wiring->totalLength // 0;                           # Total length of wiring on chip in cells
        my $levels = $mask->wiring->levels      // 0;                           # Number of levels of wiring
        my $width  = $mask->layout->width       // 0;                           # Width of chip in cells
        my $height = $mask->layout->height      // 0;                           # Height of chip in cells
        ($height*$width, $height, $length, $levels, $width);                    # Dimensions of chip
       }->();

      my $s = genHash(__PACKAGE__."::Simulation",                               # Kept going until nothing changed in the simulation
        chip    => $chip,                                                       # Chip being simulated
        changed => \%changed,                                                   # Last time this gate changed
        steps   => $t,                                                          # Number of steps to reach stability
        values  => \%values,                                                    # Values of every output at point of stability
        options => \%options,                                                   # Options used to perform simulation
        length  => $length,                                                     # Total length of wiring on chip in cells
        levels  => $levels,                                                     # Number of levels of wiring
        width   => $width,                                                      # Width of chip in cells
        height  => $height,                                                     # Height of chip in cells
        area    => $area,                                                       # Area of chip
        mask    => $mask,                                                       # Masks for chip if they have been produced
      );
      return $s;                                                                # Finished now that no more changes are occurring
     }

    for my $c(keys %changes)                                                    # Update state of circuit
     {$values{$c} = $changes{$c};
      if ($options{latest})
       {$changed{$c} = $t;                                                      # Latest time we changed this gate
       }
      else
       {$changed{$c} = $t unless defined($changed{$c});                         # Earliest time we changed this gate
       }
     }
   }

  confess "Out of time after $T steps";                                         # Not enough steps available
 }

#-------------------------------------------------------------------------------
# Export
#-------------------------------------------------------------------------------

use Exporter qw(import);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# containingFolder

@ISA          = qw(Exporter);
@EXPORT       = qw();
@EXPORT_OK    = qw(connectBits connectWords n nn setBits setWords);
%EXPORT_TAGS = (all=>[@EXPORT, @EXPORT_OK]);

#svg https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/svg

=pod

=encoding utf-8

=for html <p><a href="https://github.com/philiprbrenan/SiliconChip"><img src="https://github.com/philiprbrenan/SiliconChip/workflows/Test/badge.svg"></a>

=head1 Name

Silicon::Chip - Design a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> by combining L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> and sub L<chips|https://en.wikipedia.org/wiki/Integrated_circuit>.

=head1 Synopsis

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

=head2 Gate level diagram:

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals.png">

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals_1.png">

=head2 Other examples

Other circuit diagrams can be seen in folder: L<lib/Silicon/svg|https://github.com/philiprbrenan/SiliconChip/tree/main/lib/Silicon/svg>

=head1 Description

Design a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> by combining L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> and sub L<chips|https://en.wikipedia.org/wiki/Integrated_circuit>.


Version 20240331.


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 Construct

Construct a L<Silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> using standard L<logic gates|https://en.wikipedia.org/wiki/Logic_gate>, components and sub chips combined via buses.

=head2 newChip (%options)

Create a new L<chip|https://en.wikipedia.org/wiki/Integrated_circuit>.

     Parameter  Description
  1  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/oneZero.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/oneZero_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/and.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/and_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals_1.png">
  

=head2 gate($chip, $type, $output, $input1, $input2, %options)

A L<logic gate|https://en.wikipedia.org/wiki/Logic_gate> chosen from B<possibleTypes>.  The gate type can be used as a method name, so B<-E<gt>gate("and",> can be reduced to B<-E<gt>and(>.

     Parameter  Description
  1  $chip      Chip
  2  $type      Gate type
  3  $output    Output name
  4  $input1    Input from another gate
  5  $input2    Input from another gate
  6  %options   Options

B<Example:>


  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOr.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOr_1.png">
  

=head2 Buses

A bus is an array of bits or an array of arrays of bits

=head3 Bits

An array of bits that can be manipulated via one name.

=head4 setSizeBits ($chip, $name, $bits, %options)

Set the size of a bits bus.

     Parameter  Description
  1  $chip      Chip
  2  $name      Bits bus name
  3  $bits      Options
  4  %options

B<Example:>


  if (1)                                                                           
   {my $c = newChip();
  
    $c->setSizeBits ('i', 2);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    $c->setSizeWords('j', 3, 2);
    is_deeply($c->sizeBits,  {i => 2, j_1 => 2, j_2 => 2, j_3 => 2});
    is_deeply($c->sizeWords, {j => [3, 2]});
   }
  

=head4 bits($chip, $name, $bits, $value, %options)

Create a bus set to a specified number.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $bits      Width in bits of bus
  4  $value     Value of bus
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/bits.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/bits_1.png">
  

=head4 inputBits   ($chip, $name, $bits, %options)

Create an B<input> bus made of bits.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $bits      Width in bits of bus
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not_1.png">
  

=head4 outputBits  ($chip, $name, $input, %options)

Create an B<output> bus made of bits.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
  

=head4 notBits ($chip, $name, $input, %options)

Create a B<not> bus made of bits.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not_1.png">
  

=head4 andBits ($chip, $name, $input, %options)

B<and> a bus made of bits.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_2.png">
  

=head4 nandBits($chip, $name, $input, %options)

B<nand> a bus made of bits.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_2.png">
  

=head4 orBits  ($chip, $name, $input, %options)

B<or> a bus made of bits.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Options
  4  %options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_2.png">
  

=head4 norBits ($chip, $name, $input, %options)

B<nor> a bus made of bits.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Options
  4  %options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrBits_2.png">
  

=head3 Words

An array of arrays of bits that can be manipulated via one name.

=head4 setSizeWords($chip, $name, $words, $bits, %options)

Set the size of a bits bus.

     Parameter  Description
  1  $chip      Chip
  2  $name      Bits bus name
  3  $words     Words
  4  $bits      Bits per word
  5  %options   Options

B<Example:>


  if (1)                                                                           
   {my $c = newChip();
    $c->setSizeBits ('i', 2);
  
    $c->setSizeWords('j', 3, 2);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    is_deeply($c->sizeBits,  {i => 2, j_1 => 2, j_2 => 2, j_3 => 2});
    is_deeply($c->sizeWords, {j => [3, 2]});
   }
  

=head4 words   ($chip, $name, $bits, @values)

Create a word bus set to specified numbers.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $bits      Width in bits of each word
  4  @values    Values of words

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words_1.png">
  

=head4 inputWords  ($chip, $name, $words, $bits, %options)

Create an B<input> bus made of words.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $words     Width in words of bus
  4  $bits      Width in bits of each word on bus
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
  

=head4 outputWords ($chip, $name, $input, %options)

Create an B<output> bus made of words.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
  

=head4 notWords($chip, $name, $input, %options)

Create a B<not> bus made of words.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
  

=head4 andWords($chip, $name, $input, %options)

B<and> a bus made of words to produce a single word.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
  

=head4 andWordsX   ($chip, $name, $input, %options)

B<and> a bus made of words by and-ing the corresponding bits in each word to make a single word.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
  

=head4 orWords ($chip, $name, $input, %options)

B<or> a bus made of words to produce a single word.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
  

=head4 orWordsX($chip, $name, $input, %options)

B<or> a bus made of words by or-ing the corresponding bits in each word to make a single word.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of bus
  3  $input     Name of inputs
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/andOrWords_1.png">
  

=head2 Connect

Connect input buses to other buses.

=head3 connectInput($chip, $in, $to, %options)

Connect a previously defined input gate to the output of another gate on the same chip. This allows us to define a set of gates on the chip without having to know, first, all the names of the gates that will provide input to these gates.

     Parameter  Description
  1  $chip      Chip
  2  $in        Input gate
  3  $to        Gate to connect input gate to
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInput.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInput_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words_1.png">
  

=head3 connectInputBits($chip, $in, $to, %options)

Connect a previously defined input bit bus to another bit bus provided the two buses have the same size.

     Parameter  Description
  1  $chip      Chip
  2  $in        Input gate
  3  $to        Gate to connect input gate to
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInputBits.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInputBits_1.png">
  

=head3 connectInputWords   ($chip, $in, $to, %options)

Connect a previously defined input word bus to another word bus provided the two buses have the same size.

     Parameter  Description
  1  $chip      Chip
  2  $in        Input gate
  3  $to        Gate to connect input gate to
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInputWords.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInputWords_1.png">
  

=head2 Install

Install a chip within a chip as a sub chip.

=head3 install ($chip, $subChip, $inputs, $outputs, %options)

Install a L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> within another L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> specifying the connections between the inner and outer L<chip|https://en.wikipedia.org/wiki/Integrated_circuit>.  The same L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> can be installed multiple times as each L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> description is read only.

     Parameter  Description
  1  $chip      Outer chip
  2  $subChip   Inner chip
  3  $inputs    Inputs of inner chip to to outputs of outer chip
  4  $outputs   Outputs of inner chip to inputs of outer chip
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notb1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notb1_1.png">
  

=head1 Visualize

Visualize the L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> in various ways.

=head2 print   ($chip, %options)

Dump the L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> present on a L<chip|https://en.wikipedia.org/wiki/Integrated_circuit>.

     Parameter  Description
  1  $chip      Chip
  2  %options   Gates

B<Example:>


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
  

=head2 Silicon::Chip::Simulation::print($sim, %options)

Print simulation results as text.

     Parameter  Description
  1  $sim       Simulation
  2  %options   Options

B<Example:>


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
  

=head2 GDS2

Graphic Design System Layout for a chip which can be visualized using KLayout.

=head1 Basic Circuits

Some well known basic circuits.

=head2 n   ($c, $i)

Gate name from single index.

     Parameter  Description
  1  $c         Gate name
  2  $i         Bit number

B<Example:>


  if (1)                                                                           
  
   {is_deeply( n(a,1),   "a_1");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    is_deeply(nn(a,1,2), "a_1_2");
   }
  

=head2 nn  ($c, $i, $j)

Gate name from double index.

     Parameter  Description
  1  $c         Gate name
  2  $i         Word number
  3  $j         Bit number

B<Example:>


  if (1)                                                                           
   {is_deeply( n(a,1),   "a_1");
  
    is_deeply(nn(a,1,2), "a_1_2");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

   }
  

=head2 Comparisons

Compare unsigned binary integers of specified bit widths.

=head3 compareEq   ($chip, $output, $a, $b, %options)

Compare two unsigned binary integers of a specified width returning B<1> if they are equal else B<0>.

     Parameter  Description
  1  $chip      Chip
  2  $output    Name of component also the output bus
  3  $a         First integer
  4  $b         Second integer
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareEq.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareEq_1.png">
  

=head3 compareGt   ($chip, $output, $a, $b, %options)

Compare two unsigned binary integers and return B<1> if the first integer is more than B<b> else B<0>.

     Parameter  Description
  1  $chip      Chip
  2  $output    Name of component also the output bus
  3  $a         First integer
  4  $b         Second integer
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareGt.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareGt_1.png">
  

=head3 compareLt   ($chip, $output, $a, $b, %options)

Compare two unsigned binary integers B<a>, B<b> of a specified width. Output B<out> is B<1> if B<a> is less than B<b> else B<0>.

     Parameter  Description
  1  $chip      Chip
  2  $output    Name of component also the output bus
  3  $a         First integer
  4  $b         Second integer
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareLt.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/CompareLt_1.png">
  

=head3 chooseFromTwoWords  ($chip, $output, $a, $b, $choose, %options)

Choose one of two words based on a bit.  The first word is chosen if the bit is B<0> otherwise the second word is chosen.

     Parameter  Description
  1  $chip      Chip
  2  $output    Name of component also the chosen word
  3  $a         The first word
  4  $b         The second word
  5  $choose    The choosing bit
  6  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/chooseFromTwoWords.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/chooseFromTwoWords_1.png">
  

=head3 enableWord  ($chip, $output, $a, $enable, %options)

Output a word or zeros depending on a choice bit.  The first word is chosen if the choice bit is B<1> otherwise all zeroes are chosen.

     Parameter  Description
  1  $chip      Chip
  2  $output    Name of component also the chosen word
  3  $a         The first word
  4  $enable    The second word
  5  %options   The choosing bit

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/enableWord.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/enableWord_1.png">
  

=head2 Masks

Point masks and monotone masks. A point mask has a single B<1> in a sea of B<0>s as in B<00100>.  A monotone mask has zero or more B<0>s followed by all B<1>s as in: B<00111>.

=head3 pointMaskToInteger  ($chip, $output, $input, %options)

Convert a mask B<i> known to have at most a single bit on - also known as a B<point mask> - to an output number B<a> representing the location in the mask of the bit set to B<1>. If no such bit exists in the point mask then output number B<a> is B<0>.

     Parameter  Description
  1  $chip      Chip
  2  $output    Output name
  3  $input     Input mask
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/pointMaskToInteger.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/pointMaskToInteger_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/pointMaskToInteger_2.png">
  

=head3 integerToPointMask  ($chip, $output, $input, %options)

Convert an integer B<i> of specified width to a point mask B<m>. If the input integer is B<0> then the mask is all zeroes as well.

     Parameter  Description
  1  $chip      Chip
  2  $output    Output name
  3  $input     Input mask
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/integerToPointMask.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/integerToPointMask_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/integerToPointMask_2.png">
  

=head3 monotoneMaskToInteger   ($chip, $output, $input, %options)

Convert a monotone mask B<i> to an output number B<r> representing the location in the mask of the bit set to B<1>. If no such bit exists in the point then output in B<r> is B<0>.

     Parameter  Description
  1  $chip      Chip
  2  $output    Output name
  3  $input     Input mask
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToInteger.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToInteger_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToInteger_2.png">
  

=head3 monotoneMaskToPointMask ($chip, $output, $input, %options)

Convert a monotone mask B<i> to a point mask B<o> representing the location in the mask of the first bit set to B<1>. If the monotone mask is all B<0>s then point mask is too.

     Parameter  Description
  1  $chip      Chip
  2  $output    Output name
  3  $input     Input mask
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToPointMask.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/monotoneMaskToPointMask_1.png">
  

=head3 integerToMonotoneMask   ($chip, $output, $input, %options)

Convert an integer B<i> of specified width to a monotone mask B<m>. If the input integer is B<0> then the mask is all zeroes.  Otherwise the mask has B<i-1> leading zeroes followed by all ones thereafter.

     Parameter  Description
  1  $chip      Chip
  2  $output    Output name
  3  $input     Input mask
  4  %options   Options

B<Example:>


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
  

=head3 chooseWordUnderMask ($chip, $output, $input, $mask, %options)

Choose one of a specified number of words B<w>, each of a specified width, using a point mask B<m> placing the selected word in B<o>.  If no word is selected then B<o> will be zero.

     Parameter  Description
  1  $chip      Chip
  2  $output    Output
  3  $input     Inputs
  4  $mask      Mask
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_2.png">
  

=head3 findWord($chip, $output, $key, $words, %options)

Choose one of a specified number of words B<w>, each of a specified width, using a key B<k>.  Return a point mask B<o> indicating the locations of the key if found or or a mask equal to all zeroes if the key is not present.

     Parameter  Description
  1  $chip      Chip
  2  $output    Found point mask
  3  $key       Key
  4  $words     Words to search
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/findWord.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/findWord_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/findWord_2.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/findWord_3.png">
  

=head1 Simulate

Simulate the behavior of the L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> given a set of values on its input gates.

=head2 setBits ($chip, $name, $value, %options)

Set an array of input gates to a number prior to running a simulation.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of input gates
  3  $value     Number to set to
  4  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/gt.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/gt_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_2.png">
  

=head2 setWords($chip, $name, @values)

Set an array of arrays of gates to an array of numbers prior to running a simulation.

     Parameter  Description
  1  $chip      Chip
  2  $name      Name of input gates
  3  @values    Number of bits in each array element

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/choose_2.png">
  

=head2 connectBits ($oc, $o, $ic, $i, %options)

Create a connection list connecting a set of output bits on the one chip to a set of input bits on another chip.

     Parameter  Description
  1  $oc        First chip
  2  $o         Name of gates on first chip
  3  $ic        Second chip
  4  $i         Names of gates on second chip
  5  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notb1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notb1_1.png">
  

=head2 connectWords($oc, $o, $ic, $i, $words, $bits, %options)

Create a connection list connecting a set of words on the outer chip to a set of words on the inner chip.

     Parameter  Description
  1  $oc        First chip
  2  $o         Name of gates on first chip
  3  $ic        Second chip
  4  $i         Names of gates on second chip
  5  $words     Number of words to connect
  6  $bits      Options
  7  %options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notw1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/notw1_1.png">
  

=head2 Silicon::Chip::Simulation::value($simulation, $name, %options)

Get the value of a gate as seen in a simulation.

     Parameter    Description
  1  $simulation  Chip
  2  $name        Gate
  3  %options     Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInput.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/connectInput_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words_1.png">
  

=head2 Silicon::Chip::Simulation::bInt ($simulation, $output, %options)

Represent the state of bits in the simulation results as an unsigned binary integer.

     Parameter    Description
  1  $simulation  Chip
  2  $output      Name of gates on bus
  3  %options     Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/not_1.png">
  

=head2 Silicon::Chip::Simulation::wInt ($simulation, $output, %options)

Represent the state of words in the simulation results as an array of unsigned binary integer.

     Parameter    Description
  1  $simulation  Chip
  2  $output      Name of gates on bus
  3  %options     Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
  

=head2 Silicon::Chip::Simulation::wordXToInteger   ($simulation, $output, %options)

Represent the state of words in the simulation results as an array of unsigned binary integer.

     Parameter    Description
  1  $simulation  Chip
  2  $output      Name of gates on bus
  3  %options     Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/words2_1.png">
  

=head2 Silicon::Chip::Simulation::checkLevelsMatch ($simulation, %options)

Check that the specified number of levels matches that specified by the pngs parameter.  The pngs paramneter tells us howmany drawings to make - one per level - ideally this should match the actual number of levels.

     Parameter    Description
  1  $simulation  Simulation
  2  %options     Options

B<Example:>


  if (1)                                                                          
   {my $N = 2;
    my $c = Silicon::Chip::newChip;
    $c->input (qw(  i));
    $c->not   (qw(n i));
    $c->output(qw(o n));
    my $s = $c->simulate({i=>1}, svg=>q(gdsTest), pngs=>1);
    ok($s->checkLevelsMatch);
   }
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/gdsTest.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/gdsTest_1.png">
  

=head2 simulate($chip, $inputs, %options)

Simulate the action of the L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> on a L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> for a given set of inputs until the output value of each L<logic gate|https://en.wikipedia.org/wiki/Logic_gate> stabilizes.  Draw the simulated circuit using the timeing information to determine the layout of the gates.

     Parameter  Description
  1  $chip      Chip
  2  $inputs    Hash of input names to values
  3  %options   Options

B<Example:>


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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/Equals_1.png">
  
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
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/square1.png">
  

=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/png/square1_1.png">
  


=head1 Hash Definitions




=head2 Silicon::Chip Definition


Kept going until nothing changed in the simulation




=head3 Output fields


=head4 Gate

Definition of gate. Capital G because of a slight default in L<Data::Table::Text::updateDocumentation> that reports a duplicate attribute if we use lowercase g.

=head4 area

Area of chip

=head4 bottomUp

Normally the gates are laid out top down but sometimes it is better to lay them out bottom up

=head4 changeStep

True if we are stepping from one change level to the next

=head4 changed

Last time this gate changed

=head4 chip

Chip being simulated

=head4 expand

Expand gates so that they never have more than two inputs

=head4 fibers

Fibers after collapse

=head4 gates

Gates in chip

=head4 h

Height of gate

=head4 height

Height of chip in cells

=head4 inPlay

Squares in play for collapsing

=head4 inputs

Outputs of outer chip to inputs of inner chip

=head4 installs

Chips installed within the chip

=head4 io

Whether an input/output gate or not

=head4 layout

Layout

=head4 length

Total length of wiring on chip in cells

=head4 levels

Number of levels of wiring

=head4 mask

Masks for chip if they have been produced

=head4 name

Name assigned to gate - or a number if no name was specified

=head4 options

Options used to perform simulation

=head4 output

Output pins as an array of pin names.  The first pin name is used as the name of the gate unless an overriding name=>option has been supplied. Output gate names are unique across the chip.  When a sub chip is installed we rename the copied gates to maintain this invariant.

=head4 outputs

Outputs of inner chip to inputs of outer chip

=head4 positions

Positions array

=head4 positionsArray

Position array

=head4 positionsHash

Position hash

=head4 seq

Sequence number for this gate

=head4 sizeBits

Sizes of bit buses

=head4 sizeWords

Sizes of word buses

=head4 steps

Number of steps to reach stability

=head4 thickness

Width of the thickest fiber bundle

=head4 title

Title if known

=head4 type

Gate type

=head4 values

Values of every output at point of stability

=head4 w

Width of gate

=head4 width

Width of chip in cells

=head4 wiring

Wiring

=head4 x

X position of left upper corner of gate

=head4 y

Y position of left upper corner of gate



=head1 Private Methods

=head2 AUTOLOAD($chip, @options)

Autoload by L<logic gate|https://en.wikipedia.org/wiki/Logic_gate> name to provide a more readable way to specify the L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> on a L<chip|https://en.wikipedia.org/wiki/Integrated_circuit>.

     Parameter  Description
  1  $chip      Chip
  2  @options   Options

=head2 Silicon::Chip::LayoutLinear::draw   ($layout, %options)

Draw a mask for the gates.

     Parameter  Description
  1  $layout    Layout
  2  %options   Options

=head2 gds2($chip, $layout, $wiring, %options)

Draw the chip using GDS2

     Parameter  Description
  1  $chip      Chip
  2  $layout    Layout
  3  $wiring    Wiring
  4  %options   Options


=head1 Index


1 L<andBits|/andBits> - B<and> a bus made of bits.

2 L<andWords|/andWords> - B<and> a bus made of words to produce a single word.

3 L<andWordsX|/andWordsX> - B<and> a bus made of words by and-ing the corresponding bits in each word to make a single word.

4 L<AUTOLOAD|/AUTOLOAD> - Autoload by L<logic gate|https://en.wikipedia.org/wiki/Logic_gate> name to provide a more readable way to specify the L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> on a L<chip|https://en.wikipedia.org/wiki/Integrated_circuit>.

5 L<bits|/bits> - Create a bus set to a specified number.

6 L<chooseFromTwoWords|/chooseFromTwoWords> - Choose one of two words based on a bit.

7 L<chooseWordUnderMask|/chooseWordUnderMask> - Choose one of a specified number of words B<w>, each of a specified width, using a point mask B<m> placing the selected word in B<o>.

8 L<compareEq|/compareEq> - Compare two unsigned binary integers of a specified width returning B<1> if they are equal else B<0>.

9 L<compareGt|/compareGt> - Compare two unsigned binary integers and return B<1> if the first integer is more than B<b> else B<0>.

10 L<compareLt|/compareLt> - Compare two unsigned binary integers B<a>, B<b> of a specified width.

11 L<connectBits|/connectBits> - Create a connection list connecting a set of output bits on the one chip to a set of input bits on another chip.

12 L<connectInput|/connectInput> - Connect a previously defined input gate to the output of another gate on the same chip.

13 L<connectInputBits|/connectInputBits> - Connect a previously defined input bit bus to another bit bus provided the two buses have the same size.

14 L<connectInputWords|/connectInputWords> - Connect a previously defined input word bus to another word bus provided the two buses have the same size.

15 L<connectWords|/connectWords> - Create a connection list connecting a set of words on the outer chip to a set of words on the inner chip.

16 L<enableWord|/enableWord> - Output a word or zeros depending on a choice bit.

17 L<findWord|/findWord> - Choose one of a specified number of words B<w>, each of a specified width, using a key B<k>.

18 L<gate|/gate> - A L<logic gate|https://en.wikipedia.org/wiki/Logic_gate> chosen from B<possibleTypes>.

19 L<gds2|/gds2> - Draw the chip using GDS2

20 L<inputBits|/inputBits> - Create an B<input> bus made of bits.

21 L<inputWords|/inputWords> - Create an B<input> bus made of words.

22 L<install|/install> - Install a L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> within another L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> specifying the connections between the inner and outer L<chip|https://en.wikipedia.org/wiki/Integrated_circuit>.

23 L<integerToMonotoneMask|/integerToMonotoneMask> - Convert an integer B<i> of specified width to a monotone mask B<m>.

24 L<integerToPointMask|/integerToPointMask> - Convert an integer B<i> of specified width to a point mask B<m>.

25 L<monotoneMaskToInteger|/monotoneMaskToInteger> - Convert a monotone mask B<i> to an output number B<r> representing the location in the mask of the bit set to B<1>.

26 L<monotoneMaskToPointMask|/monotoneMaskToPointMask> - Convert a monotone mask B<i> to a point mask B<o> representing the location in the mask of the first bit set to B<1>.

27 L<n|/n> - Gate name from single index.

28 L<nandBits|/nandBits> - B<nand> a bus made of bits.

29 L<newChip|/newChip> - Create a new L<chip|https://en.wikipedia.org/wiki/Integrated_circuit>.

30 L<nn|/nn> - Gate name from double index.

31 L<norBits|/norBits> - B<nor> a bus made of bits.

32 L<notBits|/notBits> - Create a B<not> bus made of bits.

33 L<notWords|/notWords> - Create a B<not> bus made of words.

34 L<orBits|/orBits> - B<or> a bus made of bits.

35 L<orWords|/orWords> - B<or> a bus made of words to produce a single word.

36 L<orWordsX|/orWordsX> - B<or> a bus made of words by or-ing the corresponding bits in each word to make a single word.

37 L<outputBits|/outputBits> - Create an B<output> bus made of bits.

38 L<outputWords|/outputWords> - Create an B<output> bus made of words.

39 L<pointMaskToInteger|/pointMaskToInteger> - Convert a mask B<i> known to have at most a single bit on - also known as a B<point mask> - to an output number B<a> representing the location in the mask of the bit set to B<1>.

40 L<print|/print> - Dump the L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> present on a L<chip|https://en.wikipedia.org/wiki/Integrated_circuit>.

41 L<setBits|/setBits> - Set an array of input gates to a number prior to running a simulation.

42 L<setSizeBits|/setSizeBits> - Set the size of a bits bus.

43 L<setSizeWords|/setSizeWords> - Set the size of a bits bus.

44 L<setWords|/setWords> - Set an array of arrays of gates to an array of numbers prior to running a simulation.

45 L<Silicon::Chip::LayoutLinear::draw|/Silicon::Chip::LayoutLinear::draw> - Draw a mask for the gates.

46 L<Silicon::Chip::Simulation::bInt|/Silicon::Chip::Simulation::bInt> - Represent the state of bits in the simulation results as an unsigned binary integer.

47 L<Silicon::Chip::Simulation::checkLevelsMatch|/Silicon::Chip::Simulation::checkLevelsMatch> - Check that the specified number of levels matches that specified by the pngs parameter.

48 L<Silicon::Chip::Simulation::print|/Silicon::Chip::Simulation::print> - Print simulation results as text.

49 L<Silicon::Chip::Simulation::value|/Silicon::Chip::Simulation::value> - Get the value of a gate as seen in a simulation.

50 L<Silicon::Chip::Simulation::wInt|/Silicon::Chip::Simulation::wInt> - Represent the state of words in the simulation results as an array of unsigned binary integer.

51 L<Silicon::Chip::Simulation::wordXToInteger|/Silicon::Chip::Simulation::wordXToInteger> - Represent the state of words in the simulation results as an array of unsigned binary integer.

52 L<simulate|/simulate> - Simulate the action of the L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> on a L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> for a given set of inputs until the output value of each L<logic gate|https://en.wikipedia.org/wiki/Logic_gate> stabilizes.

53 L<words|/words> - Create a word bus set to specified numbers.

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Silicon::Chip

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
clearFolder(q(svg), 399);                                                       # Clear the output svg folder
clearFolder(q(gds), 399);                                                       # GDS2 files
my sub gitHub {!-e q(/home/phil/)}                                              # On Github

my $start = time;
eval "use Test::More";
eval "Test::More->builder->output('/dev/null')" unless gitHub;
eval {goto latest}                              unless gitHub;

#svg https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChip/lib/Silicon/Chip/svg/


if (1)                                                                          #Tdistance
 {is_deeply(distance(2,1,  1, 2), 2);
 }

if (1)                                                                          #Tn #Tnn
 {is_deeply( n(a,1),   "a_1");
  is_deeply(nn(a,1,2), "a_1_2");
 }

if (1)                                                                          # Unused output
 {my $c = Silicon::Chip::newChip;
  $c->input( "i1");
  eval {$c->simulate({i1=>1})};
  ok($@ =~ m(Output from gate 'i1' is never used)i);
 }

if (1)                                                                          # Gate already specified
 {my $c = Silicon::Chip::newChip;
        $c->input("i1");
  eval {$c->input("i1")};
  ok($@ =~ m(Gate: 'i1' has already been specified));
 }

#latest:;
if (1)                                                                          # Check all inputs have values
 {my $c = Silicon::Chip::newChip;
  $c->input ("i1");
  $c->input ("i2");
  $c->and   ("and", [qw(i1 i2)]);
  $c->output("o",   q(and));
  eval {$c->simulate({i1=>1, i22=>1})};
  ok($@ =~ m(No input value for input gate: i2)i);
 }

#latest:;
if (1)                                                                          # Check each input to each gate receives output from another gate
 {my $c = Silicon::Chip::newChip;
  $c->input("i1");
  $c->input("i2");
  $c->and  ("and1", [qw(i1 i2)]);
  $c->output( "o", q(an1));
  eval {$c->simulate({i1=>1, i2=>1})};
  ok($@ =~ m(No output driving input 'an1' on 'output' gate 'o')i);
 }

#latest:;
if (1)                                                                          #Tzero
 {my $c = Silicon::Chip::newChip;
  $c->zero  ("z");
  $c->output("o", "z");
  my $s = $c->simulate({}, svg=>q(zero), pngs=>1);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps,      2);
  is_deeply($s->value("o"), 0);
 }

#latest:;
if (1)                                                                          #Tone
 {my $c = Silicon::Chip::newChip;
  $c->one ("o");
  $c->output("O", "o");
  my $s = $c->simulate({}, svg=>q(one), pngs=>1);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps      , 2);
  is_deeply($s->value("O"), 1);
 }

#latest:;
if (1)                                                                          #TnewChip
 {my $c = Silicon::Chip::newChip(expand=>1);
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

#latest:;
if (1)                                                                          #Tbits
 {my $N = 4;
  for my $i(0..2**$N-1)
   {my $c = Silicon::Chip::newChip;
    $c->bits      ("c", $N, $i);
    $c->outputBits("o", "c");
    my @T = $i == 3 ? (svg=>q(bits), pngs=>1) : ();
    my $s = $c->simulate({}, @T);
    ok($s->checkLevelsMatch) if @T;
    is_deeply($s->steps, 2);
    is_deeply($s->bInt("o"), $i);
   }
 }

#latest:;
if (1)                                                                          #TnewChip # Single AND gate
 {my $c = Silicon::Chip::newChip;
  $c->input ("i1");
  $c->input ("i2");
  $c->and   ("and1", [qw(i1 i2)]);
  $c->output("o", "and1");
  my $s = $c->simulate({i1=>1, i2=>1}, svg=>q(and), pngs=>1);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps         , 2);
  is_deeply($s->value("and1") , 1);
 }

#latest:;
if (1)                                                                          #TSilicon::Chip::Simulation::print #Tprint
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

#latest:;
if (1)                                                                          # Three AND gates in a tree
 {my $c = Silicon::Chip::newChip;
  $c->input( "i11");
  $c->input( "i12");
  $c->and(    "and1", [qw(i11 i12)]);
  $c->input( "i21");
  $c->input( "i22");
  $c->and(    "and2", [qw(i21   i22)]);
  $c->and(    "and",  [qw(and1 and2)]);
  $c->output( "o", "and");
  my $s = $c->simulate({i11=>1, i12=>1, i21=>1, i22=>1}, svg=>q(and3), pngs=>1);
  ok($s->checkLevelsMatch);

  is_deeply($s->steps        , 3);
  is_deeply($s->value("and") , 1);
  $s = $c->simulate({i11=>1, i12=>0, i21=>1, i22=>1});

  is_deeply($s->steps        , 3);
  is_deeply($s->value("and") , 0);
 }

#latest:;
if (1)                                                                          #Tgate # Two AND gates driving an OR gate
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

#latest:;
if (1)                                                                          #Tsimulate # 4 bit equal #TnewChip
 {my $B = 4;                                                                    # Number of bits

  my $c = Silicon::Chip::newChip(title=><<"END");                               # Create chip
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

#latest:;
if (1)                                                                          #TsetBits # Compare two 4 bit unsigned integers 'a' > 'b' - the pins used to input 'a' must be alphabetically less than those used for 'b'
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

  my %a = $c->setBits('a', 0);                                                  # Number a
  my %b = $c->setBits('b', 0);                                                  # Number b

  my $s = $c->simulate({%a, %b, n(a,2)=>1, n(b,2)=>1}, svg=>q(gt), pngs=>1, gsx=>2, gsy=>2, spaceDx=>1, borderDy=>1, minHeight=>18, newChange=>1); # Compare two numbers a, b to see if a > b
  ok($s->checkLevelsMatch);
  is_deeply($s->value("out"), 0);
  is_deeply($s->levels,    1);
  is_deeply($s->length, 1832);

  my $t = $c->simulate({%a, %b, n(a,2)=>1});
  is_deeply($t->value("out"), 1);
 }

#latest:;
if (1)                                                                           #TcompareEq # Compare unsigned integers
 {my $B = 2;

  my $c = Silicon::Chip::newChip(title=><<"END");
$B Bit Compare Equal
END
  $c->inputBits($_, $B) for qw(a b);                                            # First and second numbers
  $c->compareEq(qw(o a b));                                                     # Compare equals
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

#latest:;
if (gitHub)                                                                     #TcompareGt # Compare 8 bit unsigned integers 'a' > 'b' - the pins used to input 'a' must be alphabetically less than those used for 'b'
 {my $B = 3;
  my $c = Silicon::Chip::newChip(title=><<END);
$B Bit Compare more than
END
  $c->inputBits($_, $B) for qw(a b);                                            # First and second numbers
  $c->compareGt(qw(o a b));                                                     # Compare more than
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

#latest:;
if (1)                                                                          #TcompareLt # Compare 8 bit unsigned integers 'a' < 'b' - the pins used to input 'a' must be alphabetically less than those used for 'b'
 {my $B = 3;
  my $c = Silicon::Chip::newChip(title=><<"END");
$B Bit Compare Less Than
END
  $c->inputBits($_, $B) for qw(a b);                                            # First and second numbers
  $c->compareLt(qw(o a b));                                                     # Compare less than
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

#latest:;
if (1)                                                                          # Masked multiplexer: copy B bit word selected by mask from W possible locations
 {my $B = 4; my $W = 4;
  my $c = newChip;
  for my $w(1..$W)                                                              # Input words
   {$c->input("s$w");                                                           # Selection mask
    for my $b(1..$B)                                                            # Bits of input word
     {$c->input("i$w$b");
      $c->and(  "s$w$b", ["i$w$b", "s$w"]);
     }
   }
  for my $b(1..$B)                                                              # Or selected bits together to make output
   {$c->or    ("c$b", [map {"s$b$_"} 1..$W]);                                   # Combine the selected bits to make a word
    $c->output("o$b", "c$b");                                                   # Output the word selected
   }
  my $s = $c->simulate(
   {s1 =>0, s2 =>0, s3 =>1, s4 =>0,                                             # Input switch
    i11=>0, i12=>0, i13=>0, i14=>1,                                             # Inputs
    i21=>0, i22=>0, i23=>1, i24=>0,
    i31=>0, i32=>1, i33=>0, i34=>0,
    i41=>1, i42=>0, i43=>0, i44=>0}, svg=>q(maskedMultiplexor), pngs=>2,
    newChange=>1, borderDy=>4, placeFirst=>1);
  ok($s->checkLevelsMatch);

  is_deeply([@{$s->values}{qw(o1 o2 o3 o4)}], [qw(0 0 1 0)]);                   # Number selected by mask
  is_deeply($s->steps,     6);
  is_deeply($s->length, 4944);
  #say STDERR $s->mask->wiring->printCode;
 }

#latest:;
if (1)                                                                          # Rename a gate
 {my $i = newChip(name=>"inner");
          $i->input ("i");
  my $n = $i->not   ("n",  "i");
          $i->name("io", "n");

  my $ci = cloneGate $i, $n;
  renameGate $i, $ci, "aaa";
  is_deeply($ci->inputs,   { n => "i" });
  is_deeply($ci->name,  "(aaa n)");
  is_deeply($ci->io, 0);
 }

#latest:;
if (1)                                                                          #Tinstall #TconnectBits # Install one chip inside another chip, specifically one chip that performs NOT is installed once to flip a value
 {my $i = newChip(name=>"not");
     $i-> inputBits('i',     1);
     $i->   notBits(qw(n i));
     $i->outputBits(qw(o n));

  my $o = newChip(name=>"outer");
     $o->inputBits('i', 1); $o->outputBits(qw(n i));
     $o->inputBits('I', 1); $o->outputBits(qw(N I));

  my %i = connectBits($i, 'i', $o, 'n');
  my %o = connectBits($i, 'o', $o, 'I');
  $o->install($i, {%i}, {%o});
  my %d = $o->setBits('i', 1);
  my $s = $o->simulate({%d}, svg=>q(notb1), pngs=>1);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps,  2);
  is_deeply($s->values, {"(not 1 n_1)"=>0, "i_1"=>1, "N_1"=>0 });
 }

#latest:;
if (1)                                                                          #TconnectWords # Install one chip inside another chip, specifically one chip that performs NOT is installed three times sequentially to flip a value
 {my $i = newChip(name=>"not");
     $i-> inputWords('i', 1, 1);
     $i->   notWords(qw(n i));
     $i->outputWords(qw(o n));

  my $o = newChip(name=>"outer");
     $o->inputWords('i', 1, 1); $o->output(nn('n', 1, 1), nn('i', 1, 1));
     $o->inputWords('I', 1, 1); $o->output(nn('N', 1, 1), nn('I', 1, 1));

  my %i = connectWords($i, 'i', $o, 'n', 1, 1);
  my %o = connectWords($i, 'o', $o, 'I', 1, 1);
  $o->install($i, {%i}, {%o});
  my %d = $o->setWords('i', 1);
  my $s = $o->simulate({%d}, svg=>q(notw1), pngs=>1);
  ok($s->checkLevelsMatch);

  is_deeply($s->steps,  2);
  is_deeply($s->values, { "(not 1 n_1_1)" => 0, "i_1_1" => 1, "N_1_1" => 0 });
 }

#latest:;
if (1)
 {my $i = newChip(name=>"inner");
     $i->input ("Ii");
     $i->not   ("In", "Ii");
     $i->output( "Io", "In");

  my $o = newChip(name=>"outer");
     $o->input ("Oi1");
     $o->output("Oo1", "Oi1");
     $o->input ("Oi2");
     $o->output("Oo2", "Oi2");
     $o->input ("Oi3");
     $o->output("Oo3", "Oi3");
     $o->input ("Oi4");
     $o->output("Oo",  "Oi4");

  $o->install($i, {Ii=>"Oo1"}, {Io=>"Oi2"});
  $o->install($i, {Ii=>"Oo2"}, {Io=>"Oi3"});
  $o->install($i, {Ii=>"Oo3"}, {Io=>"Oi4"});

  my $s = $o->simulate({Oi1=>1}, svg=>q(not3), pngs=>1);
  ok($s->checkLevelsMatch);
  is_deeply($s->value("Oo"), 0);
  is_deeply($s->steps,       4);

  my $t = $o->simulate({Oi1=>0});
  is_deeply($t->value("Oo"), 1);
  is_deeply($t->steps,       4);
 }

#latest:;
if (gitHub)                                                                     #TpointMaskToInteger
 {my $B = 4;
  my $N = 2**$B-1;

  my $c = Silicon::Chip::newChip(title=><<"END");
$B bits point mask to integer
END
  $c->inputBits         (qw(    i), $N);                                        # Mask with no more than one bit on
  $c->pointMaskToInteger(qw(o   i));                                            # Convert
  $c->outputBits        (qw(out o));                                            # Mask with no more than one bit on

 for my $i(0..$N)                                                               # Each position of mask
   {my %i = setBits($c, 'i', $i ? 1<<($i-1) : 0);                               # Point in each position with zero representing no position
    my $T = $i == 5;
    my @T = $T ? (svg=>q(pointMaskToInteger), pngs=>2, newChange=>1, gsx=>3, gsy=>3, spaceDx=>2, spaceDy=>2, newChange=>1, borderDy=>4) : ();
    my $s = $c->simulate(\%i, @T);
    ok($s->checkLevelsMatch) if @T;
    is_deeply($s->steps, 6);
    my %o = $s->values->%*;                                                     # Output bits
    my $n = eval join '', '0b', map {$o{n(o,$_)}} reverse 1..$B;                # Output bits as number
    is_deeply($n, $i);
    is_deeply($s->levels, 2) if $T;
   }
 }

#latest:;
if (gitHub)                                                                     #TintegerToPointMask
 {my $B = 3;
  my $N = 2**$B-1;

  my $c = Silicon::Chip::newChip(title=><<"END");
$B bit integer to $N bit monotone mask.
END
     $c->inputBits         (qw(  i), $B);                                       # Input bus
     $c->integerToPointMask(qw(m i));
     $c->outputBits        (qw(o m));

  for my $i(0..$N)                                                              # Each position of mask
   {my %i = setBits($c, 'i', $i);
    my @T = $i == 5 ? (svg=>q(integerToPointMask), pngs=>2, placeFirst=>1):();
    my $s = $c->simulate(\%i, @T);
    ok($s->checkLevelsMatch) if @T;
    is_deeply($s->steps, 9);

    my $r = $s->bInt('o');                                                      # Mask values
    is_deeply($r, $i ? 1<<($i-1) : 0);                                          # Expected mask
   }
 }

#latest:;
if (gitHub)                                                                     #TmonotoneMaskToInteger
 {my $B = 4;
  my $N = 2**$B-1;

  my $c = Silicon::Chip::newChip(title=><<"END");
$N bit monotone mask to $B bit integer
END
     $c->inputBits            ('i',     $N);
     $c->monotoneMaskToInteger(qw(m i));
     $c->outputBits           (qw(o m));

  for my $i(0..$N-1)                                                            # Each monotone mask
   {my %i = setBits($c, 'i', $i > 0 ? 1<<$i-1 : 0);
    my @T = $i == 5 ? (svg=>q(monotoneMaskToInteger), pngs=>2, placeFirst=>1) : ();
    my $s = $c->simulate(\%i, @T);
    ok($s->checkLevelsMatch) if @T;

    is_deeply($s->steps, 9);
    is_deeply($s->bInt('m'), $i);
   }
 }

#latest:;
if (gitHub)                                                                     #TintegerToMonotoneMask
 {my $B = 4;
  my $N = 2**$B-1;

  my $c = Silicon::Chip::newChip(title=><<"END");
Convert $B bit integer to $N bit monotone mask
END
     $c->inputBits            ('i', $B);                                        # Input gates
     $c->integerToMonotoneMask(qw(m i));
     $c->outputBits           (qw(o m));                                        # Output gates

  for my $i(0..$N)                                                              # Each position of mask
   {my %i = setBits($c, 'i', $i);                                               # The number to convert
    my $s = $c->simulate(\%i);
    is_deeply($s->steps, 19);
    is_deeply($s->bInt('o'), $i > 0 ? ((1<<$N)-1)>>($i-1)<<($i-1) : 0);         # Expected mask
   }
 }

#latest:;
if (1)
 {my $B = 4;
  my $N = 2**$B-1;

  my $c = Silicon::Chip::newChip(title=><<"END");
Convert $B bit integer to $N bit monotone mask
END
     $c->inputBits            ('i', $B);                                        # Input gates
     $c->integerToMonotoneMask(qw(m i));
     $c->outputBits           (qw(o m));                                        # Output gates

  for my $i(2)                                                                  # Each position of mask
   {my %i = setBits($c, 'i', $i);                                               # The number to convert
    my @T = (svg=>q(integerToMontoneMask), pngs=>2, newChange=>1, spaceDx=>4, spaceDy=>4, borderDy=>12, placeFirst=>1);
    my $s = $c->simulate(\%i, @T);
    ok($s->checkLevelsMatch);
    is_deeply($s->steps, 19);
    is_deeply($s->bInt('o'), $i > 0 ? ((1<<$N)-1)>>($i-1)<<($i-1) : 0);         # Expected mask
   }
 }

#latest:;
if (1)                                                                          #TchooseWordUnderMask #TsetBits #TsetWords
 {my $B = 3; my $W = 4;

  my $c = Silicon::Chip::newChip(title=><<"END");
Choose one of $W words of $B bits
END
     $c->inputWords         ('w',       $W, $B);
     $c->inputBits          ('m',       $W);
     $c->chooseWordUnderMask(qw(W w m));
     $c->outputBits         (qw(o W));

  my %i = setWords($c, 'w', 0b000, 0b001, 0b010, 0b0100);
  my %m = setBits ($c, 'm', 1<<2);                                              # Choose the third word

  my $s = $c->simulate({%i, %m}, svg=>q(choose), pngs=>2);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps,  6);
  is_deeply($s->bInt('o'), 0b010);
 }

#latest:;
if (gitHub)                                                                     #TfindWord
 {my $B = 3; my $W = 2**$B-1;

  my $c = Silicon::Chip::newChip(title=><<END);
Search $W words of $B bits
END
     $c->inputBits ('k',       $B);                                             # Search key
     $c->inputWords('w',       2**$B-1, $B);                                    # Words to search
     $c->findWord  (qw(m k w));                                                 # Find the word
     $c->outputBits(qw(M m));                                                   # Output mask

  my %w = setWords($c, 'w', reverse 1..$W);

  for my $k(0..$W)                                                              # Each possible key
   {my %k = setBits($c, 'k', $k);
    my @T = $k == 3 ? (svg=>q(findWord), pngs=>3) : ();
    my $s = $c->simulate({%k, %w}, @T);
    ok($s->checkLevelsMatch) if @T;
    is_deeply($s->steps,  7);
    is_deeply($s->bInt('M'),$k ? 2**($W-$k) : 0);
   }
 }

#latest:;
if (1)                                                                          #TinputBits #ToutputBits #TnotBits #TSilicon::Chip::Simulation::bInt
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

#latest:;                                                                       # Good for wiring testing
if (gitHub)                                                                          #TandBits #TorBits #TnandBits #TnorBits
 {for my $W(2..8)
   {my $c = newChip(expand=>1);
       $c-> inputBits('i', $W);
       $c->   andBits(qw(and  i));
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

#latest:;
if (1)                                                                          #TandWords #TandWordsX #TorWords #TorWordsX #ToutputBits #TnotWords
 {my @B = ((my $W = 4), (my $B = 2));

  my $c = newChip();
     $c->inputWords ('i', @B);
     $c->andWords   (qw(and  i));
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

#latest:;
if (1)                                                                          #TandWords #TorWords #TSilicon::Chip::Simulation::wordXToInteger #TSilicon::Chip::Simulation::wInt  #TinputWords #ToutputWords
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


#latest:;
if (1)
 {my $B = 4;

  my $c = newChip();
     $c->inputBits('i', 4);
     $c->not   (n('n',  1), n('i', 2));  $c->output(n('o',  1), n('n', 1));
     $c->not   (n('n',  2), n('i', 3));  $c->output(n('o',  2), n('n', 2));
     $c->not   (n('n',  3), n('i', 4));  $c->output(n('o',  3), n('n', 3));
     $c->not   (n('n',  4), n('i', 1));  $c->output(n('o',  4), n('n', 4));

  my %a = setBits($c, 'i', 0b0011);

  my $s = $c->simulate({%a}, svg=>q(collapseLeftSimple), pngs=>1, newChange=>1, spaceDy=>4, minHeight=>10);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps, 2);
 }

#latest:;
if (1)                                                                          #TchooseFromTwoWords
 {my $B = 4;

  my $c = newChip();
     $c->inputBits('a', $B);                                                    # First word
     $c->inputBits('b', $B);                                                    # Second word
     $c->input    ('c');                                                        # Chooser
     $c->chooseFromTwoWords(qw(o a b c));                                       # Generate gates
     $c->outputBits('out', 'o');                                                # Result

  my %a = setBits($c, 'a', 0b0011);
  my %b = setBits($c, 'b', 0b1100);

  my $s = $c->simulate({%a, %b, c=>1}, svg=>q(chooseFromTwoWords), pngs=>1, minHeight=>18, spaceDy=>2);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps,  9);
  is_deeply($s->bInt('out'), 0b1100);

  my $t = $c->simulate({%a, %b, c=>0});
  is_deeply($t->steps,               9);
  is_deeply($t->bInt('out'), 0b0011);
 }

#latest:;
if (1)                                                                          #TenableWord
 {my $B = 4;

  my $c = newChip();
     $c->inputBits ('a', $B);                                                   # Word
     $c->input     ('c');                                                       # Choice bit
     $c->enableWord(qw(o a c));                                                 # Generate gates
     $c->outputBits(qw(out o));                                                 # Result

  my %a = setBits($c, 'a', 3);

  my $s = $c->simulate({%a, c=>1}, svg=>q(enableWord), pngs=>1, spaceDy=>1);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps,       4);
  is_deeply($s->bInt('out'), 3);

  my $t = $c->simulate({%a, c=>0});
  is_deeply($t->steps,       4);
  is_deeply($t->bInt('out'), 0);
 }

#latest:;
if (gitHub)                                                                     #TmonotoneMaskToPointMask
 {my $B = 4;

  my $c = newChip();
     $c->inputBits('m', $B);                                                    # Monotone mask
     $c->monotoneMaskToPointMask(qw(o m));                                      # Generate gates
     $c->outputBits('out', 'o');                                                # Point mask

  for my $i(0..$B)
   {my %m = $c->setBits('m', eval '0b'.(1 x $i).('0' x ($B-$i)));
    my @T = $i == 2 ? (svg=>q(monotoneMaskToPointMask), pngs=>1) : ();
    my $s = $c->simulate({%m},  @T);
    ok($s->checkLevelsMatch) if @T;
    is_deeply($s->steps,  3) if @T;
    is_deeply($s->bInt('out'), $i ? (1<<($B-1)) / (1<<($i-1)) : 0);
   }
 }

#latest:;
if (1)                                                                          # Internal input gate  #TconnectInput #TSilicon::Chip::Simulation::value
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

#latest:;
if (1)                                                                          #Twords # Internal input gate  #TconnectInput #TSilicon::Chip::Simulation::value
 {my @n = qw(3 2 1 2 3);
  my $c = newChip();
     $c->words('i', 2, @n);                                                     # Input
     $c->outputWords(qw(o i));                                                  # Output
  my $s = $c->simulate({}, svg=>q(words), pngs=>1, minHeight=>10);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps,  2);
  is_deeply([$s->wInt("i")], [@n]);
 }

#latest:;
if (1)                                                                          #TsetSizeBits #TsetSizeWords
 {my $c = newChip();
  $c->setSizeBits ('i', 2);
  $c->setSizeWords('j', 3, 2);
  is_deeply($c->sizeBits,  {i => 2, j_1 => 2, j_2 => 2, j_3 => 2});
  is_deeply($c->sizeWords, {j => [3, 2]});
 }

#latest:;
if (1)                                                                          #TconnectInputBits
 {my $N = 5; my $B = 5;
  my $c = newChip();
  $c->bits      ('a', $B, $N);
  $c->inputBits ('i', $N);
  $c->outputBits(qw(o i));
  $c->connectInputBits(qw(i a));                                                # The input gates will get squeezed out
  my $s = $c->simulate({}, svg=>q(connectInputBits), pngs=>1, newChange=>1);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps,  2);
  is_deeply($s->levels, 1);
  is_deeply($s->bInt("o"), $N);
 }

#latest:;
if (1)                                                                          #TconnectInputWords
 {my $W = 6; my $B = 5;
  my $c = newChip();
  $c->words      ('a',     $B, 1..$W);
  $c->inputWords ('i', $W, $B);
  $c->outputWords(qw(o i));
  $c->connectInputWords(qw(i a));
  my $s = $c->simulate({}, svg=>q(connectInputWords), pngs=>1, newChange=>1, borderDy=>16);
  ok($s->checkLevelsMatch);
  is_deeply($s->steps, 2);
  is_deeply([$s->wInt("o")], [1..$W]);
 }

#latest:;
if (1)                                                                          # Collapse left
 {my $c = Silicon::Chip::newChip;
  $c->input ('a');
  $c->input (             n('ia', $_)) for 1..8;
  $c->and   ('aa',  [map {n('ia', $_)}     1..8]);
  $c->output('oa', 'aa');
  $c->not   ('n1', 'a'); $c->output('o1', 'n1');
  $c->input (             n('ib', $_)) for 1..8;
  $c->and   ('ab',  [map {n('ib', $_)}     1..8]);
  $c->output('ob', 'ab');
  $c->not   ('n2', 'a'); $c->output('o2', 'n2');
  my %a = map {(n('ia', $_)=>1)} 1..8;
  my %b = map {(n('ib', $_)=>1)} 1..8;
  my $s = $c->simulate({%a, %b, a=>0}, svg=>q(collapseLeft), pngs=>2,
       gsx=>3, gsy=>3, spaceDx=>0, spaceDy=>1, newChange=>1, borderDy=>4);
  ok($s->checkLevelsMatch);
  is_deeply($s->width,    94);
  is_deeply($s->height,   24);
 }

#latest:;
if (1)                                                                          #Tsimulate
 {my $N = 2;
  my $c = Silicon::Chip::newChip;
  $c->input (n('i', $_))                              for 1..$N;
  $c->xor   (n("x", $_),   n('i', $_-1), n('i', $_))  for 2..$N;
  $c->and   ('a',    [map {n('x', $_)}                    2..$N]);
  $c->output('o',  'a');
  my %a = map {(n('i', $_)=> $_ % 2)} 1..$N;
  my $s = $c->simulate({%a}, svg=>q(square1), pngs=>1);
  ok($s->checkLevelsMatch);
 }

#latest:;
if (1)                                                                          #TfanOut
 {my $N = 2;
  my $c = Silicon::Chip::newChip;
  $c->input ('i');
  $c->fanOut(     [qw(f1 f2)], 'i');
  $c->and   ('a', [qw(f1 f2)]);
  $c->output('o',  'a');
  my $s = $c->simulate({i=>1}, svg=>q(fan2), pngs=>1, newChange=>1);
  ok($s->checkLevelsMatch);
  is_deeply($s->value("o"), 1);
 }

#latest:;
if (1)                                                                          #
 {my $N = 2;
  my $c = Silicon::Chip::newChip(expand=>1);
  $c->input ('i');
  $c->continue($_, q(i)) for qw(a b c d);
  $c->and   (      'A',     [qw(a b c d)]);
  $c->output('o',  'A');
  my $s = $c->simulate({i=>1}, svg=>q(addfan2), pngs=>1, spaceDy=>1, newChange=>1, minHeight=>20, gsx=>2, gsy=>2);
  ok($s->checkLevelsMatch);
  is_deeply($s->length, 142);
  is_deeply($s->value("o"), 1);
 }

#latest:;
if (1)                                                                          #TSilicon::Chip::Simulation::checkLevelsMatch
 {my $N = 2;
  my $c = Silicon::Chip::newChip;
  $c->input (qw(  i));
  $c->not   (qw(n i));
  $c->output(qw(o n));
  my $s = $c->simulate({i=>1}, svg=>q(gdsTest), pngs=>1);
  ok($s->checkLevelsMatch);
 }

done_testing();
say STDERR sprintf "Finished in %9.4f seconds", time - $start;
finish: 1;
