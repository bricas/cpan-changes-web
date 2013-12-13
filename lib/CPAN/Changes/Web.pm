package CPAN::Changes::Web;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use XML::Atom::SimpleFeed;
use HTML::Entities ();
use CPAN::Changes  ();
use Try::Tiny;
use Text::Diff ();

our $VERSION = '0.1';

hook before => sub {
    var scan => schema( 'db' )->resultset( 'Scan' )->latest;
};

hook before_template => sub {
    my $tokens = shift;
    $tokens->{ self_uri } = URI->new_abs( request->uri, request->base );
    $tokens->{ scan } = vars->{ scan };
    $tokens->{ title } ||= vars->{ title } || '';
};

get '/' => sub {
    my $dists = vars->{ scan }->distributions;
    my $pass  = $dists->passes->count;
    my $fail  = $dists->failures->count;

    template 'index',
        {
        dist_uri        => uri_for( '/dist' ),
        author_uri      => uri_for( '/author' ),
        authors         => $dists->search( {}, { group_by => 'author' } )->count,
        dists           => $pass + $fail,
        dists_pass      => $pass,
        dists_fail      => $fail,
        dists_progress  => int( $pass / ( $pass + $fail ) * 100 ),
        recent_releases => scalar $dists->recent,
        };
};

get '/news' => sub {
    var title => 'News';
    template 'news', { show_all => 1 };
};

get '/author' => sub {
    var title => 'Authors';
    template 'author/index',
        {
        author_uri       => uri_for( '/author' ),
        current_page     => params->{ page },
        entries_per_page => 1000,
        authors          => vars->{ scan }->distributions->authors
        };
};

get '/author/:id' => sub {
    my $dists = vars->{ scan }->distributions( { author => params->{ id } } );

    if ( !$dists->count ) {
        return send_error( 'Not Found', 404 );
    }

    my $pass = $dists->passes->count;
    my $fail = $dists->failures->count;

    my $author_info = $dists->authors->first;

    var title => $author_info->name;

    template 'author/id', {
        dist_uri     => uri_for( '/dist' ),
        dists        => $dists,
        pass         => $pass,
        fail         => $fail,
        progress     => int( $pass / ( $pass + $fail ) * 100 ),
        author_info  => $author_info,
        header_links => [
            {   rel   => 'alternate',
                type  => 'application/atom+xml',
                title => 'Distributions by ' . params->{ id },
                href  => uri_for( '/author/' . params->{ id } . '/feed' )
            }
            ]

    };
};

get '/author/:id/feed' => sub {
    my $dists = vars->{ scan }->distributions( { author => params->{ id } },
        { order_by => 'dist_timestamp DESC' } );
    $dists = _handle_feed_filter( $dists );

    if ( !$dists->count ) {
        return send_error( 'Not Found', 404 );
    }

    my $author_info = $dists->authors->first;

    my $feed = XML::Atom::SimpleFeed->new(
        title => 'Distributions by ' . $author_info->name,
        link  => uri_for( '/' ),
        link  => {
            rel  => 'self',
            href => uri_for( '/author/' . params->{ id } . '/feed' ),
        },
        updated => $dists->first->dist_timestamp . 'Z',
        author  => 'CPAN::Changes Kwalitee Service',
        id      => uri_for( '/author/' . params->{ id } . '/feed' ),
    );

    _releases_to_entries( $feed, $dists );

    content_type( 'application/atom+xml' );
    return $feed->as_string;
};

get '/dist' => sub {
    var title => 'Distributions';
    template 'dist/index',
        {
        dist_uri         => uri_for( '/dist' ),
        current_page     => params->{ page },
        entries_per_page => 1000,
        distributions    => [
            vars->{ scan }->distributions( {}, { group_by => 'distribution' } )
                ->get_column( 'distribution' )->all
        ]
        };
};

get '/dist/:dist/feed' => sub {
    my $releases
        = vars->{ scan }->distributions( { distribution => params->{ dist } } );
    $releases = _handle_feed_filter( $releases );

    if ( !$releases->count ) {
        return send_error( 'Not Found', 404 );
    }

    my $feed = XML::Atom::SimpleFeed->new(
        title => 'Releases for ' . params->{ dist },
        link  => uri_for( '/' ),
        link  => {
            rel  => 'self',
            href => uri_for( '/dist/' . params->{ dist } . '/feed' ),
        },
        updated => $releases->first->dist_timestamp . 'Z',
        author  => 'CPAN::Changes Kwalitee Service',
        id      => uri_for( '/dist/' . params->{ dist } . '/feed' ),
    );

    _releases_to_entries( $feed, $releases );

    content_type( 'application/atom+xml' );
    return $feed->as_string;

};

get '/dist/:dist/json' => sub {
    my $release
        = vars->{ scan }->distributions( { distribution => params->{ dist } } )
        ->first;

    if ( !$release ) {
        return send_error( 'Not Found', 404 );
    }

    content_type( 'application/json' );

    return to_json( { error => $release->failure } ) if $release->failure;
    return to_json(
        [   map {
                { %$_ }
                } reverse( $release->as_changes_obj->releases )
        ]
    );

};

get '/dist/:dist' => \&_show_release;
get '/dist/:dist/:version?' => \&_show_release;

