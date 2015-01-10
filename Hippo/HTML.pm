package Hippo::HTML;

use common::sense;

use Carp;

sub new {
	my $class = shift @_;
	if (@_ <= 1) {
		return $class->new_single($_[0]);
	} else {
		return Hippo::HTML::Sequence->new([ @_ ]);
	}
}

sub new_single {
	my ($class, $arg) = @_;

	given (ref $arg) {
		when ("") {
			return Hippo::HTML::Text->new($arg);
		}
		when ('ARRAY') {
			if (defined $arg->[0]) {
				return Hippo::HTML::Element->new($arg);
			} else {
				return Hippo::HTML::Sequence->new($arg);
			}
		}
		when (/^Hippo::HTML::/) {
			return $arg;
		}
		default {
			confess "Unknown data type passed to Hippo::HTML->new: $arg";
		}
	}
}

package Hippo::HTML::Raw;

sub new {
	my ($class, $text) = @_;
	my $e = [ $text ];
	return bless $e;
}

sub render {
	my ($self, $fh, $indent) = @_;
	print $fh "\t" x $indent if $indent >= 0;
	print $fh $self->[0];
	print $fh "\n" if $indent >= 0;
}

package Hippo::HTML::Text;

sub new {
	my ($class, $text) = @_;
	my $e = [ $text ];
	return bless $e;
}

sub escape {
	my $x = shift @_;
	$x =~ s/&/&amp;/g;
	$x =~ s/</&lt;/g;
	$x =~ s/>/&gt;/g;
	$x =~ s/"/&quot;/g;
	$x =~ s/'/&#39;/g;
	return $x;
}

sub render {
	my ($self, $fh, $indent) = @_;
	print $fh "\t" x $indent if $indent >= 0;
	print $fh escape($self->[0]);
	print $fh "\n" if $indent >= 0;
}

package Hippo::HTML::Element;

use Carp;

my %default_options = (
	'a' => { _flat => 1 },
	'base' => { _empty => 1 },
	'br' => { _empty => 1 },
	'dd' => { _noclose => 1 },
	'dt' => { _noclose => 1 },
	'h1' => { _flat => 1 },
	'h2' => { _flat => 1 },
	'h3' => { _flat => 1 },
	'h4' => { _flat => 1 },
	'h5' => { _flat => 1 },
	'h6' => { _flat => 1 },
	'hr' => { _empty => 1 },
	'img' => { _empty => 1 },
	'input' => { _empty => 1 },
	'link' => { _empty => 1 },
	'meta' => { _empty => 1 },
	'p' => { _flat => 1 },
	'param' => { _empty => 1 },
	'td' => { _flat => 1, _noclose => 1 },
	'th' => { _flat => 1, _noclose => 1 },
	'title' => { _flat => 1 },
	'tr' => { _flat => 1, _noclose => 1 },
);

sub new {
	my ($class, $arg) = @_;

	my $elt = $arg->[0] // confess;
	ref $elt and confess;

	my $attrs = {};
	my $def = $default_options{$elt};
	if ($def) {
		for my $k (keys %$def) {
			$attrs->{$k} = $def->{$k};
		}
	}

	my $i = 1;
	if (ref $arg->[$i] eq 'HASH') {
		my $a = $arg->[$i++];
		for my $k (keys %$a) {
			$attrs->{$k} = $a->{$k};
		}
	}

	my $sons = [];
	while ($i < scalar @$arg) {
		push @$sons, Hippo::HTML->new_single( $arg->[$i++] );
	}

	my $e = {
		elt => $elt,
		attrs => $attrs,
	};
	$e->{sons} = $sons if @$sons;
	return bless $e, 'Hippo::HTML::Element';
}

