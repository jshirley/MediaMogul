#!/usr/bin/env perl

use warnings;
use strict;

use FindBin;
use FCGI::Engine::Manager;

my $m = FCGI::Engine::Manager->new( conf => "$FindBin::Bin/fastcgi.yml" );

my ( $command, $server_name ) = @ARGV;

$m->start($server_name)        if $command eq 'start';
$m->stop($server_name)         if $command eq 'stop';
$m->restart($server_name)      if $command eq 'restart';
$m->graceful($server_name)     if $command eq 'graceful';

print $m->status($server_name) if $command eq 'status';
