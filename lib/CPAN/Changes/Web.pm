package CPAN::Changes::Web;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use XML::Atom::SimpleFeed;
use HTML::Entities ();
use CPAN::Changes  ();
use Try::Tiny;

our $VERSION = '0.1';

# From DateTime::Format::W3CDTF
my $date_re = qr{(\d\d\d\d) # Year
                 (?:-(\d\d) # -Month
                 (?:-(\d\d) # -Day
                 (?:T
                   (\d\d):(\d\d) # Hour:Minute
                   (?:
                     :(\d\d)     # :Second
                     (\.\d+)?    # .Fractional_Second
                   )?
                   ( Z          # UTC
                   | [+-]\d\d:\d\d    # Hour:Minute TZ offset
                     (?::\d\d)?       # :Second TZ offset
                 )?)?)?)?}x;

before sub {
    var scan => schema( 'db' )->resultset( 'Scan' )->first;
};

before_template sub {
    my $tokens = shift;
    $tokens->{ scan } = vars->{ scan };
    $tokens->{ title } ||= vars->{ title } || '';
};

get '/' => sub {
    my $releases = vars->{ scan }->releases;
    my $pass     = $releases->passes->count;
    my $fail     = $releases->failures->count;

    template 'index',
        {
        dist_uri => uri_for( '/dist' ),
        dists =>
            $releases->search( {}, { group_by => 'distribution' } )->count,
        author_uri => uri_for( '/author' ),
        authors  => $releases->search( {}, { group_by => 'author' } )->count,
        releases => $pass + $fail,
        releases_pass     => $pass,
        releases_fail     => $fail,
        releases_progress => int( $pass / ( $pass + $fail ) * 100 ),
        recent_releases   => scalar $releases->recent,
        };
};

get '/author' => sub {
    var title => 'Authors';
    template 'author/index',
        {
        author_uri       => uri_for( '/author' ),
        current_page     => params->{page}, 
        entries_per_page => 1000,
        authors          => [
            vars->{ scan }->releases( {},
                { group_by => 'author', order_by => 'author' } )
                ->get_column( 'author' )->all
        ]
        };
};

get '/author/:id' => sub {
    my $releases = vars->{ scan }->releases( { author => params->{ id } } );

    if ( !$releases->count ) {
        return send_error( 'Not Found', 404 );
    }

    my $pass = $releases->passes->count;
    my $fail = $releases->failures->count;

    var title => params->{ id };

    template 'author/id', {
        dist_uri     => uri_for( '/dist' ),
        releases     => $releases,
        pass         => $pass,
        fail         => $fail,
        progress     => int( $pass / ( $pass + $fail ) * 100 ),
        header_links => [
            {   rel   => 'alternate',
                type  => 'application/atom+xml',
                title => 'Releases by ' . params->{ id },
                href  => uri_for( '/author/' . params->{ id } . '/feed' )
            }
            ]

    };
};

get '/author/:id/feed' => sub {
    my $releases = vars->{ scan }->releases( { author => params->{ id } },
        { order_by => 'dist_timestamp DESC' } );

    if ( !$releases->count ) {
        return send_error( 'Not Found', 404 );
    }

    my $feed = XML::Atom::SimpleFeed->new(
        title => 'Releases by ' . params->{ id },
        link  => uri_for( '/' ),
        link  => {
            rel  => 'self',
            href => uri_for( '/author/' . params->{ id } . '/feed' ),
        },
        updated => $releases->first->dist_timestamp . 'Z',
        author  => 'CPAN::Changes Kwalitee Service',
        id      => uri_for( '/author/' . params->{ id } . '/feed' ),
    );

    _releases_to_entries( $feed, $releases );

    content_type( 'application/atom+xml' );
    return $feed->as_string;
};

get '/dist' => sub {
    var title => 'Distributions';
    template 'dist/index',
        {
        dist_uri         => uri_for( '/dist' ),
        current_page     => params->{page}, 
        entries_per_page => 1000,
        distributions    => [
            vars->{ scan }->releases( {}, { group_by => 'distribution' } )
                ->get_column( 'distribution' )->all
        ]
        };
};

