# Copyright (c) 1997-2001, Perforce Software, Inc.  All rights reserved.
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


#*******************************************************************************
# P4::Perl	- UI object for Perforce interface. Handles the Perforce API's
#		  callbacks and stores the results for returning using 
#		  normal perl conventions.
#*******************************************************************************

package P4::Perl;
use P4::UI;
use strict;
use vars qw( @ISA );

@ISA = qw( P4::UI );

sub new
{
    my $class = shift;
    my $self = new P4::UI;
    $self->{ 'Results' } = [];
    $self->{ 'Errors' } = [];
    $self->{ 'Input' } = undef;
    bless( $self, $class );
    return $self;
}

#*******************************************************************************
# Override methods called from the Perforce API
#*******************************************************************************
sub OutputInfo
{
    my ( $self, $level, $data ) = @_;
    push( @{ $self->{ 'Results' } }, $data );
}

sub OutputStat
{
    my ( $self, $href ) = @_;
    push( @{ $self->{ 'Results' } }, $href );
}

# Not required. Use "p4 command -o" and "p4 command -i" to avoid the 
# editing step.
sub Edit
{
    warn( "Edit() method not supported by P4::Perl class" );
    return;
}

sub ErrorPause
{
    my ( $self, $message ) = @_;
    push ( @{ $self->{ 'Errors' } }, $message );
}

sub InputData
{
    my $self = shift;
    if ( defined( $self->{ 'Input' } ) )
    {
	my $input = $self->{ 'Input' };
	$self->{ 'Input' } = undef; 	# Clear it out to prevent re-use
	return $input;
    }
    warn( "P4::InputData() called without any data to supply" );
    return undef;
}

sub OutputError
{
    my ( $self, $error ) = @_;
    push ( @{ $self->{ 'Errors' } }, $error );
}

sub OutputText
{
    my ( $self, $text ) = @_;
    push( @{ $self->{ 'Results' } }, $text );
}

sub Prompt
{
    my ( $self, $prompt ) = @_;
    warn( "Prompt() method not supported by P4::Perl class" );
    return undef;
}

#*******************************************************************************
#* Sending input to Perforce
#*******************************************************************************
sub SetInput
{
    my $self = shift;
    $self->{ 'Input' } = shift;
}


#*******************************************************************************
#* Getting the results of commands
#*******************************************************************************

#
# Return the results of the last command, clearing the results buffer.
# If the caller wants an array, then they get one. If not, and there's
# only one result record, then it is returned intact (even if it's 
# a hash reference containing tagged output). If there's more than
# one output record, then they are formatted and joined together into
# a single scalar string and returned to the caller.
#
sub Results
{
    my $self = shift;
    if ( wantarray() )
    {
	my $results = $self->{ 'Results' };
	$self->{ 'Results' } = [];
	return @$results;
    }

    if ( scalar( @{ $self->{ 'Results' } } ) == 1 )
    {
	my $results = $self->{ 'Results' };
	$self->{ 'Results' } = [];
	return $results->[ 0 ];
    }

    return join("\n",map( _ResultToString( $_ ), @{ $self->{ 'Results' } } ) );
}

# Join results together for user. Required when they want their results in
# scalar context.  Newline handling's a bit crufty at the mo' for tagged
# data, but it does the job and most people won't want tagged output in
# this format anyway.
sub _ResultToString
{
    my $item = shift;
    my $result = "";

    if ( ref( $item ) )
    {
	foreach my $key ( keys %{ $item } )
	{
	    $result .= $key . " " . $item->{ $key } . "\n";
	}
	chop( $result );
	return $result;
    }
    return $item;
}



sub ErrorCount
{
    my $self = shift;
    return scalar( @{ $self->{ 'Errors' } } );
}

sub Errors
{
    my $self = shift;
    my $errs = $self->{ 'Errors' };
    $self->{ 'Errors' } = [];
    return $errs;
}

# Flush results and errors buffers
sub Clear
{
    my $self = shift;
    $self->{ 'Results' } = [];
    $self->{ 'Errors'} = [];
}


#*******************************************************************************
#* Main interface definition.
#*******************************************************************************
package P4;
use P4::Client;
use AutoLoader;
use strict;
use vars qw( $VERSION $AUTOLOAD @ISA @EXPORT @EXPORT_OK );

