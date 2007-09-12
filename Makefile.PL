use strict;
use inc::Module::Install;

name('POE-Component-MDBA');
all_from('lib/POE/Component/MDBA.pm');
license('perl');
requires('Class::Accessor::Fast');
requires('Class::Inspector');
requires('Data::Dumper');
requires('DBI');
requires('Digest::MD5');
requires('POE');
requires('POE::Component::Generic');

&auto_install;

&WriteAll;