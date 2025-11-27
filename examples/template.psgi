#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Trickster;
use Trickster::Template;

my $app = Trickster->new(debug => 1);

# Initialize template engine
my $template = Trickster::Template->new(
    path => ["$FindBin::Bin/../templates"],
    cache => 0, # Disable cache for development
    layout => 'layouts/main.tx',
    default_vars => {
        app_name => 'Trickster Demo',
    },
);

# Home page - standalone HTML
$app->get('/', sub {
    my ($req, $res) = @_;
    
    my $html = $template->render('index.html.tx', {
        no_layout => 1,
    });
    
    return $res->html($html);
});

# Example with layout
$app->get('/about', sub {
    my ($req, $res) = @_;
    
    my $html = $template->render_string(q{
        <div class="card">
            <h2>About Trickster</h2>
            <p style="color: #64748b; line-height: 1.6; margin-top: 1rem;">
                Trickster is a modern, battle-tested micro-framework for building web applications in Perl.
            </p>
            
            <h3 style="margin-top: 2rem;">Features</h3>
            <ul style="margin-left: 1.5rem; margin-top: 1rem; color: #475569; line-height: 1.8;">
                <li>Fast routing with constraints</li>
                <li>Stateless signed-cookie sessions</li>
                <li>Template engine with Text::Xslate</li>
                <li>Production-ready middleware</li>
                <li>Zero dependencies core</li>
            </ul>
            
            <div style="margin-top: 2rem; padding-top: 2rem; border-top: 1px solid #e2e8f0;">
                <a href="/" style="color: #667eea; text-decoration: none; font-weight: 500;">← Back to Home</a>
            </div>
        </div>
    }, {
        title => 'About - Trickster Demo',
    });
    
    return $res->html($html);
});

# API endpoint example
$app->get('/api/info', sub {
    my ($req, $res) = @_;
    
    return $res->json({
        name => 'Trickster',
        version => '0.01',
        features => [
            'Fast routing',
            'Stateless sessions',
            'Template engine',
            'Middleware support',
        ],
    });
});

$app->to_app;
