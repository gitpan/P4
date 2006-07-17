# Copyright (c) 1997-2006, Perforce Software, Inc.  All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1.  Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
# 
# 2.  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE SOFTWARE, INC. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package P4;
use strict;

require Exporter;
require DynaLoader;

use AutoLoader;
use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK $AUTOLOAD );

@ISA = qw(Exporter DynaLoader);
@EXPORT_OK = qw( );
@EXPORT = qw();
$VERSION = qq( 3.5313 );

bootstrap P4 $VERSION;

#
# Execute a command. The return value depends on the context of the call.
#
# Returns an array of results if the caller's asked for one
# Returns undef if result set is empty
# Returns a scalar result in scalar context if only one result exists.
# Returns an array ref in scalar context if more than one result exists.
#
sub Run
{
    my $self = shift;
    my $results = $self->_Run( @_ );
    return @$results 		if( wantarray );
    return undef 		if( scalar( @$results ) == 0 );
    return $$results[ 0 ] 	if( scalar( @$results ) == 1 );
    return $results;
}

# Change the current working directory. Returns undef on failure.
sub SetCwd
{
    my $self = shift;
    my $cwd = shift;

    # First we chdir to the dir if it exists. If successful, then we
    # update the PWD environment variable (if defined) and call the
    # API equivalent function, now named _SetCwd()
    return undef unless chdir( $cwd );
    $ENV{ "PWD" } = $cwd if ( defined( $ENV{ "PWD" } ) );
    $self->_SetCwd( $cwd );
    return $cwd;
}


#
# Run 'p4 login' using the password supplied by the user
#
sub Login()
{
    my $self = shift;
    $self->SetInput( $self->GetPassword() );
    return $self->Run( "login" );
}

#
# Run 'p4 passwd' to change the password
#
sub Password( $$ )
{
    my $self 	= shift;
    my $oldpass = shift;
    my $newpass = shift;

    my $args = [ $oldpass, $newpass, $newpass ];
    $self->SetInput( $args );
    return $self->Run( "password" );
}


#*******************************************************************************
#* Useful shortcut methods to make common actions easier to code. Nothing
#* here that can't be done using the already defined methods.
#*******************************************************************************


# SubmitSpec	- "p4 submit -i"
#
# Submit a changelist using supplied spec. Spec can be in string form,
# or a hash containing the required form elements and a specdef member
# telling the API how to create the form. 
#
# Synopsis:	$p4->SubmitSpec( $spec );
sub SubmitSpec( $ )
{
    my $self = shift;
    $self->SetInput( shift );
    $self->Submit( "-i" );
}

#*******************************************************************************
#* Compatibility-ville.
#*******************************************************************************

sub Tag()
{
    my $self = shift;
    $self->Tagged();
}


# Makes the Perforce commands usable as methods on the object for
# cleaner syntax. If it's not a valid method, you'll find out when
# Perforce recommends you read the help.
# 
# Also implements Fetch/Save methods for common Perforce commands. e.g.
#
#	$label = $p4->FetchLabel( "labelname" );
#	$change = $p4->FetchChange( [ changeno ] );
#
#	$p4->SaveChange( $change );
#	$p4->SaveUser( $p4->GetUser( "username" ) );
#
# Use with care as it's not too clever. SaveSubmit is perfectly valid as 
# far as this code is concerned, but it doesn't do much!
#
sub AUTOLOAD
{
	my $self = shift;
	my $cmd;
	($cmd = $AUTOLOAD ) =~ s/.*:://;
	$cmd = lc $cmd;

	if ( $cmd =~ /^save(\w+)/i  )
	{
	    die( "save$1 requires an argument!" ) if ( ! scalar( @_ ) );
	    $self->SetInput( shift );
	    return $self->Run( $1, "-i", @_ );
	}
	elsif ( $cmd =~ /^fetch(\w+)/i )
	{
	    return $self->Run( $1, "-o", @_ );
	}
	elsif ( $cmd =~ /^parse(\w+)/i )
	{
	    die( "parse$1 requires an argument!" ) if ( ! scalar( @_ ) );
	    return $self->ParseSpec( $1, $_[0] );
	}
	elsif ( $cmd =~ /^format(\w+)/i )
	{
	    die( "format$1 requires an argument!" ) if ( ! scalar( @_ ) );
	    return $self->FormatSpec( $1, $_[0] );
	}
	return $self->Run( $cmd, @_ );
}

