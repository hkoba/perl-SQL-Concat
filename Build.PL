use strict;
use warnings;
use Module::Build::Pluggable 'CPANfile';
use FindBin;

my $builder = Module::Build::Pluggable->new
  (module_name       => 'SQL::Concat'
   , dist_version_from   => 'lib/SQL/Concat.pm'
   , dist_author           => q{KOBAYASHI, Hiroaki <hkoba@cpan.org>},
   , license => 'perl'
 );

$builder->create_build_script();
