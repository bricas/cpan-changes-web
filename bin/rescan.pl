#!/usr/bin/env perl

use strict;
use warnings;

$|++;

use lib 'lib';

require 'bin/_validate.pl';

use CPAN::Changes::Web;
use Dancer ':script';
use CPAN::Changes;

my $schema = CPAN::Changes::Web::schema( 'db' );
my $scan = $schema->resultset( 'Scan' )->first;
$scan->update( { cpan_changes_version => $CPAN::Changes::VERSION } );

my $releases = $scan->releases;
my $count = 0;
while( my $release = $releases->next ) {
    printf "\r[%05d] %-71.71s", ++$count, $release->distribution;
    validate_changes( $release );
}

print "\n";
