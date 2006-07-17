# Copyright (c) 1997-2004, Perforce Software, Inc.  All rights reserved.
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

$self->{CC} 		= "c++";
$self->{LD} 		= "c++";
$self->{DEFINE} 	.= " -DOS_LINUX -Dconst_char='char'";

# Some Perl builds - notably ActiveState, but also some Red Hat ones use very
# restrictive preprocessor settings which are no good to us. So, just to be
# on the safe side, we'll also add in what we need here.

$self->{DEFINE}		.= " -D_BSD_SOURCE -D_SVID_SOURCE";

print <<EOS;

IMPORTANT NOTE
--------------

If you get errors like this:

Can't load 'blib/arch/auto/P4/P4.so' for module P4: blib/arch/auto/P4/P4.so: 
undefined symbol: _ZN10ClientUser7MessageEP5Error at /usr/lib/perl5/5.8.2/i686-linux-multi/DynaLoader.pm line 229.

when you're running your 'make test', you are using build of the Perforce API
compiled with gcc2 on a machine running gcc3. Please download a gcc3 compiled
version of the Perforce API from 

http://www.perforce.com/downloads/perforce/rXX.Y/bin.linux80x86/p4api.tar

(where rXX.Y is the current Perforce release - i.e. r04.2)

EOS

