# -*- mode: perl -*-
requires perl => '5.010';

requires 'MOP4Import::Declare' => 0.002;

on build => sub {
  requires 'Module::Build::Pluggable';
  requires 'Module::CPANfile';
};

on 'test' => sub {
    requires 'Test::Kantan' => 0.40;
};
