#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'MediaMogul';
all_from 'lib/MediaMogul.pm';

requires 'Catalyst::Runtime' => '5.80030';

requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Action::REST';

requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Authentication::Store::FromSub';

requires 'Moose';
requires 'MooseX::Storage';

requires 'namespace::autoclean';

requires 'Catalyst::View::TT';

requires 'MongoDB';

requires 'YAML';

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
