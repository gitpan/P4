#!/usr/bin/perl
#*******************************************************************************
#* example.pl - a short sample showing how to use the P4 client interface
#*******************************************************************************
use P4;

# Initialisation
my $p4 = new P4;
$p4->Connect() or die( "Failed to connect to Perforce" );

# Running "p4 info" and getting the results as a single string
my $info;
$info = join( "\n", $p4->Info() );	

# Or equivalently
$info = join( "\n", $p4->Run( "info" ) );

# Running "p4 info" and getting the results in array form
my @info;
@info = $p4->Info();

# Submitting changes. Use "p4 change -o" to grab the change spec
# and "p4 submit -i" to do the submit.
#
# Commented out by default to make the example non-invasive

#my $change = $p4->FetchChange();
#$change =~ s/<enter description here>/Some description/;
#$p4->SetInput( $change );
#$p4->Submit( "-i" ) );


# Parsing forms. Requires protocol options set prior to initialisation
$p4 = new P4;	# discard old object
$p4->ParseForms();
$p4->Connect() or die( "Failed to connect to Perforce" );

my $spec = $p4->FetchClient();
foreach my $key ( sort keys %$spec )
{
    next if ( $key eq "specdef" );
    if( $key eq "View" )
    {
	print( "View:\n" );
	foreach my $v ( @{$spec->{ $key }} )
	{
	    print( "\t$v\n" );
	}
    }
    else
    {
	print( "$key\t => " . $spec->{ $key } . "\n" );
    }
}

