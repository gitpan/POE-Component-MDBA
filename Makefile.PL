use strict;
use inc::Module::Install;

name('POE-Component-MDBA');
license('perl');
requires('Class::Accessor::Fast');
requires('Data::Dumper');
requires('DBI');
requires('Digest::MD5');
requires('POE');
requires('POE::Component::Generic');

&auto_headers;
&auto_install;

&WriteAll;