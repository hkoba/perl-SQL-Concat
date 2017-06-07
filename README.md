[![Build Status](https://travis-ci.org/hkoba/perl-SQL-Concat.svg?branch=master)](https://travis-ci.org/hkoba/perl-SQL-Concat)
# NAME

SQL::Concat - SQL concatenator, only cares about bind-vars, to write SQL generator

# SYNOPSIS

```perl
# Functional interface
use SQL::Concat qw/SQL PAR/;

my $composed = SQL(SELECT => "*" =>
                   FROM   => entries =>
                   WHERE  => ("uid =" =>
                              PAR(SQL(SELECT => uid => FROM => authors =>
                                      WHERE => ["name = ?", 'foo'])))
                 );

my ($sql, @bind) = $composed->as_sql_bind;
# ==>
# SQL: SELECT * FROM entries WHERE uid = (SELECT uid FROM authors WHERE name = ?)
# BIND: foo

# OO Interface
my $comp = SQL::Concat->new(sep => ' ')
  ->concat(SELECT => foo => FROM => 'bar');
```

# DESCRIPTION

SQL::Concat is **NOT** a _SQL generator_, but a minimalistic _SQL
fragments concatenator_ with safe bind-variable handling.  SQL::Concat
doesn't care anything about SQL but **placeholder** and
bind-variables. Other important topics to generate correct SQL
such as SQL syntaxes, SQL keywords, quotes, or even parens are
all remained your-side.

In other words, generating correct SQL is all up-to-you users of
SQL::Concat. If you don't (want to) learn about SQL, use other SQL
generators (e.g. [SQL::Maker](https://metacpan.org/pod/SQL::Maker), [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract), ...) instead.

This module only focuses on correctly concatenating SQL fragments
with keeping their corresponding bind variables.

## What concat() does is...

`join($SEP, @ITEMS)`! except it knows about bind variables and placeholders.
Default $SEP is a space character `' '` but you can give it as [sep => $sep](#sep) option
for [new()](#new)
or constructor argument like [SQL::Concat->concat\_by($SEP)](#concat_by).

- STRING

    Non-reference values are used just as resulting SQL as-is.
    This means each given strings are treated as **RAW** SQL fragment.
    If you want to use foreign values, you must use next ["BIND\_ARRAY"](#bind_array).

    ```perl
    use SQL::Concat qw/SQL/;

    SQL(SELECT => 1)->as_sql_bind;
    # SQL: "SELECT 1"
    # BIND: ()

    SQL(SELECT => 'foo, bar' => FROM => 'baz', "\nORDER BY bar")->as_sql_bind;
    # SQL: "SELECT foo, bar FROM baz
    #       ORDER BY bar"
    # BIND: ()
    ```

    Note: `SQL()` is just a shorthand of `SQL::Concat->new(sep => ' ')->concat( @ITEMS... )`. See [SQL()](#sql) for more equivalent examples.

- BIND\_ARRAY \[$RAW\_SQL, @BIND\]


    If item is ARRAY reference, it is treated as BIND\_ARRAY.
    The first element of BIND\_ARRAY is treated as RAW SQL.
    The rest of the elements are pushed into `->{bind}` array.
    This SQL fragment must contain same number of SQL-placeholders(`?`)
    with corresponding @BIND variables.

    ```
    SQL(["city = ?", 'tokyo'])->as_sql_bind
    # SQL: "city = ?"
    # BIND: ('tokyo')

    SQL(["age BETWEEN ? AND ?", 20, 65])->as_sql_bind
    # SQL: "age BETWEEN ? AND ?"
    # BIND: (20, 65)
    ```

- SQL::Concat


    Finally, concat() can accept SQL::Concat instances. In this case, `->{sql}` and `->{bind}` are extracted and treated just like ["BIND\_ARRAY"](#bind_array)

    ```perl
    SQL(SELECT => "*" =>
        FROM => members =>
        WHERE =>
        SQL(["city = ?", "tokyo"]),
        AND =>
        SQL(["age BETWEEN ? AND ?", 20, 65])
    )->as_sql_bind;
    # SQL: "SELECT * FROM members WHERE city = ? AND age BETWEEN ? AND ?"
    # BIND: ('tokyo', 20, 65)
    ```

## Helper methods/functions for complex SQL construction

To build complex SQL, we often need to put parens around some SQL fragments.
For example:

```perl
SQL(SELECT =>
    , SQL(SELECT => "count(*)" => FROM => "foo")
    , ","
    , SQL(SELECT => "count(*)" => FROM => "bar")
)
# (WRONG) SQL: SELECT SELECT count(*) FROM foo , SELECT count(*) FROM bar
```

Fortunately, SQL::Concat has [->paren()](#paren) method, so you can write

```perl
SQL(SELECT =>
    , SQL(SELECT => "count(*)" => FROM => "foo")->paren
    , ","
    , SQL(SELECT => "count(*)" => FROM => "bar")->paren
)
# SQL: SELECT (SELECT count(*) FROM foo) , (SELECT count(*) FROM bar)
```

Or you can use another function [PAR()](#par).

```perl
use SQL::Concat qw/SQL PAR/;

SQL(SELECT =>
    , PAR(SELECT => "count(*)" => FROM => "foo")
    , ","
    , PAR(SELECT => "count(*)" => FROM => "bar")
)
```

You may feel `","` is ugly. In this case, you can use [CSV()](#csv).

```perl
use SQL::Concat qw/SQL PAR CSV/;

SQL(SELECT =>
    , CSV(PAR(SELECT => "count(*)" => FROM => "foo")
         , PAR(SELECT => "count(*)" => FROM => "bar"))
)
# SQL: SELECT (SELECT count(*) FROM foo), (SELECT count(*) FROM bar)
```

You may want to use other separator to compose "UNION" query. For this,
use [CAT()](#cat). This will be useful to compose AND/OR too.

```perl
use SQL::Concat qw/SQL CAT/;

CAT(UNION =>
    , SQL(SELECT => "*" => FROM => "foo")
    , SQL(SELECT => "*" => FROM => "bar"))
)
# SQL: SELECT * FROM foo UNION SELECT * FROM bar
```

To construct SQL conditionally, you can use [Ternary](https://metacpan.org/pod/perlop#ternary) operator
in [list context](https://metacpan.org/pod/perlglossary#list-context) as usual.

```perl
SQL(SELECT => "*" => FROM => members =>
    ($name ? SQL(WHERE => ["name = ?", $name]) : ())
)
# SQL: SELECT * FROM members WHERE name = ?

# (or when $name is empty)
# SQL: SELECT * FROM members
```

You may feel above cumbersome. If so, you can try another helper [OPT()](#opt)
and [PFX()](#pfx).

```perl
use SQL::Concat qw/SQL PFX OPT/;

SQL(SELECT => "*" => FROM => members =>
    PFX(WHERE => OPT("name = ?", $name))
)
```

## Complex example

```perl
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
```

# FUNCTIONS

## `SQL( @ITEMS... )`


Equiv. of

- `SQL::Concat->concat( @ITEMS... )`
- `SQL::Concat->concat_by(' ', @ITEMS... )`
- `SQL::Concat->new(sep => ' ')->concat( @ITEMS... )`

## `CSV( @ITEMS... )`


Equiv. of `SQL::Concat->concat_by(', ', @ITEMS... )`

Note: you can use "," anywhere in concat() items. For example,
you can write `SQL(SELECT => "x, y, z")` instead of `SQL(SELECT => CSV(qw/x y z/))`.

## `CAT($SEP, @ITEMS... )`


Equiv. of `SQL::Concat->concat_by($SEP, @ITEMS... )`, except
`$SEP` is wrapped by whitespace when necessary.

XXX: Should I use `"\n"` as wrapping char instead of `" "`?

## `PAR( @ITEMS... )`


Equiv. of `SQL( ITEMS...)->paren`

## `PFX($ITEM, @OTHER_ITEMS...)`


Prefix `$ITEM` only when `@OTHER_ITEMS` are not empty.
Usually used like `PFX(WHERE => ...conditional...)`.

## `OPT(RAW_SQL, VALUE, @OTHER_ITEMS...)`


If VALUE is defined, `(SQL([$RAW_SQL, $VALUE]), @OTHER_ITEMS)` are returned. Otherwise empty list is returned.

This is designed to help generating `"LIMIT ? OFFSET ?"`.

# METHODS

## `SQL::Concat->new(%args)`


Constructor, inherited from [MOP4Import::Base::Configure](https://metacpan.org/pod/MOP4Import::Base::Configure).

### Options

Following options has their getter.
To set these options after new,
use ["configure" in MOP4Import::Base::Configure](https://metacpan.org/pod/MOP4Import::Base::Configure#configure) method.

- sep


    Separator, used in [concat()](#concat).

- sql


    SQL, constructed when [concat()](#concat) is called.
    Once set, you are not allowed to call ["concat"](#concat) again.

- bind


    Bind variables, constructed when ["BIND\_ARRAY"](#bind_array) is given to [concat()](#concat).

## `SQL::Concat->concat( @ITEMS... )`


Central operation of SQL::Concat. It basically does:

```perl
$self->{bind} = [];
foreach my MY $item (@_) {
  next unless defined $item;
  if (not ref $item) {
    push @sql, $item;
  } else {
    $item = SQL::Concat->of_bind_array($item)
      if ref $item eq 'ARRAY';

    $item->validate_placeholders;

    push @sql, $item->{sql};
    push @{$self->{bind}}, @{$item->{bind}};
  }
}
$self->{sql} = join($self->{sep}, @sql);
```

## `SQL::Concat->concat_by($SEP, @ITEMS)`


Equiv. of `SQL::Concat->new(sep => $SEP)->concat( @ITEMS... )`

## ` paren() `

Equiv. of `$obj->format('(%s)')`.

## ` format_by($FMT) `

Apply `sprintf($FMT, $self->{sql})`.
This will create a clone of $self.

## ` as_sql_bind() `

Extract `$self->{sql}` and `@{$self->{bind}}`.
If caller is scalar context, wrap them with `[]`.

# LICENSE

Copyright (C) KOBAYASI, Hiroaki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

KOBAYASI, Hiroaki &lt;hkoba @ cpan.org>
