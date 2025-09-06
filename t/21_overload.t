#!/usr/bin/env perl
use strict;
use Test::Spec;

use rlib;

use SQL::Concat qw(SQL);

describe "concat - ", sub {

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
};

describe "bool - ", sub {

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
