use Try::Tiny;

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

    if ( $latest->version ne $release->version ) {
        $release->update(
            {   failure => sprintf
                    'Version of most recent changelog (%s) does not match distribution version (%s)',
                $latest->version, $release->version
            }
        );
        return;
    }

    $release->update(
        {   changes_release_date => $latest->date,
            changes_for_release  => $latest->serialize
        }
    );

    return;
}

1;
