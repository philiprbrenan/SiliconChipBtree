<div>
    <p><a href="https://github.com/philiprbrenan/MathIntersectionCircleLine"><img src="https://github.com/philiprbrenan/MathIntersectionCircleLine/workflows/Test/badge.svg"></a>
</div>

# Name

    Math::Intersection::Circle::Line - Find the points at which circles and lines
    intersect to test geometric intuition.

# Synopsis

    use Math::Intersection::Circle::Line q(:all);
    use Test::More q(no_plan);
    use utf8;

    # Euler Line, see: L<https://en.wikipedia.org/wiki/Euler_line>

    if (1)
     {my @t = (0, 0, 4, 0, 0, 3);                                                  # Corners of the triangle
      &areaOfPolygon(sub {ok !$_[0]},                                              # Polygon formed by these points has zero area and so is a line or a point
        &circumCircle   (sub {@_[0,1]}, @t),                                       # green
        &ninePointCircle(sub {@_[0,1]}, @t),                                       # red
        &orthoCentre    (sub {@_[0,1]}, @t),                                       # blue
        &centroid       (sub {@_[0,1]}, @t));                                      # orange
     }

    # An isosceles tringle with an apex height of 3/4 of the radius of its
    # circumcircle divides Euler's line into 6 equal pieces

    if (1)
     {my $r = 400;                                                                 # Arbitrary but convenient radius
      intersectionCircleLine                                                       # Find coordinates of equiangles of isoceles triangle
       {my ($x, $y, $𝕩, $𝕪) = @_;                                                  # Coordinates of equiangles
        my ($𝘅, $𝘆) = (0, $r);                                                     # Coordinates of apex
        my ($nx, $ny, $nr) = ninePointCircle {@_} $x, $y, $𝘅, $𝘆, $𝕩, $𝕪;          # Coordinates of centre and radius of nine point circle
        my ($cx, $cy)      = centroid        {@_} $x, $y, $𝘅, $𝘆, $𝕩, $𝕪;          # Coordinates of centroid
        my ($ox, $oy)      = orthoCentre     {@_} $x, $y, $𝘅, $𝘆, $𝕩, $𝕪;          # Coordinates of orthocentre
        ok near(100, $y);                                                          # Circumcentre to base of triangle
        ok near(200, $cy);                                                         # Circumcentre to lower circumference of nine point circle
        ok near(300, $y+$nr);                                                      # Circumcentre to centre of nine point circle
        ok near(400, $𝘆);                                                          # Circumcentre to apex of isosceles triangle
        ok near(500, $y+2*$nr);                                                    # Circumcentre to upper circumference of nine point circle
        ok near(600, $oy);                                                         # Circumcentre to orthocentre
       } 0, 0, $r,  0, $r/4, 1, $r/4;                                              # Chord at 1/4 radius
     }

    # A line segment across a circle is never longer than the diameter

    if (1)                                                                         # Random circle and random line
     {my ($x, $y, $r, $𝘅, $𝘆, $𝕩, $𝕪) = map {rand()} 1..7;
      intersectionCircleLine                                                       # Find intersection of a circle and a line
       {return ok 1 unless @_ == 4;                                                # Ignore line unless it crosses circle
        ok &vectorLength(@_) <= 2*$r;                                              # Length if line segment is less than or equal to that of a diameter
      } $x, $y, $r, $𝘅, $𝘆, $𝕩, $𝕪;                                                # Circle and line to be intersected
     }

    # The length of a side of a hexagon is the radius of a circle inscribed through
    # its vertices

    if (1)
     {my ($x, $y, $r) = map {rand()} 1..3;                                         # Random circle
      my @p = intersectionCircles {@_} $x, $y, $r, $x+$r, $y, $r;                  # First step of one radius
      my @𝗽 = intersectionCircles {@_} $x, $y, $r, $p[0], $p[1], $r;               # Second step of one radius
      my @q = !&near($x+$r, $y, @𝗽[0,1]) ? @𝗽[0,1] : @𝗽[2,3];                      # Away from start point
      my @𝗾 = intersectionCircles {@_} $x, $y, $r, $q[0], $q[1], $r;               # Third step of one radius
      ok &near2(@𝗾[0,1], $x-$r, $y) or                                             # Brings us to a point
         &near2(@𝗾[2,3], $x-$r, $y);                                               # opposite to the start point
     }

    # Circle through three points chosen at random has the same centre regardless of
    # the pairing of the points

    sub circleThrough3
     {my ($x, $y, $𝘅, $𝘆, $𝕩, $𝕪) = @_;                                            # Three points
     &intersectionLines
      (sub                                                                         # Intersection of bisectors is the centre of the circle
        {my @r =(&vectorLength(@_, $x, $y),                                        # Radii from centre of circle to each point
                 &vectorLength(@_, $𝘅, $𝘆),
                 &vectorLength(@_, $𝕩, $𝕪));
         ok &near(@r[0,1]);                                                        # Check radii are equal
         ok &near(@r[1,2]);
          @_                                                                       # Return centre
        }, rotate90AroundMidPoint($x, $y, $𝘅, $𝘆),                                 # Bisectors between pairs of points
           rotate90AroundMidPoint($𝕩, $𝕪, $𝘅, $𝘆));
     }

    if (1)
     {my (@points) = map {rand()} 1..6;                                            # Three points chosen at random
      ok &near2(circleThrough3(@points), circleThrough3(@points[2..5, 0..1]));     # Circle has same centre regardless
      ok &near2(circleThrough3(@points), circleThrough3(@points[4..5, 0..3]));     # of the pairing of the points
     }

