$( document ).ready( function() {

    // All
    $( '#showall' ).click( function() {
        $( '#showall' ).css( 'font-weight', 'bold' );
        $( '#showpass,#showfail' ).css( 'font-weight', 'normal' );
        $( '#releases li' ).show();
        return false;
    } );

    // Pass
    $( '#showpass' ).click( function() {
        $( '#showpass' ).css( 'font-weight', 'bold' );
        $( '#showall,#showfail' ).css( 'font-weight', 'normal' );
        $( '#releases li.pass' ).show();
        $( '#releases li.fail' ).hide();
        return false;
    } );

    // Fail
    $( '#showfail' ).click( function() {
        $( '#showfail' ).css( 'font-weight', 'bold' );
        $( '#showall,#showpass' ).css( 'font-weight', 'normal' );
        $( '#releases li.fail' ).show();
        $( '#releases li.pass' ).hide();
        return false;
    } );

    // Reformatted
    $( '#showreformatted' ).click( function() {
        $( '#showreformatted' ).css( 'font-weight', 'bold' );
        $( '#showoriginal,#showdiff' ).css( 'font-weight', 'normal' );
        $( '#reformatted' ).show();
        $( '#original,#diff' ).hide();
        return false;
    } );

    // Original
    $( '#showoriginal' ).click( function() {
        $( '#showoriginal' ).css( 'font-weight', 'bold' );
        $( '#showreformatted,#showdiff' ).css( 'font-weight', 'normal' );
        $( '#original' ).show();
        $( '#reformatted,#diff' ).hide();
        return false;
    } );

    // Diff
    $( '#showdiff' ).click( function() {
        $( '#showdiff' ).css( 'font-weight', 'bold' );
        $( '#showreformatted,#showoriginal' ).css( 'font-weight', 'normal' );
        $( '#diff' ).show();
        $( '#reformatted,#original' ).hide();
        return false;
    } );
} );