sub render {
	my ($self, $fh, $indent) = @_;
	my $tag = $self->{elt};
	my $attrs = $self->{attrs};

	my @alist = ();
	for my $a (sort keys %$attrs) {
		my $v = $attrs->{$a};
		if ($a =~ m{^_}) {
			# Internal attribute
		} elsif ($a =~ m{^(.*)!$}) {
			push @alist, $1 if $v;
		} else {
			push @alist, $a . "='" . Hippo::HTML::Text::escape($v) . "'" if defined $v;
		}
	}

	my $rec_indent = $indent;
	if ($indent >= 0) {
		print $fh "\t" x $indent;
		if ($attrs->{_flat}) {
			$rec_indent = -1;
		} else {
			$rec_indent++;
		}
	}
	print $fh '<', $tag;
	print $fh ' ', join(' ', @alist) if @alist;
	print $fh '>';
	if ($rec_indent >= 0) {
		print $fh "\n";
	}

	if ($attrs->{_empty}) {
		!@{$self->{sons}} or confess;
		return;
	}

	for my $son (@{$self->{sons}}) {
		$son->render($fh, $rec_indent);
	}

	unless ($attrs->{_noclose}) {
		print $fh "\t" x $indent if $rec_indent >= 0;
		print $fh '</', $tag, '>';
	}
	print $fh "\n" if $indent >= 0;
}

package Hippo::HTML::Sequence;

sub new {
	my ($class, $arg) = @_;
	my $e = [ map { defined($_) ? Hippo::HTML->new_single($_) : () } @$arg ];
	return bless $e;
}

sub render {
	my ($self, $fh, $indent) = @_;
	$_->render($fh, $indent) for @$self;
}

42;

__END__

=pod

=head1 NAME

Hippo::HTML - a tree-based representation of HTML.

=head1 SYNOPSIS

  my $t = Hippo::HTML->new(
    [ 'div',
      [ 'h1', 'Heading' ],
      [ 'p', { class => 'test' },
        'A paragraph of text with one word ',
        [ 'em', 'emphasized' ],
        ' and another ',
        [ 'i', 'in italics' ],
      ],
      [ 'p', Hippo::HTML::Raw->new('&#9731;') ],
      [ 'table', [ 'tr', [ 'td', 1 ], [ 'td', 2 ] ], [ 'tr', [ 'td', 3 ], [ 'td', '4' ] ] ],
    ]
  );

  $t->render(\*STDOUT, 0);

=head1 DESCRIPTION

C<Hippo::HTML> provides a representation of HTML documents by Perl data structures.
The constructor of this class produces an object of one of the following subclasses,
based on its parameters:

=over

=item *
C<Hippo::HTML::Text> - a piece of text, which will be properly escaped in the output
(dangerous characters replaced by entities).

=item *
C<Hippo::HTML::Element> - a HTML element, together with its attributes and a list
of descendants.

Attribute values will be automatically escaped.

Attribute names prefixed with C<!> represent boolean attributes
(i.e., an attribute without a value, like C<selected> in the C<INPUT> element).
When the attribute's value is evaluated as true in boolean context, the attribute
will be included in the output; otherwise, it will be omitted.

Attribute names prefixed with C<_> are internal, invisible in the generated
output. The following internal attributes are recognized:

=over

=item *
C<_empty> - the element has no contents (that is, no descendants)

=item *
C<_noclose> - the element does not need a close tag

=item *
C<_flat> - render element contents as one line with no indent

=back

When a well-known HTML element is constructed, the internal attributes
are set up automatically. However, you can override them if you wish.

=item *
C<Hippo::HTML::Sequence> - a sequence of HTML objects of arbitrary types.

=item *
C<Hippo::HTML::Raw> - a string of raw HTML code. Will be rendered as-is.

=back

=head1 METHODS

=head2 new

  my $tree = Hippo::HTML->new($template);

Construct a tree of HTML objects from a Perl data structure given as C<$template>.

A template can be:

=over

=item *
a scalar: translated to C<Hippo::HTML::Text>.

=item *
an array reference: a C<Hippo::HTML::Element> is constructed. The first
item of the array is used as the name of the element. Immediately after it, a hash reference
containing element's attributes may be present (attribute values will be escaped automatically).
The rest of the array is used as templates for descendants of the element.

=item *
an array reference, whose first item is C<undef>: construct a C<Hippo::HTML::Sequence>.

=item *
an object reference: already constructed HTML objects may be included directly.
Please note that when such an object becomes a part of another object, it will
not be copied, only the reference will.

=item *
multiple templates may be given: in this case, a C<Hippo::HTML::Sequence> is constructed.

=back

=head2 render

  $object->render($fh, $indent)

Construct textual representation of the given HTML object and write it to file handle C<$fh>,
indented by the given number of steps (C<-1> for a one-line representation without indent).

=head1 AUTHOR

Martin Mares