#*******************************************************************************
# Compatibility-ville.
#*******************************************************************************
sub Final
{
    my $self = shift;
    $self->Disconnect();
}

sub Init
{
    my $self = shift;
    $self->Connect();
}

1;
__END__

=head1 NAME

P4 - OO interface to the Perforce SCM System.

=head1 SYNOPSIS

  use P4;
  my $p4 = new P4;

  $p4->SetClient( $clientname );
  $p4->SetPort ( $p4port );
  $p4->SetPassword( $p4password );
  $p4->Connect() or die( "Failed to connect to Perforce Server" );
  
  my $info = $p4->Run( "info" );
  $p4->Edit( "file.txt" ) or die( "Failed to edit file.txt" );
  $p4->Disconnect();


=head1 DESCRIPTION

This module provides an OO interface to the Perforce SCM system that
is designed to be intuitive to Perl users. Data is returned in Perl
arrays and hashes and input can also be supplied in these formats.

Each P4 object represents a connection to the Perforce Server, and 
multiple commands may be executed (serially) over a single connection.

=head1 BASE METHODS

=over 4

=item P4::new()

Construct a new P4 object. e.g.

  my $p4 = new P4;

=item P4::Connect()

Initializes the Perforce client and connects to the server.
Returns false on failure and true on success.

=item P4::DebugLevel( [ level ] )

Gets and optionally sets the debug level. Without an argument, it 
just returns the current debug level. With an argument, it first updates
the debug level and then returns the new value.

For example:

 $client->DebugLevel( 1 );
 $client->DebugLevel( 0 );
 print( "Debug level = ", $client->DebugLevel(), "\n" );

=item P4::Dropped()

Returns true if the TCP/IP connection between client and server has 
been dropped.

=item P4::ErrorCount()

Returns the number of errors encountered during execution of the last
command

=item P4::Errors()

Returns a list of the error messages received during execution of 
the last command.


=item P4::FormatSpec( type, string )

Converts a Perforce form of the specified type (client/label etc.)
held in the supplied hash into its string representation. Note that 
shortcut methods are available that obviate the need to supply the 
type argument. The following two examples are equivalent:

    my $client = $p4->FormatSpec( "client", $hash );
    my $client = $p4->FormatClient( $hash );


=item P4::Disconnect()

Terminate the connection and clean up. Should be called before exiting.

=item P4::GetClient()

Return the name of the current charset in use. Applicable only when
used with Perforce servers running in unicode mode.

=item P4::GetClient()

Returns the current Perforce client name. This may have previously
been set by SetClient(), or may be taken from the environment or
P4CONFIG file if any. If all that fails, it will be your hostname.

=item P4::GetCwd()

Returns the current working directory as your Perforce client sees
it.

=item P4::GetHost()

Returns the client hostname. Defaults to your hostname, but can
be overridden with SetHost()

=item P4::GetPassword()

Returns your Perforce password.  Taken from a previous call to 
SetPassword() or extracted from the environment ( $ENV{P4PASSWD} ), 
or a P4CONFIG file.

=item P4::GetPort()

Returns the current address for your Perforce server. Taken from 
a previous call to SetPort(), or from $ENV{P4PORT} or a P4CONFIG
file.

=item P4::IsParseForms()

Returns true if ParseForms mode is enabled on this client.

=item P4::IsTagged()

Returns true if Tagged mode is enabled on this client.

a previous call to SetPort(), or from $ENV{P4PORT} or a P4CONFIG
file.

=item P4::MergeErrors( [0|1] )

For backwards compatibility. In previous versions of P4, errors and
warnings were mixed in the same 'Errors' array. This made it tricky
for users to ignore warnings, but still look out for errors. This
release of P4 stores them in two separate arrays. You can get the
list of errors, but calling P4::Errors(), and the list of warnings by
calling P4::Warnings(). If you want to revert to the old behaviour, 
you can call this method to revert to the old behaviour and all
warnings will go into the error array. i.e.

  $p4->MergeErrors( 1 );
  $p4->Sync();
  $p4->MergeErrors( 0 );


=item P4::ParseForms()

Request that forms returned by commands such as C<$p4-E<gt>GetChange()>, or
C<$p4-E<gt>Client( "-o" )> be parsed and returned as a hash reference for easy
manipulation. Must be called prior to calling C<Connect()>.

