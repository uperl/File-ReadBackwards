# File::ReadBackwards.pm

# Copyright (C) 2000 by Uri Guttman. All rights reserved.
# mail bugs, comments and feedback to uri@sysarch.com

use strict ;

use vars qw( $VERSION ) ;

$VERSION = '0.90' ;

package File::ReadBackwards ;

use Symbol ;
use Fcntl ;
use Carp ;
use integer ;

my $max_read_size = 1 << 13 ;

my $default_rec_sep ;

BEGIN {

# set the default record separator according to this OS
# this needs testing and expansion.

# look for CR/LF types
# then look for CR types
# else it's a LF type

	if ( $^O =~ /win32/i || $^O =~ /vms/i ) {

		$default_rec_sep = "\015\012" ;
	}
	elsif ( $^O =~ /mac/i ) {

		$default_rec_sep = "\015" ;
	}
	else {
		$default_rec_sep = "\012" ;
	}

# the tied interface is exactly the same as the object one, so all we
# need to do is to alias the subs with typeglobs

	*TIEHANDLE = \&new ;
	*READLINE = \&readline ;
}


# constructor for File::ReadBackwards

sub new {

	my( $class, $filename, $rec_sep ) = @_ ;

	my( $handle, $read_size, $seek_pos, $self, $rec_regex, $is_crlf ) ;

# see if this file uses the default of a cr/lf separator
# those files will get cr/lf converted to \n

	$is_crlf = ! defined $rec_sep && $default_rec_sep eq "\015\012" ;

	$rec_sep ||= $default_rec_sep ;

# get a handle and open the file

	$handle = gensym ;
	sysopen( $handle, $filename, O_RDONLY ) || return ;
	binmode $handle ;

# seek to the end of the file

	sysseek( $handle, 0, 2 ) ;
	$seek_pos = tell( $handle ) ;

# get the size of the first block to read,
# either a trailing partial one (the % size) or full sized one (max read size)

	$read_size = $seek_pos % $max_read_size || $max_read_size ;

# create the object

	$self = bless {
			'file_name'	=> $filename,
			'handle'	=> $handle,
			'read_size'	=> $read_size,
			'seek_pos'	=> $seek_pos,
			'lines'		=> [],
			'is_crlf'	=> $is_crlf,
			'rec_sep'	=> $rec_sep,
			'rec_regex'	=> qr/(.*?$rec_sep|.+)/s,


		}, $class ;

	return( $self ) ;
}

# read the previous record from the file
# 
sub readline {

	my( $self, $line_ref ) = @_ ;

	my( $handle, $lines_ref, $seek_pos, $read_cnt, $read_buf,
	    $file_size, $read_size, $text ) ;

# get the buffer of lines

	$lines_ref = $self->{'lines'} ;

	while( 1 ) {

# see if there is more than 1 line in the buffer

		if ( @{$lines_ref} > 1 ) {

# we have a complete line so return it

			return( pop @{$lines_ref} ) ;
		}

# we don't have a complete, so have to read blocks until we do

		$seek_pos = $self->{'seek_pos'} ;

# see if we are at the beginning of the file

		if ( $seek_pos == 0 ) {

# the last read never made more lines, so return the last line in the buffer
# if no lines left then undef will be returned

			return( pop @{$lines_ref} ) ;
		}

# we have to read more text so get the handle and the current read size

		$handle = $self->{'handle'} ;
		$read_size = $self->{'read_size'} ;

# after the first read, always read the maximum size

		$self->{'read_size'} = $max_read_size ;

# seek to the beginning of this block and save the new seek position

		$seek_pos -= $read_size ;
		sysseek( $handle, $seek_pos, 0 ) ;
		$self->{'seek_pos'} = $seek_pos ;

# read in the next (previous) block of text

		$read_cnt = sysread( $handle, $read_buf, $read_size ) ;

# prepend the read buffer to the leftover (possibly partial) line

		$text = $read_buf . ( pop @{$lines_ref} || '' ) ;

# split the buffer into a list of lines
# this may want to be $/ but reading files backwards assumes plain text and
# newline separators

		@{$lines_ref} = $text =~ /$self->{'rec_regex'}/g ;

#print "Lines \n=>", join( "<=\n=>", @{$lines_ref} ), "<=\n" ;

# convert those damned cr/lf lines to \n

		if ( $self->{'is_crlf'} ) {

			s/\015\012/\n/ for @{$lines_ref} ;
		}

	}
}

__END__


=head1 NAME

Backwards.pm -- Read a file backwards by lines.
 

=head1 Synopsis

    use Backwards ;

    # Object interface

    $bw = Backwards->new( 'log_file' ) or
		    die "can't read 'log_file' $!" ;

    while( defined( $log_line = $bw->readline ) ) {
	    print $log_line ;
    }

    # Tied Handle Interface

    tie *BW, 'log_file' or die "can't read 'log_file' $!" ;

    while( <BW> ) {
	    print ;
    }

=head1 DESCRIPTION
  

This module reads a file backwards line by line. It is simple to use,
memory efficient and fast. It supports both an object and a tied handle
interface.

It is intended for processing log and other similar text files which
typically have their newest entries appended to them. Files can have any
record separator string (as with $/) which is file specific and
defaults to a value suitable to the OS.


=head2 Object Interface
 

There are only 2 methods in Backwards' object interface, new and
readline.

=head2 new( $file, [$rec_sep] )

New takes as arguments a filename and an optional record separator. It
either returns the object on a successful open or undef upon failure. $!
is set to the error code if any.

=head2 readline

Readline takes no arguments and it returns the previous line in the file
or undef when there are no more lines in the file.


=head2 Tied Handle Interface

=head2 tie( *HANDLE, File::ReadBackwards, $file, [$rec_sep] )
 

The TIEHANDLE and READLINE methods are aliased to the new and readline
methods respectively so refer to them for their arguments and API.  Once
you have tied a handle to File::ReadBackwards the only operation
permissible is <> which will read the previous line. All other tied
handle operations will generate an unknown method error. Do not seek,
write or perform any other operation other than <> on the tied handle.

=head1 Line and Record Endings
 

Since this module needs to use low level I/O for efficiency, it can't
portably seek and do block I/O without managing line ending conversions.
This module supports the default record separators of normal
line ending strings used on the OS. You can also set the separator on a
per file basis. If the default separator is used and it is CR/LF (e.g,
VMS, redmondware) it will be converted to a single newline. Unix and
MacOS files systems use only a single character for line endings and the
read lines are left unchanged.

=head1 Design

It works by reading a large (8kb) block of data from the end of the
file.  It then splits them on the record separator and stores a list of
records in the object. Each call to readline returns the top record of
the list and if the list is empty it refills it by reading the previous
block from the file and splitting it.  When the beginning of the file is
reached and there are no more lines, undef is returned.  All boundary
conditions are handled correctly i.e. if there is a trailing partial
line (no newline) it will be the first line returned and lines larger
than the read buffer size are handled properly.


=head1 Notes
 

There is no support for list context in either the object or tied
interfaces. If you want to slurp all of the lines into an array in
backwards order (and you don't care about memory usage) just do:

	@back_lines = reverse <FH>.

This module is only intended to read one line at a time from the end of
a file to the beginning.

=head1 Author
 

Uri Guttman, uri@sysarch.com

=head1 Copyright
 

Copyright (C) 2000 by Uri Guttman. All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
