use strict;
use Test::Kantan;
use rlib;
use SQL::Concat qw/SQL PAR OPT CAT CSV/;

sub catch (&) {my ($code) = @_; local $@; eval {$code->()}; $@}

describe "Functional interfaces of SQL::Concat", sub {

  describe "SQL", sub {

    expect(SQL(SELECT => '*', FROM => 'foo')->sql)
      ->to_be("SELECT * FROM foo");
  };

  describe "PAR", sub {
    expect(PAR(SELECT => '*', FROM => 'foo')->sql)
      ->to_be("(SELECT * FROM foo)");
  };

  describe "CAT", sub {
    expect(CAT(UNION =>
	       SQL(SELECT => '*', FROM => 'x')
	       , SQL(SELECT => '*', FROM => 'y')
	       , SQL(SELECT => '*', FROM => 'z'))
	   ->sql)
      ->to_be("SELECT * FROM x UNION SELECT * FROM y UNION SELECT * FROM z");
    
    expect(CAT("\nINTERSECT\n" =>
	       SQL(SELECT => '*', FROM => 'x')
	       , SQL(SELECT => '*', FROM => 'y')
	       , SQL(SELECT => '*', FROM => 'z'))
	   ->sql)
      ->to_be("SELECT * FROM x
INTERSECT
SELECT * FROM y
INTERSECT
SELECT * FROM z");

  };
  
  describe "CSV", sub {

    expect(SQL(SELECT => CSV(foo => bar =>
			     "datetime(ts) as dt"))
	   ->sql)->to_be("SELECT foo, bar, datetime(ts) as dt");
  };

  describe "OPT", sub {

    expect([OPT("limit ?" => undef)])->to_be([]);
    expect([OPT("limit ?" => 100)->as_sql_bind])->to_be(["limit ?", 100]);
    expect([OPT("limit ?" => 100
		, OPT("offset ?", 3)
	      )->as_sql_bind])->to_be(["limit ? offset ?", 100, 3]);
    expect([OPT("limit ?" => 100
		, OPT("offset ?", undef)
	      )->as_sql_bind])->to_be(["limit ?", 100]);
    expect([OPT("limit ?" => undef
		, OPT("offset ?", 3)
	      )])->to_be([]);
    expect([SQL(OPT("limit ?" => undef
		    , OPT("offset ?", 3)
		  ))->as_sql_bind])->to_be(['']);
  };
};

done_testing;

