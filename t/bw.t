#!/usr/local/bin/perl -ws

use strict ;
use Test ;
use File::ReadBackwards ;
use Carp ;

use vars qw( $opt_v ) ;

my( $file, @nl_data, @crlf_data ) ;

init_data() ;

plan( tests => 2 * @nl_data ) ;

$file = 'bw.data' ;

print "nl\n" ;

test_read_backwards( \@nl_data ) ;

print "crlf\n" ;

test_read_backwards( \@crlf_data, "\015\012" ) ;

unlink $file ;

exit ;

sub init_data {

	my( $test_ref, $template, $data, $data_list, $rec_sep ) ;

	foreach $test_ref (	[ \@nl_data, "\n" ],
				[ \@crlf_data, "\015\012" ] ) {

		( $data_list, $rec_sep ) = @{$test_ref} ;

		foreach $template (
				'',
				'RS',
				'RSRS',
				'RSRSRS',
				"\015",
				"\015RSRS",
				'abcd',
				"abcdefghijRS",
				"abcdefghijRS" x 512,
				'a' x (8 * 1024),
				'a' x (8 * 1024) . '0',
				'0' x (8 * 1024) . '0',
				'a' x (32 * 1024),
				join( 'RS', '00' .. '99', '' ),
				join( 'RS', '00' .. '99' ),
				join( 'RS', '0000' .. '9999', '' ),
				join( 'RS', '0000' .. '9999' ),
			) {

			( $data = $template ) =~ s/RS/$rec_sep/g ;

			push @{$data_list}, $data ;
		}
	}
}

sub test_read_backwards {

	my( $data_list_ref, $rec_sep ) = @_ ;

	my( $data, @rev_file_lines, @bw_file_lines, $bw, $line, @sep_arg ) ;

	foreach $data ( @$data_list_ref ) {

		if ( defined $rec_sep ) { 

			write_bin_file( $file, $data ) ;

			@rev_file_lines = reverse read_bin_file( $file,
								 $rec_sep ) ;

# print "cnt: ${\scalar @rev_file_lines}\n" ;

			@sep_arg = $rec_sep ;
		}
		else {
			write_file( $file, $data ) ;

			@rev_file_lines = reverse read_file( $file ) ;
		}

		@bw_file_lines = () ;
		$bw = File::ReadBackwards->new( $file, @sep_arg ) or
					die "can't open $file: $!" ;

		push( @bw_file_lines, $line)
				while defined( $line = $bw->readline() ) ;

		$bw->close() ;

		if ( join( '', @rev_file_lines ) eq
		     join( '', @bw_file_lines ) ) {

			ok( 1 ) ;
		}
		else {
			ok( 0 ) ;
			if ( $opt_v ) {
				print "[$rev_file_lines[0]]\n" ;
				print unpack( 'H*', $rev_file_lines[0] ), "\n" ;
				print unpack( 'H*', $bw_file_lines[0] ), "\n" ;
			}

	#		print unpack( 'H*', join '',@rev_file_lines ), "\n" ;
	#		print unpack( 'H*', join '',@bw_file_lines ), "\n" ;
		}
	}
}

sub read_file {

	my( $file_name ) = shift ;

	local( *FH ) ;

	open( FH, $file_name ) || carp "can't open $file_name $!" ;

	local( $/ ) unless wantarray ;

	<FH>
}

# utility sub to write a file. takes a file name and a list of strings

sub write_file {

	my( $file_name ) = shift ;

	local( *FH ) ;

	open( FH, ">$file_name" ) || carp "can't create $file_name $!" ;

	print FH @_ ;
}



sub read_bin_file {

	my( $file_name ) = shift ;

	local( *FH ) ;
	open( FH, $file_name ) || carp "can't open $file_name $!" ;
	binmode( FH ) ;

	local( $/ ) = shift if @_ ;

	local( $/ ) unless wantarray ;

	<FH>
}

# utility sub to write a file. takes a file name and a list of strings

sub write_bin_file {

	my( $file_name ) = shift ;

	local( *FH ) ;
	open( FH, ">$file_name" ) || carp "can't create $file_name $!" ;
	binmode( FH ) ;

	print FH @_ ;
}
