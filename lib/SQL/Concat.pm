package SQL::Concat;
use 5.008001;
use strict;
use warnings;
use Carp;

our $VERSION = "0.01";

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

SQL::Concat is SQL generator for minimalists.
This module only focuses on correctly concatinating SQL fragments
with keeping their corresponding bind variables.
Other nasty but important topics about SQL syntaxes, quotes or even keywords
are all remained untouched to your side. In other words, if you don't (want to)
learn about SQL, use other SQL generators (e.g. L<SQL::Maker>, L<SQL::QueryMaker>, ...) instead.




    # Complex example;
    use SQL::Concat qw/SQL PAR OPT CSV/;
  
    sub to_find_entries {
       my ($tags, $limit, $offset) = @_;

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
                                  , CSV("ts desc", "eid desc")
                                  , $pager))
                  : ())
               , "\nORDER BY"
               , CSV("fid desc", "feno desc")
               , ($tags ? () :$pager)
             )->as_sql_bind;
       }


=head1 FUNCTIONS

=head2 C<< SQL( @ITEMS... ) >>
X<SQL>

Equiv. of C<< SQL::Concat->new(sep => ' ')->concat( @ITEMS... ) >>

=head2 C<< CSV( @ITEMS... ) >>
X<CSV>

Equiv. of C<< SQL::Concat->new(sep => ', ')->concat( @ITEMS... ) >>

=head2 C<< CAT($SEP, @ITEMS... ) >>
X<CAT>

Equiv. of C<< SQL::Concat->new(sep => $SEP)->concat( @ITEMS... ) >>

=head2 C<< PAR( @ITEMS... ) >>
X<PAR>

Equiv. of C<< SQL( ITEMS...)->paren >>

=head1 METHODS

=head2 C<< SQL::Concat->new(%args) >>
X<new>

=over 4

=item sep

Separator, used in L</concat>.

=item sql



=item bind

=back


=head2 C< concat( ITEMS... ) >
X<concat>

=over 4

=item STRING

=item ARRAY  [RAW_SQL, @BIND]

=item SQL::Concat

=back

=head2 C< paren() >

Equiv. of C<< $obj->format('(%s)') >>.

=head2 C< format_by($FMT) >

Apply C<< sprintf($FMT, $self->{sql}) >>. This will create a clone.

=head2 C< as_sql_bind() >


=head1 LICENSE

Copyright (C) KOBAYASI, Hiroaki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

KOBAYASI, Hiroaki E<lt>hkoba @ cpan.orgE<gt>

=cut