$VERSION = qq( 0.931 );

@ISA = qw( P4::Client );

@EXPORT_OK = qw( );
@EXPORT = qw();

sub new
{
	my $class = shift;
	my $self = new P4::Client;
	$self->{ 'ui' } = new P4::Perl;
	bless( $self, $class );
	return $self;
}

#
# Prior to running a "p4 submit/change/user/client/etc -i", use this method
# to provide the form you want to send to Perforce.
#
sub SetInput( $ )
{
    my $self = shift;
    my $data = shift;

    $self->{ 'ui' }->SetInput( $data );
}


sub Run
{
    my $self = shift;
    my $cmd = shift;

    $self->{ 'ui' }->Clear();
    P4::Client::Run( $self, $self->{ 'ui' }, $cmd, @_ );
    return $self->{ 'ui' }->Results();
}

sub Errors
{
    my $self = shift;
    return $self->{ 'ui' }->Errors();
}

sub ErrorCount
{
    my $self = shift;
    return $self->{ 'ui' }->ErrorCount();
}


#*******************************************************************************
#* Useful shortcut methods to make common actions easier to code. Nothing
#* here that can't be done using the already defined methods.
#*******************************************************************************

# Tag		- Request tagged output. Call before calling Init().
#
sub Tag()
{
    my $self = shift;
    $self->SetProtocol( "tag", "" );
}


# ParseForms	- Request that all forms be parsed into hashes for easy use.
#		  Call prior to calling Init().
#
sub ParseForms()
{
    my $self = shift;
    $self->SetProtocol( "tag", "" );
    $self->SetProtocol( "specstring", "" );
}


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

