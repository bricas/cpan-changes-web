use Try::Tiny;

use CPAN::Changes;
use version ();

sub validate_changes {
    my( $release ) = shift;

    return unless $release->changes_fulltext;

    $release->failure( undef );
    $release->changes_release_date( undef );
    $release->changes_for_release( undef );

    my $changes = try {
        local $SIG{ __WARN__ } = sub { };    # ignore warnings
        CPAN::Changes->load_string( $release->changes_fulltext );
    }
    catch {
        $release->update( { failure => "Parse error: $_" } );
        return;
    };

    return unless $changes;

    my @releases = reverse( $changes->releases );
    my $latest   = $releases[ 0 ];

    if ( !$latest ) {
        $release->update(
            { failure => 'No releases found in "Changes" file' } );
        return;
    }

    my $latest_ver = _parse_version( $latest->version );
    if( !defined $latest_ver ) {
        $release->update(
            {   failure => sprintf
                    'Version of most recent changelog (%s) is not a valid version',
                $latest->version
            }
        );
        return;
    }

    my $release_ver = _parse_version( $release->version );
    if( !defined $release_ver ) {
        $release->update(
            {   failure => sprintf
                    'Version of the distribution (%s) is not a valid version',
                $release->version
            }
        );
        return;
    }

    if ( $latest_ver != $release_ver ) {
        $release->update(
            {   failure => sprintf
                    'Version of most recent changelog (%s) does not match distribution version (%s)',
                $latest->version, $release->version
            }
        );
        return;
    }

    # Check all dates
    for( map { $_->date } @releases ) {
        if ( !$_ or $_ !~ m{^${CPAN::Changes::W3CDTF_REGEX}\s*$} ) {
            $release->update(
                {   failure => sprintf
                        'Changelog release date (%s) does not look like a W3CDTF',
                    $_ || ''
                }
            );
            return;
        }
    }

    $release->update(
        {   changes_release_date => $latest->date,
            changes_for_release  => $latest->serialize
        }
    );

    return;
}

sub _parse_version {
    my $v = shift;
    local $SIG{ __WARN__ } = sub {};
    return eval { version->parse( $v ) };
}

1;
