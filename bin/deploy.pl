#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

use CPAN::Changes::Web;
use Dancer ':script';

CPAN::Changes::Web::schema( 'db' )->deploy;
