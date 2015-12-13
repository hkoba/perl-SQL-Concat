package SQL::Concat;
use 5.010;
use strict;
use warnings;
use Carp;

our $VERSION = "0.001";

use MOP4Import::Base::Configure -as_base
  , [fields => qw/sql bind/
     , [sep => default => ' ']]
  ;
use MOP4Import::Util qw/lexpand terse_dump/;

sub SQL {
  MY->new(sep => ' ')->concat(@_);
}

sub PAR {
  SQL(@_)->paren;
}

# Useful for OPT("limit ?", $limit, OPT("offset ?", $offset))
sub OPT {
  my ($expr, $value, @rest) = @_;
  return unless defined $value;
  SQL([$expr, $value], @rest);
}

sub PFX {
  my ($prefix, @items) = @_;
  return unless @items;
  SQL($prefix => @items);
}

# sub SELECT {
#   MY->new(sep => ' ')->concat(SELECT => @_);
# }

sub CAT {
  MY->concat_by(_wrap_ws($_[0]), @_[1..$#_]);
}

sub CSV {
  MY->concat_by(', ', @_);
}

sub _wrap_ws {
  my ($str) = @_;
  $str =~ s/^(\S)/ $1/;
  $str =~ s/(\S)\z/$1 /;
  $str;
}

# XXX: Do you want deep copy?
sub clone {
  (my MY $item) = @_;
  MY->new(%$item)
}

sub paren {
  shift->format_by('(%s)');
}

sub format_by {
  (my MY $item, my $fmt) = @_;
  my MY $clone = $item->clone;
  $clone->{sql} = sprintf($fmt, $item->{sql});
  $clone;
}

sub concat_by {
  my MY $self = ref $_[0]
    ? shift->configure(sep => shift)
    : shift->new(sep => shift);
  $self->concat(@_);
}

sub concat {
  my MY $self = ref $_[0] ? shift : shift->new;
  if (defined $self->{sql}) {
    croak "concat() called after concat!";
  }
  my @sql;
  $self->{bind} = [];
  foreach my MY $item (@_) {
    next unless defined $item;
    if (not ref $item) {
      push @sql, $item;
    } else {
      my ($s, @b) = ref $item eq 'ARRAY'
	? @$item : ($item->{sql}, lexpand($item->{bind}));
      unless (defined $s) {
	croak "Undefined SQL Fragment!";
      }
      unless (($s =~ tr,?,?,) == @b) {
	croak "SQL Placeholder mismatch! sql='$s' bind=".terse_dump(@b);
      }
      push @sql, $s;
      push @{$self->{bind}}, @b;
    }
  }
  $self->{sql} = join($self->{sep}, @sql);
  $self
}

sub as_sql_bind {
  (my MY $self) = @_;
  if (wantarray) {
    ($self->{sql}, lexpand($self->{bind}));
  } else {
    [$self->{sql}, lexpand($self->{bind})];
  }
}

#========================================

sub BQ {
  if (ref $_[0]) {
    croak "Meaningless backtick for reference! ".terse_dump($_[0]);
  }
  if ($_[0] =~ /\`/) {
    croak "Can't quote by backtick: text contains backtick! $_[0]";
  }
  q{`}.$_[0].q{`}
}


sub _sample {

  my $name;

  SQL(select => "*" => from => table => );

  my $comp = SQL::Concat->new(sep => ' ')
    ->concat(SELECT => foo => FROM => 'bar');

  my $composed = SQL(SELECT => "*" =>
		     FROM   => entries =>
		     WHERE  => ("uid =" =>
				PAR(SQL(SELECT => uid => FROM => authors =>
					WHERE => ["name = ?", $name])))
		   );

  my ($sql, @bind) = $composed->as_sql_bind;
}

1;
__END__

=encoding utf-8

=head1 NAME

SQL::Concat - Zero knowledge concatenator for SQLs (with hidden bind variables)

=head1 SYNOPSIS

    # Functional interface
    use SQL::Concat qw/SQL PAR/;

    my $composed = SQL(SELECT => "*" =>
                       FROM   => entries =>
                       WHERE  => ("uid =" =>
                                  PAR(SQL(SELECT => uid => FROM => authors =>
                                          WHERE => ["name = ?", $name])))
                     );

    my ($sql, @bind) = $composed->as_sql_bind;

    # OO Interface
    my $comp = SQL::Concat->new(sep => ' ')
      ->concat(SELECT => foo => FROM => 'bar');


=head1 DESCRIPTION

SQL::Concat is yet another SQL generator for B<minimalists>.
This module only focuses on correctly concatinating SQL fragments
with keeping their corresponding bind variables.
Other important topics about SQL B<syntaxes>, B<quotes> or even B<SQL keywords>
are all remained untouched to B<your side>. In other words, if you don't (want to)
learn about SQL, use other SQL generators (e.g. L<SQL::Maker>, L<SQL::Abstract>, ...) instead.

=head2 What concat() does is...

C<join($SEP, @ITEMS)>! except it knows about bind variables and placeholders.
Default $SEP is C<' '> but you can give it as L</sep> option or L</concat_by>.

=over 4

=item STRING

Just used as resulting SQL as-is.
This means each given strings are treated as B<RAW> SQL fragment.
If you want to use foreign values, you must use next L</BIND_ARRAY>.

  use SQL::Concat qw/SQL/;

  SQL(SELECT => 1)->as_sql_bind;
  # SQL: "SELECT 1"
  # BIND: ()

  SQL(SELECT => 'foo, bar' => FROM => 'baz', "\nORDER BY bar")->as_sql_bind;
  # SQL: "SELECT foo, bar FROM baz
  #       ORDER BY bar"
  # BIND: ()


=item BIND_ARRAY [$RAW_SQL, @BIND]
X<BIND_ARRAY>

First element is treated as RAW SQL.
Rest of the elements are pushed into C<< ->{bind} >> array.
This SQL fragment must contain same number of SQL-placeholders(C<?>)
with corresponding @BIND variables.

  SQL(["city = ?", 'tokyo'])->as_sql_bind
  # SQL: "city = ?"
  # BIND: ('tokyo')

  SQL(["age BETWEEN ? AND ?", 20, 65])->as_sql_bind
  # SQL: "age BETWEEN ? AND ?"
  # BIND: (20, 65)

=item SQL::Concat
X<compose>

Finally, concat() can accept SQL::Concat instances. In this case, C<< ->{sql} >> and C<< ->{bind} >> are extracted and treated just like L</BIND_ARRAY>

  SQL(SELECT => "*" =>
      FROM => members =>
      WHERE =>
      SQL(["city = ?", "tokyo"]),
      AND =>
      SQL(["age BETWEEN ? AND ?", 20, 65])
  )->as_sql_bind;
  # SQL: "SELECT * FROM members WHERE city = ? AND age BETWEEN ? AND ?"
  # BIND: ('tokyo', 20, 65)

=back

=head2 Helper methods/functions for complex SQL construction

To build complex SQL, we often need to put parens around some SQL fragments.
For example:

  SQL(SELECT =>
      , SQL(SELECT => "count(*)" => FROM => "foo")
      , ","
      , SQL(SELECT => "count(*)" => FROM => "bar")
  )
  # (WRONG) SQL: SELECT SELECT count(*) FROM foo , SELECT count(*) FROM bar

Fortunately, SQL::Concat has C<< ->paren >> method, so you can write

  SQL(SELECT =>
      , SQL(SELECT => "count(*)" => FROM => "foo")->paren
      , ","
      , SQL(SELECT => "count(*)" => FROM => "bar")->paren
  )
  # SQL: SELECT (SELECT count(*) FROM foo) , (SELECT count(*) FROM bar)

Ore you can use another function L</PAR>.

  use SQL::Concat qw/SQL PAR/;

  SQL(SELECT =>
      , PAR(SELECT => "count(*)" => FROM => "foo")
      , ","
      , PAR(SELECT => "count(*)" => FROM => "bar")
  )

You may feel C<","> is ugly. In this case, you can use L</CSV>.

  use SQL::Concat qw/SQL PAR CSV/;

  SQL(SELECT =>
      , CSV(PAR(SELECT => "count(*)" => FROM => "foo")
           , PAR(SELECT => "count(*)" => FROM => "bar"))
  )
  # SQL: SELECT (SELECT count(*) FROM foo), (SELECT count(*) FROM bar)

You may want to use other separator to compose "UNION" query. For this,
use L</CAT>. This will be useful to compose AND/OR too.

  use SQL::Concat qw/SQL CAT/;

  CAT(UNION =>
      , SQL(SELECT => "*" => FROM => "foo")
      , SQL(SELECT => "*" => FROM => "bar"))
  )
  # SQL: SELECT * FROM foo UNION SELECT * FROM bar

To construct SQL conditionally, you can use L<Ternary|perlop/ternary> operator
in L<list context|perlglossary/list context> as usual.

  SQL(SELECT => "*" => FROM => members =>
      ($name ? SQL(WHERE => ["name = ?", $name]) : ())
  )
  # SQL: SELECT * FROM members WHERE name = ?

  # (or when $name is empty)
  # SQL: SELECT * FROM members

You may feel above cumbersome. If so, you can try another helper L</OPT>
and L</PFX>.

  use SQL::Concat qw/SQL PFX OPT/;

  SQL(SELECT => "*" => FROM => members =>
      PFX(WHERE => OPT("name = ?", $name))
  )

=head2 Complex example

    use SQL::Concat qw/SQL PAR OPT CSV/;
  
    sub to_find_entries {
       my ($tags, $limit, $offset, $reverse) = @_;

       my $pager = OPT("limit ?", $limit, OPT("offset ?", $offset));
     
       my ($sql, @bind)
         = SQL(SELECT => CSV("datetime(ts, 'unixepoch', 'localtime') as dt"
                             , qw/eid path/)
               , FROM => entrytext =>
               , ($tags
                  ? SQL(WHERE => eid =>
                        IN => PAR(SELECT => eid =>
                                  FROM =>
                                  PAR(CAT("\nINTERSECT\n" => map {
                                    SQL(SELECT => DISTINCT => "eid, ts" =>
                                        FROM => entry_tag =>
                                        WHERE => tid =>
                                        IN => PAR(SELECT => tid =>
                                                  FROM => tag =>
                                                  WHERE => ["tag glob ?", lc($_)]))
                                  } @$tags))
                                  , "\nORDER BY"
                                  , CSV(map {$reverse ? "$_ desc" : $_} qw/ts eid/)
                                  , $pager))
                  : ())
               , "\nORDER BY"
               , CSV(map {$reverse ? "$_ desc" : $_} qw/fid feno/)
               , ($tags ? () :$pager)
             )->as_sql_bind;
       }


=head1 FUNCTIONS

=head2 C<< SQL( @ITEMS... ) >>
X<SQL>

Equiv. of

=over 4

=item * C<< SQL::Concat->concat( @ITEMS... ) >>

=item * C<< SQL::Concat->concat_by(' ', @ITEMS... ) >>

=item * C<< SQL::Concat->new(sep => ' ')->concat( @ITEMS... ) >>

=back

=head2 C<< CSV( @ITEMS... ) >>
X<CSV>

Equiv. of C<< SQL::Concat->concat_by(', ', @ITEMS... ) >>

Note: you can use "," anywhere in concat() items. For example,
you can write C<< SQL(SELECT => "x, y, z") >> instead of C<< SQL(SELECT => CSV(qw/x y z/)) >>.

=head2 C<< CAT($SEP, @ITEMS... ) >>
X<CAT>

Equiv. of C<< SQL::Concat->concat_by($SEP, @ITEMS... ) >>, except
C<$SEP> is wrapped by whitespace when necessary.

XXX: Should I use C<"\n"> as wrapping char instead of C<" ">?

=head2 C<< PAR( @ITEMS... ) >>
X<PAR>

Equiv. of C<< SQL( ITEMS...)->paren >>

=head2 C<< PFX($ITEM, @OTHER_ITEMS...) >>
X<PFX>

Prefix C<$ITEM> only when C<@OTHER_ITEMS> are not empty.
Usually used like C<< PFX(WHERE => ...conditional...) >>.

=head2 C<< OPT(RAW_SQL, VALUE, @OTHER_ITEMS...) >>
X<OPT>

If VALUE is defined, C<< (SQL([$RAW_SQL, $VALUE]), @OTHER_ITEMS) >> are returned. Otherwise empty list is returned.

This is designed to help generating C<"LIMIT ? OFFSET ?">.

=head1 METHODS

=head2 C<< SQL::Concat->new(%args) >>
X<new>

Constructor, inherited from L<MOP4Import::Base::Configure>.

=head3 Options

Following options has their getter.
To set these options after new,
use L<MOP4Import::Base::Configure/configure> method.

=over 4

=item sep
X<sep>

Separator, used in L</concat>.

=item sql
X<sql>

SQL, constructed when L</concat> is called.
Once set, you are not allowed to call L</concat> again.

=item bind
X<bind>

Bind variables, constructed when L</BIND_ARRAY> is given to L</concat>.

=back


=head2 C<< SQL::Concat->concat( @ITEMS... ) >>
X<concat>

Central operation of SQL::Concat. It basically does:

  $self->{bind} = [];
  foreach my MY $item (@_) {
    next unless defined $item;
    if (not ref $item) {
      push @sql, $item;
    } else {
      my ($s, @b) = ref $item eq 'ARRAY'
	? @$item : ($item->{sql}, @{$item->{bind}});
      push @sql, $s;
      push @{$self->{bind}}, @b;
    }
  }
  $self->{sql} = join($self->{sep}, @sql);


=head2 C<< SQL::Concat->concat_by($SEP, @ITEMS) >>
X<concat_by>

Equiv. of C<< SQL::Concat->new(sep => $SEP)->concat( @ITEMS... ) >>

=head2 C< paren() >

Equiv. of C<< $obj->format('(%s)') >>.

=head2 C< format_by($FMT) >

Apply C<< sprintf($FMT, $self->{sql}) >>.
This will create a clone of $self.

=head2 C< as_sql_bind() >

Extract C<< $self->{sql} >> and C<< @{$self->{bind}} >>.
If caller is scalar context, wrap them with C<[]>.


=head1 LICENSE

Copyright (C) KOBAYASI, Hiroaki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

KOBAYASI, Hiroaki E<lt>hkoba @ cpan.orgE<gt>

=cut

