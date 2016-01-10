unit role Serialize::Naive;

use v6;
use strict;

my $serialize-basic-types = (Str, Str:D, Bool, Bool:D,
    Int, Int:D, UInt, UInt:D, Rat, Rat:D, Any, Any:D);

sub walk-type($type, $value, Sub :$objfunc, :$array-type, :$hash-type, Sub :$warn)
{
	for $serialize-basic-types.values -> $basic {
		next unless $basic === $type;

		# Ah, weirdness...
		if $type === Rat || $type === Rat:D {
			return $value.Rat;
		} else {
			return $value;
		}
	}

	if $type ~~ Positional {
		my $sub = $type.of;
		my $arr-type = $array-type !=== Any?? $array-type!! $type;
		return $arr-type.new($value.values.map: {
			walk-type($sub, $_, :objfunc($objfunc), :warn($warn))
		});
	}

	if $type ~~ Associative {
		my $sub = $type.of;
		my $h-type = $hash-type !=== Any?? $hash-type!! $type;
		return $h-type.new($value.kv.map: -> $k, $v {
			$k => walk-type($sub, $v, :objfunc($objfunc),
			    :array-type($array-type), :hash-type($hash-type),
			    :warn($warn))
		});
	}

	return $objfunc($value, $type, :warn($warn));
}

sub do-deserialize(%data, $type, Sub :$warn)
{
	my %build;
	my Bool %handled;
	for $type.^attributes -> $attr {
		my Str $name = $attr.name;
		$name ~~ s/^\$\!//;
		my $type = $attr.type;

		next unless %data{$name}:exists;
		%handled{$name} = True;
		my $value = %data{$name};
		%build{$name} = walk-type($type, $value,
		    :objfunc(&do-deserialize), :warn($warn));
	}

	my Str @unhandled = %data.keys.grep: { not %handled{$_}:exists };
	if @unhandled && $warn.defined {
		&$warn("Deserializing " ~ $type.^name ~ ": " ~
		    "unhandled data elements: " ~ @unhandled);
	}
	return $type.new(|%build);
}

method deserialize(%data, Sub :$warn)
{
	return do-deserialize %data, self.WHAT, :warn($warn);
}

sub do-serialize($obj, $type, Sub :$warn)
{
	my %build;
	for $type.^attributes -> $attr {
		next unless $attr.has_accessor;

		my Str $name = $attr.name;
		$name ~~ s/^\$\!//;
		my $value = $attr.get_value($obj);
		next unless $value.defined;

		%build{$name} = walk-type($attr.type, $value,
		    :objfunc(&do-serialize),
		    :array-type(Array), :hash-type(Hash),
		    :warn($warn));
	}
	return %build;
}

method serialize(Sub :$warn)
{
	return do-serialize self, self.WHAT, :warn($warn);
}
