package CPAN::Changes::Web::Schema::Result::Scan;

use strict;
use warnings;

use base qw( DBIx::Class );

__PACKAGE__->load_components( qw( TimeStamp Core ) );
__PACKAGE__->table( 'scan' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    run_date => {
        data_type     => 'datetime',
        set_on_create => 1,
    },
    cpan_changes_version => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 0,
    },
);
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->resultset_attributes( { order_by => [ 'run_date DESC' ] } );

__PACKAGE__->has_many( scan_release_joins =>
        'CPAN::Changes::Web::Schema::Result::ScanReleaseJoin' => 'scan_id' );
__PACKAGE__->many_to_many( releases => 'scan_release_joins' => 'release' );

sub hall_of_fame_authors {
    my $self = shift;
    my $inner = $self->releases( { failure => { NOT => undef } } );

    return $self->releases(
        {   author => { 'NOT IN' => $inner->get_column( 'author' )->as_query }
        }
    )->authors;
}

1;
