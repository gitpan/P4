/*******************************************************************************
Copyright (c) 1997-2006, Perforce Software, Inc.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1.  Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

2.  Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

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
*******************************************************************************/

class ClientApi;
class PerlClientUser;

class PerlClientApi 
{
    public:
    		PerlClientApi();
		~PerlClientApi();

    SV *	Connect();
    SV *	Disconnect();
    SV *	Dropped();
    SV *	Run( const char *cmd, int argc, char * const *argv );

    void	SetApiLevel( int level );
    SV *	SetCharset( const char *c );
    void	SetClient( const char *c ) 	{ client->SetClient( c );    }
    void	SetCwd( const char *c )		{ client->SetCwd( c );	     }
    void	SetHost( const char *c )	{ client->SetHost( c );	     }
    void	SetLanguage( const char *c )	{ client->SetLanguage( c );  }
    void	SetPassword( const char *c )	{ client->SetPassword( c );  }
    void	SetMaxResults( int v )		{ maxResults = v;	     }
    void	SetMaxScanRows( int v )		{ maxScanRows = v;	     }
    void	SetPort( const char *c )	{ client->SetPort( c );	     }
    void	SetUser( const char *c )	{ client->SetUser( c );      }
    void	SetProg( const char *c )	{ prog.Set( c );	     }

    void	SetInput( SV *i );

    SV *	GetCharset();
    SV *	GetClient();
    SV *	GetCwd();
    SV *	GetHost();
    SV *	GetLanguage();
    SV *	GetPassword();
    SV *	GetPort();
    SV *	GetUser();

    // Base protocol ops
    void	SetProtocol( const char *p, const char *v );
    StrPtr *	GetProtocol( const char *v );

    // High-level protocol ops
    void	Tagged();
    void	ParseForms();
    int		IsTagged();
    int		IsParseForms();

    //
    // Handling command output
    //
    SV *	MergeErrors( int merge = -1 );
    SV *	GetFirstOutput();
    AV *	GetOutput();
    AV *	GetWarnings();
    AV *	GetErrors();

    I32		GetOutputCount();
    I32		GetWarningCount();
    I32		GetErrorCount();


    // Spec parsing
    SV *	ParseSpec( const char *type, const char *form );
    SV *	FormatSpec( const char *type, HV *hash );
    
    // Debugging support
    void	SetDebugLevel( int l );
    int		GetDebugLevel()			{ return debug;	     }
    int		IsConnected()			{ return initCount;	     }

    //
    private:
    // Compatibility flags
    //
    enum 
    {
	CPT_MERGED	= 0x0001
    };

    //
    // Client mode settings
    //
    enum
    {
	PROTO_TAG		= 0x01,
	PROTO_SPECSTRING	= 0x02,
	MODE_PARSEFORMS		= 0x03,
	PROTO_MASK		= 0x0f
    };


    StrPtr * 	FetchSpecDef( const char *type );
    void	RunCmd( const char *cmd, ClientUser *ui, int argc, char * const *argv );

    private:
	ClientApi *		client;
	PerlClientUser *	ui;
	StrBufDict		specDict;
	StrBuf			prog;
	int			server2;
	int			mode;
	int			initCount;
	int			debug;
	int			compatFlags;
	int			maxResults;
	int			maxScanRows;
};
