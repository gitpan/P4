# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use P4;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $p4 = new P4;
print( defined( $p4 ) ? "ok 2\n" : "not ok 1\n" );

$p4->ParseForms();
print( $p4->Init() ? "ok 3\n" : "not ok 2\n" );

# Since 2003.2, "p4 info" supports tagged output. So we have to handle both
# tagged and non-tagged output in the test.
my @info = $p4->Info();
if( scalar( @info ) == 1 )
{
    # Tagged output. The result should be a hashref
    my $i = $info[ 0 ];
    print( ref( $i ) == "HASH" ? "ok 4\n" : "not ok 4\n" );
    print( ( ref( $i ) && defined( $i->{ 'userName' } ) ) ? "ok 5\n" : "not ok 5\n" );
}
else
{
    # Non tagged output. 
    print( scalar( @info ) >= 10 ? "ok 4\n" : "not ok 4\n" );
    my $info = join( "\n", $p4->Info() );
    print( $info =~ /^User name/ ? "ok 5\n" : "not ok 5\n" );
}

my $client = $p4->FetchClient();
print( ref( $client ) ? "ok 6\n" : "not ok 6\n" );

my $users = $p4->Users();
print( ref( $users ) ? "ok 7\n" : "not ok 7\n" );

