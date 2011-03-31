package CPAN::Changes::Web;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use XML::Atom::SimpleFeed;
use HTML::Entities ();

our $VERSION = '0.1';

before sub {
    var scan => schema( 'db' )->resultset( 'Scan' )->first;
};

before_template sub {
    my $tokens = shift;
    $tokens->{ scan } = vars->{ scan };
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
    template 'author/index',
        {
        title      => 'Authors',
        author_uri => uri_for( '/author' ),
        authors    => [
            vars->{ scan }->releases( {},
                { group_by => 'author', order_by => 'author' } )
                ->get_column( 'author' )->all
        ]
        };
};

get '/author/:id' => sub {
    my $releases = vars->{ scan }->releases( { author => params->{ id } } );

    if( !$releases->count ) {
        return send_error( 'Not Found', 404 );
    }

    my $pass     = $releases->passes->count;
    my $fail     = $releases->failures->count;

    template 'author/id', {
        title        => params->{ id },
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

    if( !$releases->count ) {
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
    template 'dist/index',
        {
        title         => 'Distributions',
        dist_uri      => uri_for( '/dist' ),
        distributions => [
            vars->{ scan }->releases( {}, { group_by => 'distribution' } )
                ->get_column( 'distribution' )->all
        ]
        };
};

get '/dist/:dist' => sub {
    my $releases
        = vars->{ scan }->releases( { distribution => params->{ dist } } );

    if( !$releases->count ) {
        return send_error( 'Not Found', 404 );
    }

    my $pass = $releases->passes->count;
    my $fail = $releases->failures->count;

    template 'dist/dist',
        {
        title        => params->{ dist },
        author_uri   => uri_for( '/author' ),
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

    if( !$releases->count ) {
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

get '/search' => sub {
    template 'search/index', { title => 'Search' };
};

post '/search' => sub {
    my $search = params->{ q };

    if ( params->{ t } eq 'dist' ) {
        template 'dist/index',
            {
            title         => 'Search Distributions',
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
        template 'author/index',
            {
            title      => 'Search Authors',
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
        $feed->add_entry(
            title => sprintf( '%s %s (%s)',
                $release->distribution, $release->version,
                $release->author ),
            link    => uri_for( '/dist/' . $release->distribution ),
            summary => {
                type    => 'html',
                content => sprintf(
                    $tmpl,
                    HTML::Entities::encode_entities(
                        $release->failure || $release->changes_for_release || ''
                    )
                )
            },
            updated => $release->dist_timestamp . 'Z',
            id      => uri_for( '/dist/' . $release->distribution ),
        );
    }
}

true;
