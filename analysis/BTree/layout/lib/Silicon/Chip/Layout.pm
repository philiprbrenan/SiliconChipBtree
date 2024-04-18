#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/SvgSimple/lib/ -I/home/phil/perl/cpan/Math-Intersection-Circle-Line/lib
#-------------------------------------------------------------------------------
# Layout the gates of a silicon chip
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
package Silicon::Chip::Layout;
our $VERSION = 20240331;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Math::Intersection::Circle::Line;
use Svg::Simple;

makeDieConfess;

my $debug = 0;                                                                  # Debug if set
sub debugMask {1}                                                               # Adds a grid to the drawing of a bus line

#D1 Construct                                                                   # Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

sub new(%)                                                                      # New gates layout diagram.
 {my (%options) = @_;                                                           # Options
  genHash(__PACKAGE__,                                                          # Gates diagram
    %options,                                                                   # Options
    height => $options{height},                                                 # Optional height of diagram
    width  => $options{width},                                                  # Optional width of diagram
    gates  => [],                                                               # Gates on diagram
   );
 }

sub gate($%)                                                                    # New gate on a gates diagram.
 {my ($D, %options) = @_;                                                       # Diagram, options

  my ($x, $y, $w, $h, $t, $l) = @options{qw(x y w h t l)};
  defined($x) or confess "x";
  defined($y) or confess "y";
  defined($w) or confess "w";
  defined($h) or confess "h";
  defined($t) or confess "t";
  defined($l) or confess "l";

  my $g = genHash(__PACKAGE__,                                                  # Gate
    x => $x,                                                                    # X upper left corner of gate
    y => $y,                                                                    # Y upper left corner of gate
    h => $h,                                                                    # Height of gate
    w => $w,                                                                    # Width of gate
    t => $t,                                                                    # Type of gate
    l => $l,                                                                    # Type of gate
   );

  push $D->gates->@*, $g;                                                       # Append gate to diagram

  $g
 }

#D1 Visualize                                                                   # Visualize the layout of the gates

