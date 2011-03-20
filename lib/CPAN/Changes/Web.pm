package CPAN::Changes::Web;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Feed;
use DateTime;

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
        };
};

get '/author' => sub {
    template 'author/index',
        {
        title      => 'Authors',
        author_uri => uri_for( '/author' ),
        authors    => [
            vars->{ scan }->releases(
                {}, { group_by => 'author', order_by => 'author' }
                )->get_column( 'author' )->all
        ]
        };
};

get '/author/:id' => sub {
    my $releases = vars->{ scan }->releases( { author => params->{ id } } );
    my $pass = $releases->passes->count;
    my $fail = $releases->failures->count;

    template 'author/id',
        {
        title    => params->{ id },
        dist_uri => uri_for( '/dist' ),
        releases => $releases,
        pass     => $pass,
        fail     => $fail,
        progress => int( $pass / ( $pass + $fail ) * 100 )
        };
};

get '/dist' => sub {
    template 'dist/index',
        {
        title    => 'Distributions',
        dist_uri => uri_for( '/dist' ),
        distributions    => [
            vars->{ scan }->releases(
                {}, { group_by => 'distribution' }
                )->get_column( 'distribution' )->all
        ]
        };
};

get '/dist/:dist' => sub {
    my $releases = vars->{ scan }->releases( { distribution => params->{ dist } } );
    my $pass = $releases->passes->count;
    my $fail = $releases->failures->count;

    template 'dist/dist',
        {
        title      => params->{ dist },
        author_uri => uri_for( '/author' ),
        releases => $releases,
        pass     => $pass,
        fail     => $fail,
        progress => int( $pass / ( $pass + $fail ) * 100 )
        };
};

get '/search' => sub {
    template 'search/index', { title => 'Search' };
};

post '/search' => sub {
    my $search = params->{q};

    if ( params->{t} eq 'dist' ) {
        template 'dist/index',
            {
            title    => 'Search Distributions',
            dist_uri => uri_for( '/dist' ),
            distributions    => [
                vars->{ scan }->releases(
                    {
                    distribution => { 'like', "%$search%"}
                    }, { group_by => 'distribution', order_by => 'distribution' }
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
                {
                author => { 'like', "%$search%"}
                }, { group_by => 'author', order_by => 'author' }
                )->get_column( 'author' )->all
        ]
        };
    }
};

get '/feed/:type/:format' => sub {
    my @elem = vars->{scan}->releases({}, 
        { 
        rows => 10, 
        order_by => { -desc =>'id' }
        })->get_column(params->{type})->all;
        
    my $type = params->{type} eq 'distribution' ? 'dist' : params->{type};

    my @format_feed = map { { 
        id       => "http://".time.rand()."/",
        title    => $_,
        content  => 'New ' . params->{type} . ': ' . $_,
        author   => 'CPAN::Changes web',
        link     => request->base . "$type/$_",
        modified => DateTime->now } } @elem;

    my $feed = create_feed(
        format      => params->{format},
        title       => 'CPAN::Changes web - ' . ucfirst(params->{type}),
        link        => request->base,
        description => 'The last ' . params->{type},
        entries     => \@format_feed,
    );

    return $feed;
};

true;
