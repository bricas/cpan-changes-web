#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use CPAN::Changes::Web;
use Dancer ':script';
use CPAN::Changes;
use CPAN::Mini::Visit;
use CPAN::DistnameInfo;
use Try::Tiny;
use Getopt::Long;

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

CPAN::Mini::Visit->new(
    minicpan => $minicpan || undef,
    callback => \&parse_changelogs,
    %visitopts,
)->run;

print "\n";

sub parse_changelogs {
    my $job = shift;
    printf "\r[%05d] %-71.71s", $job->{ counter }, $job->{ dist };

    my $distinfo = CPAN::DistnameInfo->new( $job->{ dist } );

    my $release = $schema->resultset( 'Release' )->find_or_new(
        {   distribution   => $distinfo->dist,
            author         => $job->{ author },
            version        => $distinfo->version || 'undef', # e.g. BCARROLL/Tk-GraphMan.zip
            dist_timestamp => DateTime->from_epoch( epoch => ( stat( $job->{ archive } ) )[ 9 ] ),
        },
        { key => 'release_key' }
    );
    my $exists = $release->in_storage;
    $release->insert if !$exists;

    # use eval to ignore possible errors via resume or forced reparsing
    eval { $scan->add_to_releases( $release ); };

    return unless !$exists || $force;

    if ( !-f 'Changes' ) {
        $release->update( { failure => 'No "Changes" file found.' } );
        return;
    }

    $release->changes_fulltext( slurp( 'Changes' ) );

    my $changes = try {
        local $SIG{ __WARN__ } = sub { };    # ignore warnings
        CPAN::Changes->load_string( $release->changes_fulltext );
    }
    catch {
        $release->update( { failure => "Parse error: $_" } );
        return;
    };

    return unless $changes;

    my ( $latest ) = reverse( $changes->releases );
    if ( !$latest ) {
        $release->update(
            { failure => 'No releases found in "Changes" file' } );
        return;
    }

    if ( !$latest->date or $latest->date !~ m{^\d{4}-\d{2}-\d{2}} ) {
        $release->update(
            {   failure => sprintf
                    'Latest changelog release date (%s) does not look like a W3CDTF',
                $latest->date || ''
            }
        );
        return;
    }

    if ( $latest->version ne $distinfo->version ) {
        $release->update(
            {   failure => sprintf
                    'Version of most recent changelog (%s) does not match distribution version (%s)',
                $latest->version, $distinfo->version
            }
        );
        return;
    }

    $release->update(
        {   changes_release_date => $latest->date,
            changes_for_release  => $latest->serialize
        }
    );
}

sub slurp {
    open( my $fh, '<', shift ) or die $!;
    my $content = do { local $/; <$fh> };
    close( $fh );
    return $content;
}