sub svg($%)                                                                     # Draw the gates
 {my ($D, %options) = @_;                                                       # Diagram, options

  my @defaults = (defaults=>                                                    # Default values
   {stroke_width      => 1,
    font_size         => 1/4,
    opacity           => 3/4,
    text_anchor       => "middle",
    dominant_baseline => "central",
   });

  my $color     =                                                               # Colors of gates
   {q(and)      => "darkRed",
    q(continue) => "chocolate",
    q(fanOut)   => "steelblue",
    q(gt)       => "orangered",
    q(input)    => "green",
    q(lt)       => "teal",
    q(nand)     => "Red",
    q(ngt)      => "orange",
    q(nlt)      => "turquoise",
    q(nor)      => "Blue",
    q(not)      => "red",
    q(nxor)     => "seaGreen",
    q(one)      => "Navy",
    q(or)       => "darkBlue",
    q(output)   => "orange",
    q(xor)      => "darkGreen",
    q(zero)     => "gray",
   };

  my $svg = Svg::Simple::new(@defaults, %options, grid=>debugMask ? 1 : 0);     # Draw each wire via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

  for my $g($D->gates->@*)                                                      # Each gate
   {my ($x, $y, $w, $h, $t, $l) = @$g{qw(x y w h t l)};
    my $X  = $x+$w-1/10; my $xx = $x+$w/2; my $x14 = $x + $w/4; my $x18 = $x + $w/8;
    my $y1 = $y+$h/3; my $yy = $y+$h/2; my $y3 = $y+2*$h/3;  my $Y = $y+$h;
    my $c  = $$color{$t};
    defined($c) or confess "No color for $t";

    my sub Not()
     {if ($t =~ m(\An))
       {$svg->circle(cx=>$X, cy=>$yy, r=>1/10, fill_opacity=>0, stroke_width=>1/20, stroke=>"gold");
       }
     }

    my $arc = $svg->arcPath(64, $xx, $y, $X, $yy, $xx, $Y);

    $svg->rect(x=>$x, y=>$y, width=>$w, height=>$h, fill_opacity=>0, stroke_opacity=>0); # Warps the gate with an invisible rectangle to force the svg image out to the right size.  This line can be dropped when Svg::Simple takes paths into account when calculating the size of a drawing

    if    ($t eq "input")
     {$svg->circle(cx=>$x+1, cy=>$y+1/2, r =>1/3,          fill=>$c);
     }
    elsif ($t eq "output")
     {$svg->rect(x=>$x+1/2,   y=>$y, width=>1, height =>1, fill=>$c);
     }
    elsif ($t eq "not" or $t eq "continue")
     {$svg->path(d=>"M $x $y L $X $yy L $x $Y Z", stroke_width=>1/20, stroke=>$c, fill_opacity=>0.1, fill=>$c);
      Not();
     }
    elsif ($t =~ m(\An?or\Z))
     {$svg->path(d=>"M $x $y $arc L $x $Y  L $x14 $yy Z", stroke_width=>1/20, stroke=>$c, fill_opacity=>0.1, fill=>$c);
      Not();
     }
    elsif ($t =~ m(\An?and\Z))
     {$svg->path(d=>"M $x $y $arc L $x $Y  L $x   $yy Z", stroke_width=>1/20, stroke=>$c, fill_opacity=>0.1, fill=>$c);
      Not();
     }
    elsif ($t =~ m(\An?xor\Z))
     {$svg->path(d=>"M $x $y $arc L $x $Y  L $x18 $yy Z", stroke_width=>1/20, stroke=>$c, fill_opacity=>0.1, fill=>$c);
      $svg->path(d=>"M $x $y      L $x14 $yy L $x $Y",    stroke_width=>1/20, stroke=>$c, fill_opacity=>0.1, fill=>$c);
      Not();
     }
    elsif ($t =~ m(\An?gt\Z))
     {$svg->path(d=>"M $x $y L $X $y L $xx $yy L $X $Y L$x $Y Z ", stroke_width=>1/20, stroke=>$c, fill_opacity=>0.1, fill=>$c);
      Not();
     }
    elsif ($t =~ m(\An?lt\Z))
     {$svg->path(d=>"M $x $y L $xx $yy L $x $Y L $X $Y L$X $y Z ", stroke_width=>1/20, stroke=>$c, fill_opacity=>0.1, fill=>$c);
      Not();
     }
    elsif ($t =~ m(\AfanOut\Z))                                                 # Fan
     {my @arc = split /L/, $arc;
      for my $i(keys @arc)
       {next if $i % 8;
        $arc[$i] = " $x $yy ";                                                  # Neutralize some of the arc
       }
      shift @arc; pop @arc;
      my $fan = join "L", @arc;
      $svg->path(d=>"M $x $yy $fan", stroke_width=>1/20, stroke=>$c, fill_opacity=>0.1, fill=>$c);
     }
    elsif ($t eq "one" or $t eq "zero")
     {$svg->text(x=>$x+1,   y=>$y+1/2, fill=>$c, fill_opacity=>1, font_size=>1, cdata=>($t eq "one" ? "1" : "0"));
      $svg->rect(x=>$x+1/2, y=>$y, width=>1, height=>1, fill_opacity=>0, stroke=>$c, stroke_opacity=>1, stroke_width=>1/40);
     }
    $svg->text  (x=>$x+$w/2, y=>$y+$h/2, cdata=>$l);
   }

  my $t = $svg->print(                                                          # Text of svg - the width and height chosen to match those of Wiring.
    width =>($D->width //$options{width} //0)+1,
    height=>($D->height//$options{height}//0)+1);

  if (my $f = $options{svg})                                                    # Optionally write to an svg file
   {writeFile(fpe(q(svg), $f, q(svg)), $t)
   }

  $t
 }

#D0
#-------------------------------------------------------------------------------
# Export
#-------------------------------------------------------------------------------

use Exporter qw(import);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# containingFolder

@ISA          = qw(Exporter);
@EXPORT       = qw();
@EXPORT_OK    = qw();
%EXPORT_TAGS = (all=>[@EXPORT, @EXPORT_OK]);

#svg https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipLayout/lib/Silicon/Chip/svg/

=pod

=encoding utf-8

=for html <p><a href="https://github.com/philiprbrenan/SiliconChipLayout"><img src="https://github.com/philiprbrenan/SiliconChipLayout/workflows/Test/badge.svg"></a>

=head1 Name

Silicon::Chip::Layout - Layout the gates of a silicon chip L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.

=head1 Synopsis

=for html <p><img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipLayout/lib/Silicon/Chip/png/input1.png">

=head1 Description

Layout the gates of a silicon chip L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.


Version 20240308.


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 Construct

Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

=head2 new (%options)

New gates layout diagram.

     Parameter  Description
  1  %options   Options

B<Example:>



   {my $d = new;                                                                      # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲



=head2 gate($D, %options)

New gate on a gates diagram.

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


   {my $d = new;


=head1 Visualize

Visualize the layout of the gates

=head2 svg ($D, %options)

Draw the gates

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


   {my $d = new;



=head1 Hash Definitions




=head2 Silicon::Chip::Layout Definition


Gate




=head3 Output fields


=head4 gates

Gates on diagram

=head4 h

Height of gate

=head4 l

Type of gate

=head4 t

Type of gate

=head4 w

Width of gate

=head4 x

X upper left corner of gate

=head4 y

Y upper left corner of gate



=head1 Index


1 L<gate|/gate> - New gate on a gates diagram.

2 L<new|/new> - New gates layout diagram.

3 L<svg|/svg> - Draw the gates

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Silicon::Chip::Layout

=head1 Author

L<philiprbrenan@gmail.com|mailto:philiprbrenan@gmail.com>

L<http://prb.appaapps.com|http://prb.appaapps.com>

=head1 Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.

=cut



goto finish if caller;
clearFolder(q(svg), 99);                                                        # Clear the output svg folder
my $start = time;
eval "use Test::More";
eval "Test::More->builder->output('/dev/null')" if -e q(/home/phil/);
eval {goto latest} if -e q(/home/phil/);

my sub  ok($)        {!$_[0] and confess; &ok( $_[0])}
my sub nok($)        {&ok(!$_[0])}
my sub is_deeply($$) {&is_deeply(@_)}

# Tests

if (1)
 {my $d = new;                                                                  #Tnew #Tgate #Tsvg
     $d->gate(x=> 1, y=>1, w=>2, h=>1, t=>"input",    l=>"i1");
     $d->gate(x=> 1, y=>2, w=>2, h=>1, t=>"output",   l=>"o1");
     $d->gate(x=> 3, y=>1, w=>2, h=>2, t=>"or",       l=>"or");
     $d->gate(x=> 3, y=>3, w=>2, h=>2, t=>"nor",      l=>"nor");
     $d->gate(x=> 5, y=>1, w=>2, h=>2, t=>"and",      l=>"and");
     $d->gate(x=> 5, y=>3, w=>2, h=>2, t=>"nand",     l=>"nand");
     $d->gate(x=> 7, y=>1, w=>2, h=>2, t=>"xor",      l=>"xor");
     $d->gate(x=> 7, y=>3, w=>2, h=>2, t=>"nxor",     l=>"nxor");
     $d->gate(x=> 9, y=>1, w=>2, h=>2, t=>"lt",       l=>"lt");
     $d->gate(x=> 9, y=>3, w=>2, h=>2, t=>"nlt",      l=>"nlt");
     $d->gate(x=>11, y=>1, w=>2, h=>2, t=>"gt",       l=>"gt");
     $d->gate(x=>11, y=>3, w=>2, h=>2, t=>"ngt",      l=>"ngt");
     $d->gate(x=>13, y=>1, w=>2, h=>1, t=>"continue", l=>"cont");
     $d->gate(x=>13, y=>2, w=>2, h=>1, t=>"not",      l=>"not");
     $d->gate(x=>13, y=>3, w=>2, h=>1, t=>"one",      l=>"one");
     $d->gate(x=>13, y=>4, w=>2, h=>1, t=>"zero",     l=>"zero");
     $d->gate(x=>1,  y=>3, w=>2, h=>2, t=>"fanOut",   l=>"fan out");
     $d->svg(svg=>q(input1), width=>14, height=>6);
 }

#latest:;

ok  1;
&done_testing;
finish: 1
