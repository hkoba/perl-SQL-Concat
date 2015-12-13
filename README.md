# NAME

SQL::Concat - Zero knowledge SQL concatenator (with hidden bind variables)

# SYNOPSIS

```perl
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
```

# DESCRIPTION

SQL::Concat is yet another SQL generator for **minimalists**.
See [lib/SQL/Concat.pod](blob/master/lib/SQL/Concat.pod) for details.

# LICENSE

Copyright (C) KOBAYASI, Hiroaki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

KOBAYASI, Hiroaki &lt;buribullet@gmail.com>
