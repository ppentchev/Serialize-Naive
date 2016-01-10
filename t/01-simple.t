#!/usr/bin/env perl6

use v6;
use strict;

use Serialize::Naive;
use Test;

plan 8;

class Point does Serialize::Naive
{
	has Int $.x;
	has Int $.y;
}

class Circle does Serialize::Naive
{
	has Point $.center;
	has Rat $.radius;
}

class Triangle does Serialize::Naive
{
	#has Point @.vertices;
	has Array[Point] $.vertices;
	has Str $.label;

	method is-valid() returns Bool:D
	{
		return $!vertices.elems == 3;
	}
}

{
	my %data = center => {x => 1, y => 2}, radius => 1.5;

	my Circle:D $c = Circle.deserialize(%data);
	is $c.radius, 1.5, 'trivial - radius';
	is $c.center.x, 1, 'trivial - center - x';
	is $c.center.y, 2, 'trivial - center - y';

	my %tridata = label => 'Soldier Y', unhand => 'me', vertices => [
		{x => 0, y => 0},
		{x => 1},
		{x => 1, y => 1, weird => 'ness'},
	];

	my UInt:D $warnings = 0;
	my Triangle:D $tri = Triangle.deserialize(%tridata,
	    :warn(sub ($) { $warnings++ }));
	ok $tri.is-valid, 'triangle - valid';
	nok $tri.vertices[1].y.defined, 'triangle - an undefined value';
	is $warnings, 2, 'triangle - unhandled value warnings';

	my %newdata = $c.serialize;
	is-deeply %newdata, %data, 'trivial - serialize back';

	my %newtridata = $tri.serialize;
	%tridata<unhand>:delete;
	%tridata<vertices>[2]<weird>:delete;
	is-deeply %newtridata, %tridata, 'triangle - serialize back';
}
