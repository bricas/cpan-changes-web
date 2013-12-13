#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';

require 'bin/_validate.pl';

$|++;

use CPAN::Changes::Web;
use Dancer ':script';
use CPAN::Changes;
use CPAN::Mini::Visit;
use CPAN::DistnameInfo;
use Getopt::Long;
use CPAN::Meta;

GetOptions(
    'resume|r'       => \my $resume,
    'force|f'        => \my $force,
    'minicpan|m=s'   => \my $minicpan,
    'visitopts|vo=s' => \my %visitopts,
);

my $schema = CPAN::Changes::Web::schema( 'db' );
my $scan = $schema->resultset( 'Scan' )->first;

if ( !$scan || !$resume ) {
    $scan = $schema->resultset( 'Scan' )
        ->create( { cpan_changes_version => $CPAN::Changes::VERSION } );
}
else {
    $scan->update( { cpan_changes_version => $CPAN::Changes::VERSION } );
}

my $release_rs = $schema->resultset( 'Release' );
my $release;
my $counter = 0;

CPAN::Mini::Visit->new(
    minicpan   => $minicpan || undef,
    callback   => \&parse_dist,
    ignore     => [ \&skip_existing ],
    prefer_bin => 1,
    %visitopts,
)->run;

print "\n";
print "Cleaning old scans...";

$schema->resultset( 'Scan' )->search( { id => { '!=' => $scan->id } } )->delete_all;

print "Done\n";

$scan->update( { is_running => 0 } );

sub skip_existing {
    my $job = shift;
    printf "\r[%05d] %-71.71s", ++$counter, $job->{ dist };

    my $distinfo = CPAN::DistnameInfo->new( $job->{ dist } );
    $release = $release_rs->find_or_new(
        {   distribution   => $distinfo->dist,
            author         => $job->{ author },
            version        => $distinfo->version || 'undef', # e.g. BCARROLL/Tk-GraphMan.zip
            dist_timestamp => DateTime->from_epoch( epoch => ( stat( $job->{ archive } ) )[ 9 ] ),
        },
        { key => 'release_key' }
    );

    my $exists = $release->in_storage;

    if( !$exists ) {
        $release->insert;
        my $prev = $release_rs->search(
            {
                distribution => $release->distribution,
                version => { '!=' => $release->version } },
            { order_by => 'ctime desc' }
        )->first;

        if( $prev ) {
            $release->update( { previous_changes_fulltext => $prev->changes_fulltext } );
        }
    }

    # use eval to ignore possible errors via resume or forced reparsing
    eval { $scan->add_to_releases( $release ); };

    return ( !$exists || $force ) ? 0 : 1;
}

sub parse_dist {
    my $job = shift;

    my ( $metafile ) = glob( 'META.*' );
    if( $metafile && ( my $meta = eval { CPAN::Meta->load_file( $metafile ) } ) ) {
        $release->abstract( strip_pod( $meta->abstract ) );
    }    

    if ( !-f 'Changes' ) {
        $release->update( { failure => 'No "Changes" file found.' } );
        return;
    }

    $release->changes_fulltext( slurp( 'Changes' ) );

    validate_changes( $release );
}

# From MetaCPAN::Util
sub strip_pod {
    my $pod = shift;
    $pod =~ s/L<([^\/]*?)\/([^\/]*?)>/$2 in $1/g;
    $pod =~ s/\w<(.*?)(\|.*?)?>/$1/g;
    return $pod;
}

sub slurp {
    open( my $fh, '<', shift ) or die $!;
    my $content = do { local $/; <$fh> };
    close( $fh );
    return $content;
}