=item P4::ParseSpec( type, string )

Converts a Perforce form of the specified type (client/label etc.)
held in the supplied string into a hash and returns a reference to 
that hash. Note that shortcut methods are available to avoid the
need to supply the type argument. The following two examples are
equivalent:

    my $hash = $p4->ParseSpec( "client", $clientspec );
    my $hash = $p4->ParseClient( $clientspec );


=item P4::Password( $oldpass, $newpass )

Run a C<p4 password> command to change the user's password from
$oldpass to $newpass. Not to be confused with P4::SetPassword.


=item P4::Run( cmd, [$arg...] )

Run a Perforce command returning the results. Since Perforce commands
can partially succeed and partially fail, you should check for errors
using C<P4::ErrorCount()>. 

Results are returned as follows:

    An array of results in array context.
    undef in scalar context if result set is empty.
    A scalar result in scalar context if only one result exists.
    An array ref in scalar context if more than one result exists.

Through the magic of the AutoLoader, you can also treat the 
Perforce commands as methods, so:

 $p4->Edit( "filename.txt );

is equivalent to 

 $p4->Run( "edit", "filename.txt" );

Note that the format of the scalar or array results you get 
depends on (a) whether you're using tagged (or form parsing) mode 
(b) the command you've executed (c) the arguments you supplied and 
(d) your Perforce server version.

In tagged or form parsing mode, ideally each result element will be
a hashref, but this is dependent on the command you ran and your server
version.

In non-tagged mode ( default ), the each result element will be a string. 
In this case, also note that as the Perforce server sometimes asks the 
client to write a blank line between result elements, some of these result 
elements can be empty. 

Mostly you will want to use form parsing (and hence tagged) mode. See
ParseForms().

Note that the return values of individual Perforce commands are not 
documented because they may vary between server releases. 

If you want to be correlate the results returned by the P4 interface with 
those sent to the command line client try running your command with RPC 
tracing enabled. For example:

 Tagged mode:		p4 -Ztag -vrpc=1 describe -s 4321
 Non-Tagged mode:	p4 -vrpc=1 describe -s 4321

Pay attention to the calls to client-FstatInfo(), client-OutputText(), 
client-OutputData() and client-HandleError(). I<Each call to one of these
functions results in either a result element, or an error element.>

=item P4::SetApiLevel( integer )

Specify the API compatibility level to use for this script. 
This is useful when you want your script to continue to work on
newer server versions, even if the new server adds tagged output
to previously unsupported commands.

The additional tagged output support can change the server's
output, and confound your scripts. Setting the API level to a
specific value allows you to lock the output to an older
format, thus increasing the compatibility of your script.

Must be called before calling P4::Connect(). e.g.

  $p4->SetApiLevel( 57 ); # Lock to 2005.1 format
  $p4->Connect() or die( "Failed to connect to Perforce" );
  etc.

=item P4::SetCharset( $charset )

Specify the character set to use for local files when used with a
Perforce server running in unicode mode. Do not use UNLESS your
Perforce server is in unicode mode. Must be called before calling
P4::Connect(). e.g.

  $p4->SetCharset( "winansi" );
  $p4->SetCharset( "iso8859-1" );
  $p4->SetCharset( "utf8" );
  etc.

=item P4::SetClient( $client )

Sets the name of your Perforce client. If you don't call this 
method, then the clientname will default according to the normal
Perforce conventions. i.e.

    1. Value from file specified by P4CONFIG
    2. Value from $ENV{P4CLIENT}
    3. Hostname

=item P4::SetCwd( $path )

Sets the current working directory for the client. This should
be called after the Connect() and before the Run().

=item P4::SetHost( $hostname )

Sets the name of the client host - overriding the actual hostname.
This is equivalent to 'p4 -H <hostname>', and really only useful when
you want to run commands as if you were on another machine. If you
don't know when or why you might want to do that, then don't do it.

=item P4::SetInput( arg )

Save the supplied argument as input to be supplied to a subsequent 
command.  The input may be: a hashref, a scalar string or an array 
of hashrefs or scalar strings. Note that if you pass an array the
array will be shifted once each time the Perforce command being
executed asks for user input.

=item P4::SetMaxResults( value )

Limit the number of results for subsequent commands to the value
specified. Perforce will abort the command if continuing would
produce more than this number of results. Note that once set,
this limit remains in force. You can remove the restriction by
setting it to a value of 0.

=item P4::SetMaxScanRows( value )

Limit the number of records Perforce will scan when processing
subsequent commands to the value specified. Perforce will abort 
the command once this number of records has been scanned. Note 
that once set, this limit remains in force. You can remove the 
restriction by setting it to a value of 0.

=item P4::SetPassword( $password )

Specify the password to use when authenticating this user against
the Perforce Server - overrides all defaults. Not to be 
confused with P4::Password().

=item P4::SetPort( [$host:]$port )

Set the port on which your Perforce server is listening. Defaults
to:

    1. Value from file specified by P4CONFIG
    2. Value from $ENV{P4PORT}
    3. perforce:1666

=item P4::SetProg( $program_name )

Set the name of your script. This value is displayed in the server log
on 2004.2 or later servers.

=item P4::SetProtocol( $protflag, $value )

Set protocol options for this session. Deprecated. Use C<Tagged()> or
C<ParseForms()> instead.

For example:

 $p4->SetProtocol(tag,''); 
 $p4->Connect();
 my @f = $p4->Fstat( "filename" );
 my $c = $f[ 0 ]->{ 'clientFile' };

=item P4::SetUser( $username )

Set your Perforce username. Defaults to:

    1. Value from file specified by P4CONFIG
    2. Value from C<$ENV{P4USER}>
    3. OS username

=item P4::Tag()

Deprecated in favour of C<Tagged> (same functionality).

=item P4::Tagged()

Responses from commands that support tagged output will be returned
in the form of a hashref rather than plain text. Must be called 
prior to calling C<Connect()>.

=item P4::WarningCount()

Returns the number of warnings issued by the last command.

 $p4->WarningCount();

=item P4::Warnings()

Returns a list of warnings from the last command

 $p4->Warnings();

=back

=head1 SHORTCUT METHODS

The following methods are simply wrappers around the base methods
designed to make common actions easy to code.

=over 4

=item P4::Fetch<cmd>()

Shorthand for running C<$p4-E<gt>Run( "cmd", "-o" )> and returning 
the results. eg.

    $label	= $p4->FetchLabel( $labelname );
    $change 	= $p4->FetchChange( $changeno );
    $clientspec	= $p4->FetchClient( $clientname );

=item P4::Format<spec type>( hash )>

Shorthand for: 

    $p4->FormatSpec( <spec type>, hash );
    
=item P4::Parse<spec type>( buffer )>

Shorthand for: 

    $p4->ParseSpec( <spec type>, buffer );
    
=item P4::Save<cmd>()>

Shorthand for: 

    $p4->SetInput( $spec ); 
    $p4->Run( "cmd", "-i");
    
e.g.

    $p4->SaveLabel( $label );
    $p4->SaveChange( $changeno );
    $p4->SaveClient( $clientspec );

=item P4::SubmitSpec()>

Submits a changelist using the supplied change specification.
Really a shorthand for SetInput() and Run( "submit", "-i" ).

For example:

    $change = $p4->FetchChange();
    $change->{ "Description" } = "some text...";
    $p4->SubmitSpec( $change );

=back

=head1 COMPATIBILITY WITH PREVIOUS VERSIONS

This version of P4 is largely backwards compatible with previous
versions with the following exceptions:

1. Errors and warnings are now saved in separate arrays by default. The
previous behaviour can be reinstated for those with compatibility 
requirements by calling

 $p4->MergeErrors( 1 );

Splitting errors and warnings into separate arrays makes it easier to
ignore warnings and only have to deal with real errors.

2. The DoPerlDiffs() method in previous versions is no longer defined. 
It was a legacy from an earlier release and was superceded in more recent 
versions.  Users who still depend on that functionality should use a 1.x 
build of P4.  Similarly, the corresponding DoP4Diffs() method is also removed. 
It was likely not used and is not necessary anyway.

=head1 LICENCE

Copyright (c) 1997-2004, Perforce Software, Inc.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1.  Redistributions of source code must retain the 
    above copyright notice, this list of conditions 
    and the following disclaimer.

2.  Redistributions in binary form must reproduce 
    the above copyright notice, this list of conditions 
    and the following disclaimer in the documentation 
    and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE SOFTWARE, INC. BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=head1 AUTHOR

Tony Smith, Perforce Software ( tony@perforce.com or tony@smee.org )

=head1 SEE ALSO

perl(1), Perforce API documentation.

=cut