# Makes the Perforce commands usable as methods on the object for
# cleaner syntax. If it's not a valid method, you'll find out when
# Perforce recommends you read the help.
# 
# Also implements Get/Set methods for common Perforce commands. e.g.
#
#	$label = $p4->GetLabel( "labelname" );
#	$change = $p4->GetChange( [ changeno ] );
#
#	$p4->SetChange( $change );
#	$p4->SetUser( $p4->GetUser( "username" ) );
#
# Use with care as it's not too clever. SetSubmit is perfectly valid as 
# far as this code is concerned, but it doesn't do much!
#
sub AUTOLOAD
{
	my $self = shift;
	my $cmd;
	($cmd = $AUTOLOAD ) =~ s/.*:://;
	$cmd = lc $cmd;

	if ( $cmd =~ /^set(\w+)/  )
	{
	    die( "Set$1 requires an argument!" ) if ( ! scalar( @_ ) );
	    $self->SetInput( shift );
	    return $self->Run( $1, "-i", @_ );
	}
	elsif ( $cmd =~ /^get(\w+)/ )
	{
	    return $self->Run( $1, "-o", @_ );
	}
	return $self->Run( $cmd, @_ );
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
  $p4->Init() or die( "Failed to connect to Perforce Server" );
  
  my $info = $p4->Run( "info" );
  $p4->Edit( "file.txt" ) or die( "Failed to edit file.txt" );
  $p4->Final();


=head1 DESCRIPTION

This module provides an OO interface to the Perforce SCM system which
is more intuitive to Perl users than the P4::Client/P4::UI modules
but a little less capable as it represents but one way of using
P4::Client and P4::UI. 

Methods are divided into the base methods and shortcuts. The shortcuts
are intended to make scripts using this module easier by providing
easy interfaces to common actions. They're just wrappers around the base
methods though.

=head1 BASE METHODS

=over 4

=item C<new()>

	Constructor. The only method of this class you call
	directly.

=item C<P4::Dropped()>

Returns true if the TCP/IP connection between client and server has 
been dropped.

=item C<P4::Final()>

Terminate the connection and clean up. Should be called before exiting
to cleanly disconnect.

=item C<P4::GetClient()>

Returns the current Perforce client name. This may have previously
been set by SetClient(), or may be taken from the environment or
P4CONFIG file if any. If all that fails, it will be your hostname.

=item C<P4::GetCwd()>

Returns the current working directory as your Perforce client sees
it.

=item C<P4::GetHost()>

Returns the client hostname. Defaults to your hostname, but can
be overridden with SetHost()

=item C<P4::GetPassword()>

Returns your Perforce password - in plain text if that's how it's
stored and currently on all except Windows platforms, that's the 
way it's done.  Taken from a previous call to SetPassword() or 
extracted from the environment ( $ENV{P4PASSWD} ), or a P4CONFIG 
file.

Note that the password is not transmitted in clear text. 

=item C<P4::GetPort()>

Returns the current address for your Perforce server. Taken from 
a previous call to SetPort(), or from $ENV{P4PORT} or a P4CONFIG
file.

=item C<P4::Init()>

Initializes the Perforce client and connects to the server.
Returns false on failure and true on success.

=item C<P4::Run( cmd, [$arg...] )>

Run a Perforce command returning the results. Check for errors
using C<P4::ErrorCount()>. Results are returned in scalar or
array context, whichever you're using. Through the magic of 
the AutoLoader, you can also treat the Perforce commands as
methods, so 

C<$p4-E<gt>Edit( "filename.txt );>

is equivalent to 

C<$p4-E<gt>Run( "edit", "filename.txt" );>

Note that C<$var = $p4-E<gt>Info()> returns a string containing
all of the lines of output from Perforce. Whilst 
C<@var = $p4-E<gt>Info()> returns an array with each line of 
output in a separate element.

=item C<P4::SetClient( $client )>

Sets the name of your Perforce client. If you don't call this 
method, then the clientname will default according to the normal
Perforce conventions. i.e.

=over 4

=item 1. Value from file specified by P4CONFIG

=item 2. Value from C<$ENV{P4CLIENT}>

=item 3. Hostname

=back

=item C<P4::SetCwd( $path )>

Sets the current working directory for the client. This should
be called after the Init() and before the Run().

=item C<P4::SetPassword( $password )>

Set the password for the Perforce user, overriding all defaults.

=item C<P4::SetPort( [$host:]$port )>

Set the port on which your Perforce server is listening. Defaults
to:

=over 4

=item 1. Value from file specified by P4CONFIG

=item 2. Value from C<$ENV{P4PORT}>

=item 3. perforce:1666

=back

=item C<P4::SetProtocol( $protflag, $value )>

Set protocol options for this session. The most common
protocol option is the "tag" option which requests tagged
output format for commands which would otherwise get formatted
output. 

For example:

=over 4

C<$p4-E<gt>SetProtocol(tag,''); 
  $p4-E<gt>Init();
  my @f = $p4-E<gt>Fstat( "filename" );
  my $c = $f[ 0 ]-E<gt>{ 'clientFile' };
>

=back

=item C<P4::SetUser( $username )>

Set your Perforce username. Defaults to:

=over 4

=item 1. Value from file specified by P4CONFIG

=item 2. Value from C<$ENV{P4USER}>

=item 3. OS username

=back

=back

=head1 SHORTCUT METHODS

The following methods are simply wrappers around the base methods
designed to make common actions easy to code.

=over 4

=item C<P4::Tag()>

Equivalent to C<SetProtocol( "tag", "" )>. Responses from commands that
support tagged output will be in the form of a hash ref rather than plain
text. Must be called prior to calling C<Init()>.

=item C<P4::ParseForms()>

Request that forms returned by commands such as C<$p4-E<gt>GetChange()>, or
C<$p4-E<gt>Client( "-o" )> be parsed and returned as a hash reference for easy
manipulation. Equivalent to calling C<SetProtocol( "tag", "" )> and 
C<SetProtocol( "specstring", "" )>. Must be called prior to calling C<Init()>.

=item C<P4::GetChange()>

Returns a change specification formatted either as a plain string in a
scalar variable, or as a hashref if C<P4::ParseForms()> has been 
called.

=head1 API Versions

This extension has been built and tested on the Perforce 2001.1 API,
but should work with any recent version, certainly any release later
than and including 99.2.

=head1 LICENCE

Copyright (c) 1997-2001, Perforce Software, Inc.  All rights reserved.

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

Tony Smith, Perforce Software ( tony@perforce.com )

=head1 SEE ALSO

perl(1), P4::Client(3), P4::UI(3), Perforce API documentation.

=cut
