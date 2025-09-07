#!/usr/bin/env perl
use strict;
use Test::Spec;

use rlib;

use SQL::Concat qw(SQL WHERE OPT);

describe "eq: ", sub {
  it "SQL() eq SQL()", sub {
    ok(SQL() eq SQL());
  };
  it "SQL() eq ''", sub {
    ok(SQL() eq '');
  };
  it "'' eq SQL()", sub {
    ok('' eq SQL());
  };
  it "SQL() ne undef", sub {
    ok(SQL() ne undef);
  };
  it "SQL(' ') eq ' '", sub {
    ok(SQL(' ') eq ' ');
  };
  it "SQL(' ') ne ''", sub {
    ok(SQL(' ') ne '');
  };

  it "SQL(['']) eq SQL([''])", sub {
    ok(SQL(['']) eq SQL(['']));
  };

  it "SQL(['select ?', 1]) eq ['select ?', 1]", sub {
    ok(SQL(['select ?', 1]) eq ['select ?', 1]);
  };

  it "SQL(['select ?', 1]) ne ['select ?', 1, 2]", sub {
    ok(SQL(['select ?', 1]) ne ['select ?', 1, 2]);
  };

  it "SQL(['select ? is null', undef]) eq ['select ? is null', undef]", sub {
    local $SIG{__WARN__} = sub {die @_};
    ok(SQL(['select ? is null', undef]) eq ['select ? is null', undef]);
  };

};

describe "concat: ", sub {

  describe "SQL('select') . 1", sub {
    my $cat = SQL("select") . 1;

    it "should return 'select 1'", sub {
      is($cat->sql
         , "select 1");
    };
  };

  describe "'select' . SQL(1)", sub {
    my $cat = "select" . SQL(1);
    it "should return 'select 1'", sub {
      is($cat->sql
         , "select 1");
    };
  };

  describe "'select * from user' . WHERE()", sub {
    my $test = sub {
      my ($minAge) = @_;
      my $q = 'select * from user';
      $q . WHERE(
        OPT("age >= ?", $minAge || undef)
      );
    };

    it "should return 'select * from user' when minAge is undef", sub {
      is($test->()
         , 'select * from user');
    };

    it "should return 'select * from user WHERE age >= ?' when minAge is 18", sub {
      is($test->(18)
         , ['select * from user WHERE age >= ?', 18]);
    };

  };
};

describe "bool: ", sub {

  describe "SQL()", sub {

    my $cat = SQL();

    it "should be falsy", sub {

      is(!!$cat, !!0);
    };
  };

  describe "SQL('')", sub {

    my $cat = SQL('');

    it "should be falsy", sub {

      is(!!$cat, !!0);
    };
  };

  describe "SQL(1)", sub {

    my $cat = SQL(1);

    it "should be truthy", sub {

      is(!!$cat, 1);
    };
  };

  describe "SQL(0)", sub {

    my $cat = SQL(0);

    it "should be truthy!(since it is a nonempty string)", sub {

      is(!!$cat, 1);
    };
  };

};

runtests unless caller;
