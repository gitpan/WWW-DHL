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

our $VERSION = '0.02';

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

	return $self;
}

sub _post
{
	my $self = shift;
	my $url = shift;
	my $form = shift;

	my $post = $self->post($url, $form);

	unless($post->is_success())
	{
		eval { die $post->status_line() };
		return undef;
	}

	return $post->content();
}

sub _parser
{
	my $self = shift;
	my $doc = shift;
	my $parser = HTML::TokeParser->new(\$doc);

	my %ret;
	my @temp;
	while(my $t = $parser->get_token())
	{
		next unless $t->[0] eq 'S' && ($t->[1] eq 'td' || $t->[1] eq 'strong');
		my $var = $parser->get_text();

		chomp $var;
		$var =~ s#^\s+##;
		$var =~ s#\s+\z##;

		next unless $var;
		next if $var eq "[IMG]";
		next if $var =~ m#^\s+\z#;

		$var =~ s/:\z//;
		decode_entities($var);

		push @temp, $var;
	}

	splice(@temp, 0, 2);
	push @temp, undef unless $#temp % 2;

	die("Could not fetch the status...") if grep { $_ && m#\[IMG\]# } @temp;

	%ret = @temp;
	return \%ret;
}

sub status
{
	my $self = shift;
	my $ref = {};

	my %hash = (ID=>'idc', Zip=>'zip', Abroad=>'internationalShipment', Reference=>'rfn');
	while(my ($k, $v) = each (%hash))
	{
		$ref->{$v} = $self->{$k} if $self->{$k};
	}

	my $doc = $self->_post($self->{'Base'}, $ref) || die($@);
	my $stat = $self->_parser($doc);

	return $stat;
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
there are many different pages on the DHL website.

=head1 METHODS

=over 4

=item DHL->new()

Obligatory method to create the DHL object. You can pass the following
fields: ID, Zip, Reference and Abroad.

=item $dhl->status()

This method will try to fetch the status from the website. If there is
an error, it will return undef and set $@. Otherwise you will get a 
hashref containing everything we could find at the status page.

=back

=head1 BUGS

Please contact the author, if you find bugs in this code.

=head1 AUTHOR

Sebastian Stumpf E<lt>sepp@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2007 Sebastian Stumpf.   All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

LWP::UserAgent(3), HTML::TokeParser(3), http://www.dhl.de/

=cut
