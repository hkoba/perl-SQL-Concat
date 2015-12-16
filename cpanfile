# -*- mode: perl -*-
requires perl => '5.010';

requires 'rlib'; # XXX:

requires 'MOP4Import::Declare' => 0.003;

on build => sub {
  requires 'Module::Build::Pluggable';
  requires 'Module::CPANfile';
};

on 'test' => sub {
  # requires 'rlib';
  requires 'Test::Kantan' => 0.40;
};
