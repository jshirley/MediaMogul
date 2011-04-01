#!/bin/sh

curl -L http://xrl.us/perlbrewinstall | bash

~/perl5/perlbrew/bin/perlbrew init

echo source ~/perl5/perlbrew/etc/bashrc >> ~/.bashrc

source ~/perl5/perlbrew/etc/bashrc

perlbrew install perl-5.12.1

perlbrew switch perl-5.12.1

curl -L http://cpanmin.us | perl - App::cpanminus

cpanm Module::Install

git clone https://github.com/jshirley/MediaMogul.git

cd MediaMogul

cpanm --installdeps .