sub _show_release {
    my %search = ( distribution => params->{ dist } );
    if( params->{ version } ) {
        $search{ version } = params->{ version };
    }

    my $release = vars->{ scan }->distributions( \%search )->first;

    if ( !$release ) {
        return send_error( 'Not Found', 404 );
    }

    var title => sprintf( '%s %s (%s)',
        params->{ dist },
        $release->version,
        $release->author );

    my %tt = (
        author_uri   => uri_for( '/author' ),
        dist_uri     => uri_for( '/dist' ),
        release      => $release,
        header_links => [
            {   rel   => 'alternate',
                type  => 'application/atom+xml',
                title => 'Releases for ' . params->{ dist },
                href  => uri_for( '/dist/' . params->{ dist } . '/feed' )
            }
        ]
    );

    unless ( $release->failure ) {
        $tt{ reformatted } = $release->as_changes_obj->serialize;
        $tt{ diff }        = Text::Diff::diff( \$release->changes_fulltext,
            \$tt{ reformatted } );
    }

    template 'dist/release', \%tt;
};

get '/search' => sub {
    var title => 'Search';

    my $search = params->{ q };

    if( !$search ) {
        return template 'search/index', {};
    }

    if ( params->{ t } eq 'dist' ) {
        var title => 'Search Distributions';
        template 'dist/index',
            {
            entries_per_page => 250,
            current_page     => params->{ page },
            dist_uri         => uri_for( '/dist' ),
            distributions    => [
                vars->{ scan }->distributions(
                    { distribution => { 'like', "%$search%" } },
                    {   group_by => 'distribution',
                        order_by => 'lower(distribution)'
                    }
                    )->get_column( 'distribution' )->all
            ]
            };
    }
    else {
        var title => 'Search Authors';
        template 'author/index',
            {
            entries_per_page => 250,
            current_page     => params->{ page },
            author_uri       => uri_for( '/author' ),
            authors          => vars->{ scan }->distributions->authors->search_rs(
                {   -or => {
                        'author_info.id'   => { 'like', "%$search%" },
                        'author_info.name' => { 'like', "%$search%" },
                    }
                }
            )
            };
    }
};

get '/hof' => sub {
    var title => 'Hall of Fame';
    my $scan  = vars->{ scan };
    my $total = $scan->distributions->authors->count;
    my $hof   = $scan->hall_of_fame_authors;
    my $pass  = $hof->count;

    template 'hof/index',
        {
        author_uri => uri_for( '/author' ),
        authors    => $hof,
        pass       => $pass,
        percent    => int( $pass / $total * 100 )
        };
};

get '/validate' => sub {
    var title => 'Validation Tools';
    template 'validate/index', {};
};

post '/validate' => sub {
    my $fulltext = params->{ c };

    return redirect '/validate' unless $fulltext;

    var title => 'Validation Results';

    my $changes = try {
        local $SIG{ __WARN__ } = sub { };    # ignore warnings
        CPAN::Changes->load_string( $fulltext );
    }
    catch {
        return template( 'validate/result',
            { failure => "Parse error: $_", } );
    };

    return $changes unless ref $changes;

    my @releases = reverse( $changes->releases );
    my $latest   = $releases[ 0 ];

    if ( !$latest ) {
        return template( 'validate/result',
            { failure => 'No releases found in "Changes" file' } );
    }

    # Check all dates
    for ( map { $_->date } @releases ) {
        if ( !$_ or $_ !~ m{^${CPAN::Changes::W3CDTF_REGEX}\s*$} ) {
            return template(
                'validate/result',
                {   failure => sprintf
                        'Changelog release date (%s) does not look like a W3CDTF',
                    $_ || ''
                }
            );
        }
    }

    my $reformatted = $changes->serialize;
    template(
        'validate/result',
        {   original    => $fulltext,
            reformatted => $reformatted,
            diff        => Text::Diff::diff( \$fulltext, \$reformatted )
        }
    );
};

get '/recent/feed' => sub {
    my $releases = vars->{ scan }->distributions->recent;
    $releases = _handle_feed_filter( $releases );

    my $feed = XML::Atom::SimpleFeed->new(
        title   => 'Recent Releases',
        link    => uri_for( '/' ),
        link    => { rel => 'self', href => uri_for( '/recent/feed' ), },
        updated => $releases->first->dist_timestamp . 'Z',
        author  => 'CPAN::Changes Kwalitee Service',
        id      => uri_for( '/recent/feed' ),
    );

    $releases->reset;

    _releases_to_entries( $feed, $releases );

    content_type( 'application/atom+xml' );
    return $feed->as_string;
};

sub _handle_feed_filter {
    my( $rs ) = @_;

    return $rs unless my $filter = params->{ filter };

    if( $filter eq 'fail' ) {
        $rs = $rs->failures;
    }
    elsif( $filter eq 'pass' ) {
        $rs = $rs->passes;
    }

    return $rs;
}

sub _releases_to_entries {
    my ( $feed, $releases ) = @_;

    $releases->reset;

    while ( my $release = $releases->next ) {
        my( $tmpl, @args );

        if( $release->failure ) {
            $tmpl = '<pre style="color:red">ERROR: %s</pre><p>Diff from previous:</p><pre>%s</pre>';
            @args = ( $release->failure, $release->text_diff_from() );
        }
        else {
            $tmpl = '<pre>%s</pre>';
            @args = $release->changes_for_release || '';
        }

        my $content = sprintf( $tmpl, map { HTML::Entities::encode_entities $_ } @args );

        if( my $abstract = $release->abstract ) {
            $content = sprintf( '<p>%s</p>', HTML::Entities::encode_entities $abstract ) . $content;
        }

        my $link    = uri_for(
            '/'
                . join(
                '/', 'dist', $release->distribution, $release->version
                )
        );

        $feed->add_entry(
            title => sprintf( '[%s] %s %s (%s)',
                uc( $release->status_text ), $release->distribution, $release->version,
                $release->author ),
            link    => $link,
            summary => {
                type    => 'html',
                content => $content,
            },
            updated => $release->dist_timestamp . 'Z',
            id      => $link,
            author  => {
                name  => $release->author,
                email => sprintf( '<%s@cpan.org>', lc $release->author ),
            },
        );
    }
}

true;
