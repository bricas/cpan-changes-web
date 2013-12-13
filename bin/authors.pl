#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

$|++;

use CPAN::Changes::Web;
use Dancer ':script';
use Parse::CPAN::Authors;
use Getopt::Long;

GetOptions(
    'minicpan|m=s' => \my $minicpan,
);

my $schema  = CPAN::Changes::Web::schema( 'db' );
my @authors = $schema->resultset( 'Scan' )->latest->distributions( {}, { group_by => 'author', order_by => 'author' } )->get_column( 'author' )->all;
my $rs      = $schema->resultset( 'Author' );
my $p       = Parse::CPAN::Authors->new( "$minicpan/authors/01mailrc.txt.gz" );
my $counter = 0;

for my $author ( map { $p->author( $_ ) } @authors ) {
    printf "\r[%04d] %-50s", ++$counter, $author->pauseid;

    $rs->update_or_create( {
        id    => $author->pauseid,
        name  => $author->name,
        email => $author->email
    } );
}

print "\n";
