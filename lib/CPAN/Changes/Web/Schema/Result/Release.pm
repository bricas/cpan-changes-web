package CPAN::Changes::Web::Schema::Result::Release;

use strict;
use warnings;

use base qw( DBIx::Class );

use CPAN::Changes;
use Text::Diff ();

__PACKAGE__->load_components( qw( TimeStamp Core ) );
__PACKAGE__->table( 'distribution_release' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    distribution => {
        data_type   => 'varchar',
        size        => 180,
        is_nullable => 0,
    },
    author => {
        data_type   => 'varchar',
        size        => 50,
        is_nullable => 0,
    },
    version => {
        data_type   => 'varchar',
        size        => 25,
        is_nullable => 0,
    },
    dist_timestamp => {
        data_type   => 'datetime',
        is_nullable => 0,
    },
    abstract => {
        data_type   => 'text',
        size        => 1024,
        is_nullable => 1,
    },
    changes_fulltext => {
        data_type   => 'text',
        is_nullable => 1,
    },
    changes_release_date => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 1,
    },
    changes_for_release => {
        data_type   => 'text',
        is_nullable => 1,
    },
    failure => {
        data_type   => 'text',
        is_nullable => 1,
    },
    ctime => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
    mtime => {
        data_type     => 'datetime',
        set_on_create => 1,
        set_on_update => 1,
    },
);
__PACKAGE__->set_primary_key( 'id' );

# "COLLATE NOCASE" is an SQLite-ism
# __PACKAGE__->resultset_attributes(
#     { order_by => [ 'distribution COLLATE NOCASE' ] } );
__PACKAGE__->add_unique_constraint(
    release_key => [ qw( distribution author version ) ], );

__PACKAGE__->has_many( scan_release_joins =>
        'CPAN::Changes::Web::Schema::Result::ScanReleaseJoin' =>
        'release_id' );
__PACKAGE__->many_to_many( scans => 'scan_release_joins' => 'scan' );

# MySQL is not happy with this constraint.
# __PACKAGE__->might_have(
#     'author_info' => 'CPAN::Changes::Web::Schema::Result::Author',
#     { 'foreign.id' => 'self.author' }
# );

sub status_text {
    my $self = shift;
    return $self->failure ? 'fail' : 'pass';
}

sub as_changes_obj {
    return CPAN::Changes->load_string( shift->changes_fulltext );
}

sub text_diff_from {
    my $self = shift;
    my $prev = shift;

    if( !$prev ) {
        my $rs = $self->result_source->schema->resultset( 'Release' );
        $prev  = $rs->search(
            {
                distribution => $self->distribution,
                version => { '!=' => $self->version } },
            { order_by => 'ctime desc' }
        )->first;
    }

    return '' unless $prev;
    my $from = $prev->changes_fulltext || '';
    my $to = $self->changes_fulltext || ''; 

    return Text::Diff::diff( \$from, \$to );
}

1;
