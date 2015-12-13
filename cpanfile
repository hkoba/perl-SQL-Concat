# -*- mode: perl -*-
requires 'perl', '5.008001';

requires 'MOP4Import::Declare' => 0.002;

on 'test' => sub {
    requires 'Test::Kantan' => 0.40;
};
