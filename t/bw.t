#!/usr/local/bin/perl -ws

use strict ;
use Test::More ;
use File::ReadBackwards ;
use Carp ;

use vars qw( $opt_v ) ;

my $file = 'bw.data' ;

my $is_crlf = ( $^O =~ /win32/i || $^O =~ /vms/i ) ;

print "nl\n" ;
my @nl_data = init_data( "\n" ) ;
plan( tests => 8 * @nl_data + 1 ) ;
test_read_backwards( \@nl_data ) ;

print "crlf\n" ;
my @crlf_data = init_data( "\015\012" ) ;
test_read_backwards( \@crlf_data, "\015\012" ) ;

test_close() ;
unlink $file ;

exit ;

sub init_data {

	my ( $rec_sep ) = @_ ;

	return map { ( my $data = $_ ) =~ s/RS/$rec_sep/g ; $data }
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
	;
}

sub test_read_backwards {

	my( $data_list_ref, $rec_sep ) = @_ ;

	foreach my $data ( @$data_list_ref ) {


		if ( defined $rec_sep ) { 

			write_bin_file( $file, $data ) ;

# print "cnt: ${\scalar @rev_file_lines}\n" ;

		}
		else {
			write_file( $file, $data ) ;

		}

		my @rev_file_lines = reverse read_bin_file( $file ) ;
		if ( $is_crlf || $rec_sep && $rec_sep eq "\015\012" ) {
			s/\015\012\z/\n/ for @rev_file_lines ;
		}

		my $bw = File::ReadBackwards->new( $file, $rec_sep ) or
					die "can't open $file: $!" ;

		my( @bw_file_lines ) ;
		while ( defined( my $line = $bw->readline() ) ) {
			push( @bw_file_lines, $line) ;
		}

		ok( $bw->close(), 'close' ) ;

		if ( join( '', @rev_file_lines ) eq
		     join( '', @bw_file_lines ) ) {

			ok( 1, 'read' ) ;
		}
		else {
			ok( 0, 'read' ) ;
			if ( $opt_v || 1) {
				print "[$rev_file_lines[0]]\n" ;
				print unpack( 'H*', $rev_file_lines[0] ), "\n" ;
				print unpack( 'H*', $bw_file_lines[0] ), "\n" ;
			}

 print "REV ", unpack( 'H*', join '',@rev_file_lines ), "\n" ;
 print "BW  ", unpack( 'H*', join '',@bw_file_lines ), "\n" ;
		}

		$bw = File::ReadBackwards->new( $file, $rec_sep ) or
					die "can't open $file: $!" ;

		my $line1 = $bw->readline() ;
		my $pos = $bw->tell() ;
#print "BW pos = $pos\n" ;
		if ( !$bw->eof() ) {
			my $old_rec_sep = $/ ; 
			local $/ = $rec_sep || $old_rec_sep ;

			open FH, $file or die "tell open $!" ;
			seek FH, $pos, 0 or die "tell seek $!" ;
			my $line2 = <FH> ;
			$line2 =~ s/\015\012\z/\n/ ;

print "BW [", unpack( 'H*', $line1 ),
  "] TELL [", unpack( 'H*', $line2), "]\n" if $line1 ne $line2 ; 

			is ( $line1, $line2, "tell check" ) ;
		}
		else {
			ok( 1, "skip tell check" ) ;
		}

		ok( $bw->close(), 'close2' ) ;
	}
}

sub test_close {

	write_file( $file, <<BW ) ;
line1
line2
BW

	my $bw = File::ReadBackwards->new( $file ) or
					die "can't open $file: $!" ;

	my $line = $bw->readline() ;

	$bw->close() ;

	if ( $bw->readline() ) {

		ok( 0, 'close' ) ;
		return ;
	}

	ok( 1, 'close' ) ;
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

