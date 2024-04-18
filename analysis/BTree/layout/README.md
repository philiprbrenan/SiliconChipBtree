<div>
    <p><a href="https://github.com/philiprbrenan/SiliconChipLayout"><img src="https://github.com/philiprbrenan/SiliconChipLayout/workflows/Test/badge.svg"></a>
</div>

# Name

Silicon::Chip::Layout - Layout the gates of a silicon chip [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) to combine [logic gates](https://en.wikipedia.org/wiki/Logic_gate) to transform software into hardware.

# Synopsis

<div>
    <p><img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipLayout/lib/Silicon/Chip/png/input1.png">
</div>

# Description

Layout the gates of a silicon chip [silicon](https://en.wikipedia.org/wiki/Silicon) [chip](https://en.wikipedia.org/wiki/Integrated_circuit) to combine [logic gates](https://en.wikipedia.org/wiki/Logic_gate) to transform software into hardware.

Version 20240308.

The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see [Index](#index).

# Construct

Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

## new (%options)

New gates layout diagram.

       Parameter  Description
    1  %options   Options

**Example:**

    {my $d = new;                                                                      # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

## gate($D, %options)

New gate on a gates diagram.

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    {my $d = new;

# Visualize

Visualize the layout of the gates

## svg ($D, %options)

Draw the gates

       Parameter  Description
    1  $D         Diagram
    2  %options   Options

**Example:**

    {my $d = new;

# Hash Definitions

## Silicon::Chip::Layout Definition

Gate

### Output fields

#### gates

Gates on diagram

#### h

Height of gate

#### l

Type of gate

#### t

Type of gate

#### w

Width of gate

#### x

X upper left corner of gate

#### y

Y upper left corner of gate

# Index

1 [gate](#gate) - New gate on a gates diagram.

2 [new](#new) - New gates layout diagram.

3 [svg](#svg) - Draw the gates

# Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via **cpan**:

    sudo cpan install Silicon::Chip::Layout

# Author

[philiprbrenan@gmail.com](mailto:philiprbrenan@gmail.com)

[http://prb.appaapps.com](http://prb.appaapps.com)

# Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.