get '/dist/:dist' => sub {
    my $releases
        = vars->{ scan }->releases( { distribution => params->{ dist } } );

    if ( !$releases->count ) {
        return send_error( 'Not Found', 404 );
    }

    my $pass = $releases->passes->count;
    my $fail = $releases->failures->count;

    var title => params->{ dist };

    template 'dist/dist',
        {
        author_uri   => uri_for( '/author' ),
        dist_uri     => uri_for( '/dist' ),
        releases     => $releases,
        pass         => $pass,
        fail         => $fail,
        progress     => int( $pass / ( $pass + $fail ) * 100 ),
        header_links => [
            {   rel   => 'alternate',
                type  => 'application/atom+xml',
                title => 'Releases for ' . params->{ dist },
                href  => uri_for( '/dist/' . params->{ dist } . '/feed' )
            }
        ]
        };
};

get '/dist/:dist/feed' => sub {
    my $releases
        = vars->{ scan }->releases( { distribution => params->{ dist } } );

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

get '/dist/:dist/:version' => sub {
    my $release
        = vars->{ scan }->releases( { distribution => params->{ dist }, version => params->{ version } } )->first;

    if ( !$release ) {
        return send_error( 'Not Found', 404 );
    }

    var title => sprintf( '%s %s (%s)', params->{ dist }, params->{ version }, $release->author );

    template 'dist/release',
        {
        author_uri   => uri_for( '/author' ),
        dist_uri     => uri_for( '/dist' ),
        release      => $release,
        };
};

get '/search' => sub {
    var title => 'Search';
    template 'search/index', {};
};

post '/search' => sub {
    my $search = params->{ q };

    if ( params->{ t } eq 'dist' ) {
        var title => 'Search Distributions';
        template 'dist/index',
            {
            dist_uri      => uri_for( '/dist' ),
            distributions => [
                vars->{ scan }->releases(
                    { distribution => { 'like', "%$search%" } },
                    {   group_by => 'distribution',
                        order_by => 'distribution'
                    }
                    )->get_column( 'distribution' )->all
            ]
            };
    }
    else {
        var title => 'Search Authors';
        template 'author/index',
            {
            author_uri => uri_for( '/author' ),
            authors    => [
                vars->{ scan }->releases(
                    { author => { 'like', "%$search%" } },
                    { group_by => 'author', order_by => 'author' }
                    )->get_column( 'author' )->all
            ]
            };
    }
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

    my ( $latest ) = reverse( $changes->releases );
    if ( !$latest ) {
        return template( 'validate/result',
            { failure => 'No releases found in "Changes" file' } );
    }
    if ( !$latest->date or $latest->date !~ m{^$date_re\s*$} ) {
        my $d = $latest->date || '';
        return template(
            'validate/result',
            {   failure =>
                    "Latest changelog release date (${d}) does not look like a W3CDTF"
            }
        );
    }

    template( 'validate/result', { changes => $changes } );
};

get '/recent/feed' => sub {
    my $releases = vars->{ scan }->releases->recent;

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

sub _releases_to_entries {
    my ( $feed, $releases ) = @_;

    $releases->reset;

    while ( my $release = $releases->next ) {
        my $tmpl
            = $release->failure
            ? '<pre style="color:red">ERROR: %s</pre>'
            : '<pre>%s</pre>';
        my $link = uri_for( '/' . join( '/', 'dist', $release->distribution, $release->version ) );

        $feed->add_entry(
            title => sprintf( '%s %s (%s)',
                $release->distribution, $release->version,
                $release->author ),
            link    => $link,
            summary => {
                type    => 'html',
                content => sprintf(
                    $tmpl,
                    HTML::Entities::encode_entities(
                               $release->failure
                            || $release->changes_for_release
                            || ''
                    )
                )
            },
            updated => $release->dist_timestamp . 'Z',
            id      => $link,
        );
    }
}

true;
