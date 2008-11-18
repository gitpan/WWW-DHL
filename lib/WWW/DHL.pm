#!/usr/bin/perl -w
# Copyright 2007 Sebastian Stumpf <mail@sebastianstumpf.de>
# Published under the terms of 4.4BSD
# vim: set sw=4 ts=4
package WWW::DHL;
use strict;
use warnings;
use base qw(LWP::UserAgent);
use HTML::TokeParser;
use HTML::Entities;

our $VERSION = '0.03';

sub new
{
	my $class = shift;
	my $self = { @_ };

	$self->{'Agent'}	||= 'Mozilla/5.0';
	$self->{'Base'}		||= 'http://nolp.dhl.de/nextt-online-public/set_identcodes.do?lang=de';
	bless $self, $class;

	$self->agent($self->{'Agent'});

	if($self->{'ID'})
	{
		die("Please don't use spaces for 'ID'")	if $self->{'ID'} =~ m#\s#;
		die("Please specify a valid ID")		if length($self->{'ID'}) < 12;
	}

	$self->{'Base'} .= "&idc=" . $self->{'ID'};

	return $self;
}

sub _parser
{
	my $doc = shift;
	my $parser = HTML::TokeParser->new(\$doc);

	my $temp;
	my @stack;

	my $sum = {};
	my $hist = [];

	while(my $t = $parser->get_token())
	{
		if($t->[0] eq 'S' && $t->[1] eq 'td' && $t->[2] && $t->[2]->{'class'} && $t->[2]->{'class'} eq 'label')
		{
			next if ~~ keys %$sum > 4;
			my $key = $parser->get_trimmed_text();
			$temp = $key unless $key eq 'Sendungsnummer';
		}
		elsif($t->[0] eq 'S' && $t->[1] eq 'td' && $t->[2] && $t->[2]->{'class'} && $t->[2]->{'class'} eq 'value')
		{
			if(~~ keys %$sum >= 4)
			{
				push @stack, $parser->get_trimmed_text();
			}
			else
			{
				my $value = $parser->get_trimmed_text();
				$sum->{$temp} = $value if $temp && $value;
			}
		}
	}


	$temp = [];
	while(@stack)
	{
		push @$temp, shift @stack;
		if(~~ @$temp == 3)
		{
			push @$hist, $temp;
			$temp = [];
		}
	}

	return({Summary => $sum, History => $hist});
}

sub status
{
	my $self = shift;
	my $get = $self->get($self->{'Base'});

	unless($get->is_success())
	{
		eval { die("GET request failed: ". $get->status_line()) };
		return undef;
	}

	my $stat = _parser($get->content());
}

return 1;
__END__

=head1 NAME

B<DHL> - Perl module for the DHL online tracking service.

=head1 SYNOPSIS

  my $dhl = DHL->new(ID => 12345);
  print Dumper $dhl->status();
  ...

=head1 DESCRIPTION

This module allows you to check the status of B<YOUR> shipments
via the DHL website. For privacy issues please consider the 
website.
B<Please note:> This module is still some kind of alpha, because
there are many different pages on the DHL website and they are 
changing constantly.

=head1 METHODS

=over 4

=item DHL->new()

Obligatory method to create the DHL object. You B<must> pass a valid
ID for your shipment.

=item $dhl->status()

This method will try to fetch the status from the website. If there is
an error, it will return undef and set $@. Otherwise you will get a 
hashref containing the summary and history of your shipment.

=back

=head1 BUGS

Please contact the author, if you find any in this code.

=head1 AUTHOR

Sebastian Stumpf E<lt>sepp@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2007 Sebastian Stumpf.   All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

LWP::UserAgent(3), HTML::TokeParser(3), http://www.dhl.de/

=cut