# Description

    Find the points at which circles and lines intersect to test geometric
    intuition.

    Fast, fun and easy to use these functions are written in 100% Pure Perl.

## areaOfTriangle 𝘀𝘂𝗯 triangle

    Calls 𝘀𝘂𝗯($a) where $a is the area of the specified triangle:

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## areaOfPolygon 𝘀𝘂𝗯 points...

    Calls 𝘀𝘂𝗯($a) where $a is the area of the polygon with vertices specified by
    the points.

    A point is specified by supplying a list of two numbers:

     (𝘅, 𝘆)

## centroid 𝘀𝘂𝗯 triangle

    Calls 𝘀𝘂𝗯($x,$y) where $x,$y are the coordinates of the centroid of the
    specified triangle:

    See: L<https://en.wikipedia.org/wiki/Centroid>

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## circumCentre 𝘀𝘂𝗯 triangle

    Calls 𝘀𝘂𝗯($x,$y,$r) where $x,$y are the coordinates of the centre of the
    circle drawn through the corners of the specified triangle and $r is its
    radius:

    See: L<https://en.wikipedia.org/wiki/Circumscribed_circle>

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## circumCircle 𝘀𝘂𝗯 triangle

    Calls 𝘀𝘂𝗯($x,$y,$r) where $x,$y are the coordinates of the circumcentre of
    the specified triangle and $r is its radius:

    See: L<https://en.wikipedia.org/wiki/Circumscribed_circle>

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## exCircles 𝘀𝘂𝗯 triangle

    Calls 𝘀𝘂𝗯([$x,$y,$r]...) where $x,$y are the coordinates of the centre of each
    ex-circle and $r its radius for the specified triangle:

    See: L<https://en.wikipedia.org/wiki/Incircle_and_excircles_of_a_triangle>

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## circleInscribedInTriangle 𝘀𝘂𝗯 triangle

    Calls 𝘀𝘂𝗯($x,$y,$r) where $x,$y are the coordinates of the centre of
    a circle which touches each side of the triangle just once and $r is its radius:

    See: L<https://en.wikipedia.org/wiki/Incircle_and_excircles_of_a_triangle#Incircle>

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## intersectionCircles 𝘀𝘂𝗯 circle1, circle2

    Find the points at which two circles intersect.  Complains if the two circles
    are identical.

     𝘀𝘂𝗯 specifies a subroutine to be called with the coordinates of the
    intersection points if there are any or an empty parameter list if there are
    no points of intersection.

    A circle is specified by supplying a list of three numbers:

     (𝘅, 𝘆, 𝗿)

    where (𝘅, 𝘆) are the coordinates of the centre of the circle and (𝗿) is its
    radius.

    Returns whatever is returned by 𝘀𝘂𝗯.

## intersectionCirclesArea 𝘀𝘂𝗯 circle1, circle2

    Find the area of overlap of two circles expressed as a fraction of the area of
    the smallest circle. The fractional area is expressed as a number between 0
    and 1.

    𝘀𝘂𝗯 specifies a subroutine to be called with the fractional area.

    A circle is specified by supplying a list of three numbers:

     (𝘅, 𝘆, 𝗿)

    where (𝘅, 𝘆) are the coordinates of the centre of the circle and (𝗿) is its
    radius.

    Returns whatever is returned by 𝘀𝘂𝗯.

## intersectionCircleLine 𝘀𝘂𝗯 circle, line

    Find the points at which a circle and a line intersect.

     𝘀𝘂𝗯 specifies a subroutine to be called with the coordinates of the
    intersection points if there are any or an empty parameter list if there are
    no points of intersection.

    A circle is specified by supplying a list of three numbers:

     (𝘅, 𝘆, 𝗿)

    where (𝘅, 𝘆) are the coordinates of the centre of the circle and (𝗿) is its
    radius.

    A line is specified by supplying a list of four numbers:

     (x, y, 𝘅, 𝘆)

    where (x, y) and (𝘅, 𝘆) are the coordinates of two points on the line.

    Returns whatever is returned by 𝘀𝘂𝗯.

## intersectionCircleLineArea 𝘀𝘂𝗯 circle, line

    Find the fractional area of a circle occupied by a lune produced by an
    intersecting line. The fractional area is expressed as a number
    between 0 and 1.

     𝘀𝘂𝗯 specifies a subroutine to be called with the fractional area.

    A circle is specified by supplying a list of three numbers:

     (𝘅, 𝘆, 𝗿)

    where (𝘅, 𝘆) are the coordinates of the centre of the circle and (𝗿) is its
    radius.

    A line is specified by supplying a list of four numbers:

     (x, y, 𝘅, 𝘆)

    where (x, y) and (𝘅, 𝘆) are the coordinates of two points on the line.

    Returns whatever is returned by 𝘀𝘂𝗯.

