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