## intersectionLines 𝘀𝘂𝗯 line1, line2

    Finds the point at which two lines intersect.

     𝘀𝘂𝗯 specifies a subroutine to be called with the coordinates of the
    intersection point or an empty parameter list if the two lines do not
    intersect.

    Complains if the two lines are collinear.

    A line is specified by supplying a list of four numbers:

     (x, y, 𝘅, 𝘆)

    where (x, y) and (𝘅, 𝘆) are the coordinates of two points on the line.

    Returns whatever is returned by 𝘀𝘂𝗯.

## intersectionLinePoint 𝘀𝘂𝗯 line, point

    Find the point on a line closest to a specified point.

     𝘀𝘂𝗯 specifies a subroutine to be called with the coordinates of the
    intersection points if there are any.

    A line is specified by supplying a list of four numbers:

     (x, y, 𝘅, 𝘆)

    where (x, y) and (𝘅, 𝘆) are the coordinates of two points on the line.

    A point is specified by supplying a list of two numbers:

     (𝘅, 𝘆)

    where (𝘅, 𝘆) are the coordinates of the point.

    Returns whatever is returned by 𝘀𝘂𝗯.

## isEquilateralTriangle triangle

    Return true if the specified triangle is close to being equilateral within the
    definition of nearness.

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## isIsoscelesTriangle triangle

    Return true if the specified triangle is close to being isosceles within the
    definition of nearness.

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## isRightAngledTriangle triangle

    Return true if the specified triangle is close to being right angled within
    the definition of nearness.

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## ninePointCircle 𝘀𝘂𝗯 triangle

    Calls 𝘀𝘂𝗯($x,$y,$r) where $x,$y are the coordinates of the centre of the
    circle drawn through the midpoints of each side of the specified triangle and
    $r is its radius which gives the nine point circle:

    See: L<https://en.wikipedia.org/wiki/Nine-point_circle>

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## orthoCentre 𝘀𝘂𝗯 triangle

    Calls 𝘀𝘂𝗯($x,$y) where $x,$y are the coordinates of the orthocentre of the
    specified triangle:

    See: L<https://en.wikipedia.org/wiki/Altitude_%28triangle%29>

    A triangle is specified by supplying a list of six numbers:

     (x, y, 𝘅, 𝘆, 𝕩, 𝕪)

    where (x, y), (𝘅, 𝘆) and (𝕩, 𝕪) are the coordinates of the vertices of the
    triangle.

## $Math::Intersection::Circle::Line::near

    As a finite computer cannot represent an infinite plane of points it is
    necessary to make the plane discrete by merging points closer than the
    distance contained in this variable, which is set by default to 1e-6.

# Exports

    The following functions are exported by default:

- `areaOfPolygon()`
- `areaOfTriangle()`
- `centroid()`
- `circumCentre()`
- `circumCircle()`
- `circleInscribedInTriangle()`
- `circleThroughMidPointsOfTriangle()`
- `exCircles()`
- `intersectionCircleLine()`
- `intersectionCircleLineArea()`
- `intersectionCircles()`
- `intersectionCircles()`
- `intersectionCirclesArea()`
- `intersectionLines()`
- `intersectionLinePoint()`
- `isEquilateralTriangle()`
- `isIsoscelesTriangle()`
- `isRightAngledTriangle()`
- `orthoCentre()`

    Optionally some useful helper functions can also be exported either by
    specifying the tag :𝗮𝗹𝗹 or by naming the required functions individually:

- `acos()`
- `lengthsOfTheSidesOfAPolygon()`
- `midPoint()`
- `midPoint()`
- `near()`
- `near2()`
- `near3()`
- `near4()`
- `rotate90CW()`
- `rotate90CCW()`
- `rotate90AroundMidPoint()`
- `smallestPositiveAngleBetweenTwoLines()`
- `threeCollinearPoints()`
- `vectorLength()`
- `𝝿()`

# Changes

    1.003 Sun 30 Aug 2015 - Started Geometry app
    1.005 Sun 20 Dec 2015 - Still going!
    1.006 Sat 02 Jan 2016 - Euler's line divided into 6 equal pieces
    1.007 Sat 02 Jan 2016 - [rt.cpan.org #110849] Test suite fails with uselongdouble
    1.008 Sun 03 Jan 2016 - [rt.cpan.org #110849] Removed dump

# Installation

    Standard Module::Build process for building and installing modules:

      perl Build.PL
      ./Build
      ./Build test
      ./Build install

    Or, if you're on a platform (like DOS or Windows) that doesn't require
    the "./" notation, you can do this:

      perl Build.PL
      Build
      Build test
      Build install

# Author

    Philip R Brenan at gmail dot com

    http://www.appaapps.com

# Copyright

    Copyright (c) 2016 Philip R Brenan.

    This module is free software. It may be used, redistributed and/or
    modified under the same terms as Perl itself.
