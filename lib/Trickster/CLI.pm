package Trickster::CLI;

use strict;
use warnings;
use v5.14;

use File::Path qw(make_path);
use File::Spec;
use Cwd qw(getcwd);
use Getopt::Long qw(GetOptionsFromArray);

our $VERSION = '0.01';

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub run {
    my ($class, @args) = @_;
    
    my $self = $class->new;
    
    unless (@args) {
        $self->show_help;
        return;
    }
    
    my $command = shift @args;
    
    my $method = "cmd_$command";
    if ($self->can($method)) {
        $self->$method(@args);
    } else {
        say "Unknown command: $command";
        say "Run 'trickster help' for usage information.";
        exit 1;
    }
}

sub cmd_help {
    my ($self) = @_;
    $self->show_help;
}

sub show_help {
    say "Trickster v$VERSION - Modern Perl Web Framework";
    say "";
    say "Usage: trickster <command> [options]";
    say "";
    say "Commands:";
    say "  new <name>              Create a new Trickster application";
    say "  generate <type> <name>  Generate a component (controller, model, template)";
    say "  server [options]        Start the development server";
    say "  routes                  Display all registered routes";
    say "  version                 Show Trickster version";
    say "  help                    Show this help message";
    say "";
    say "Examples:";
    say "  trickster new myapp";
    say "  trickster generate controller User";
    say "  trickster server --port 3000";
    say "  trickster routes";
}

sub cmd_version {
    my ($self) = @_;
    say "🎩 Trickster v$VERSION";
    say "Perl $^V";
}

sub cmd_new {
    my ($self, $name, @args) = @_;
    
    unless ($name) {
        say "Error: Application name required";
        say "Usage: trickster new <name>";
        exit 1;
    }
    
    if (-e $name) {
        say "Error: Directory '$name' already exists";
        exit 1;
    }
    
    say "Creating new Trickster application: $name";
    say "";
    
    # Create directory structure
    my @dirs = (
        $name,
        "$name/lib",
        "$name/lib/$name",
        "$name/lib/$name/Controller",
        "$name/lib/$name/Model",
        "$name/templates",
        "$name/templates/layouts",
        "$name/public",
        "$name/public/css",
        "$name/public/js",
        "$name/t",
    );
    
    for my $dir (@dirs) {
        make_path($dir);
        say "  Created: $dir/";
    }
    
    # Create files
    $self->create_app_file($name);
    $self->create_cpanfile($name);
    $self->create_gitignore($name);
    $self->create_readme($name);
    $self->create_layout($name);
    $self->create_css($name);
    $self->create_home_template($name);
    $self->create_test($name);
    
    say "";
    say "✓ Application created successfully!";
    say "";
    say "Next steps:";
    say "  cd $name";
    say "  cpanm --installdeps .";
    say "  trickster server";
    say "";
    say "Visit http://localhost:5678";
}

sub create_app_file {
    my ($self, $name) = @_;
    
    my $content = <<"EOF";
#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "\$FindBin::Bin/lib";

use Trickster;
use Trickster::Template;

my \$app = Trickster->new(debug => 1);

# Initialize template engine
my \$template = Trickster::Template->new(
    path => ["\$FindBin::Bin/templates"],
    cache => 0,
    layout => 'layouts/main.tx',
    default_vars => {
        app_name => '$name',
    },
);

# Routes
\$app->get('/', sub {
    my (\$req, \$res) = \@_;
    
    # Home page is a complete HTML document, no layout needed
    my \$html = \$template->render('home.tx', {
        app_name => '$name',
        no_layout => 1,
    });
    
    return \$res->html(\$html);
});

# Serve static files
my \$psgi_app = \$app->to_app;

sub {
    my \$env = shift;
    my \$path = \$env->{PATH_INFO};
    
    # Serve static files
    if (\$path =~ m{^/(css|js|images)/}) {
        my \$file = "\$FindBin::Bin/public\$path";
        if (-f \$file) {
            open my \$fh, '<', \$file or return [500, ['Content-Type' => 'text/plain'], ['Error reading file']];
            my \$content = do { local \$/; <\$fh> };
            close \$fh;
            
            my \$type = \$path =~ /\.css\$/ ? 'text/css' :
                        \$path =~ /\.js\$/ ? 'application/javascript' :
                        'application/octet-stream';
            
            return [200, ['Content-Type' => \$type], [\$content]];
        }
    }
    
    # Route to app
    return \$psgi_app->(\$env);
};
EOF
    
    my $file = "$name/app.psgi";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    chmod 0755, $file;
    
    say "  Created: $file";
}

sub create_cpanfile {
    my ($self, $name) = @_;
    
    my $content = <<'EOF';
requires 'perl', '5.014';
requires 'Trickster';
requires 'Text::Xslate';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Plack::Test';
};
EOF
    
    my $file = "$name/cpanfile";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "  Created: $file";
}

sub create_gitignore {
    my ($self, $name) = @_;
    
    my $content = <<'EOF';
*.swp
*.bak
*~
.DS_Store
local/
.carton/
EOF
    
    my $file = "$name/.gitignore";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "  Created: $file";
}

sub create_readme {
    my ($self, $name) = @_;
    
    my $content = <<"EOF";
# $name

A Trickster web application.

## Installation

```bash
cpanm --installdeps .
```

## Running

```bash
plackup app.psgi
```

Visit http://localhost:5678

## Development

```bash
plackup -R lib,templates app.psgi
```

## Testing

```bash
prove -l t/
```
EOF
    
    my $file = "$name/README.md";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "  Created: $file";
}

sub create_layout {
    my ($self, $name) = @_;
    
    my $content = <<'EOF';
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>[% title || app_name %]</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <header>
        <h1>[% app_name %]</h1>
    </header>
    
    <main>
        [% content %]
    </main>
    
    <footer>
        <p>Powered by Trickster</p>
    </footer>
</body>
</html>
EOF
    
    my $file = "$name/templates/layouts/main.tx";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "  Created: $file";
}

sub create_css {
    my ($self, $name) = @_;
    
    my $content = <<'EOF';
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Helvetica', 'Arial', sans-serif;
    line-height: 1.6;
    color: #24292f;
    background: #f6f8fa;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
}

.header {
    background: #ffffff;
    border-bottom: 1px solid #d0d7de;
    padding: 1.5rem 0;
    margin-bottom: 2rem;
}

.header-content {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.brand {
    font-size: 1.5rem;
    font-weight: 600;
    color: #24292f;
    text-decoration: none;
}

.nav {
    display: flex;
    gap: 2rem;
}

.nav a {
    color: #57606a;
    text-decoration: none;
    font-weight: 500;
}

.nav a:hover {
    color: #24292f;
}

.card {
    background: #ffffff;
    border: 1px solid #d0d7de;
    border-radius: 6px;
    padding: 2rem;
    margin-bottom: 1.5rem;
}

.card h1 {
    font-size: 2rem;
    font-weight: 600;
    color: #24292f;
    margin-bottom: 0.5rem;
}

.card h2 {
    font-size: 1.5rem;
    font-weight: 600;
    color: #24292f;
    margin-bottom: 1rem;
}

.card p {
    color: #57606a;
    margin-bottom: 1rem;
}

.alert {
    background: #dff6dd;
    border: 1px solid #2da44e;
    border-radius: 6px;
    padding: 1rem;
    margin-bottom: 1.5rem;
}

.alert-success {
    color: #1a7f37;
}

.features {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
    margin: 1.5rem 0;
}

.feature {
    background: #f6f8fa;
    border: 1px solid #d0d7de;
    border-radius: 6px;
    padding: 1rem;
}

.feature-title {
    font-weight: 600;
    color: #24292f;
    margin-bottom: 0.25rem;
}

.feature-desc {
    font-size: 0.875rem;
    color: #57606a;
}

.code-block {
    background: #24292f;
    color: #f6f8fa;
    padding: 1rem;
    border-radius: 6px;
    font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
    font-size: 0.875rem;
    overflow-x: auto;
}

.btn {
    display: inline-block;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    text-decoration: none;
    font-weight: 500;
    border: 1px solid #d0d7de;
}

.btn-primary {
    background: #24292f;
    color: #ffffff;
    border-color: #24292f;
}

.btn-secondary {
    background: #ffffff;
    color: #24292f;
}

.footer {
    text-align: center;
    padding: 2rem;
    color: #57606a;
    font-size: 0.875rem;
    border-top: 1px solid #d0d7de;
    margin-top: 3rem;
}

.footer a {
    color: #0969da;
    text-decoration: none;
}

.footer a:hover {
    text-decoration: underline;
}
EOF
    
    my $file = "$name/public/css/style.css";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "  Created: $file";
}

sub create_home_template {
    my ($self, $name) = @_;
    
    my $content = <<'EOF';
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>[% app_name %]</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <div class="header">
        <div class="header-content">
            <a href="/" class="brand">🎩 [% app_name %]</a>
            <nav class="nav">
                <a href="/">Home</a>
                <a href="https://github.com/tricksterperl/trickster" target="_blank">GitHub</a>
            </nav>
        </div>
    </div>
    
    <div class="container">
        <div class="alert alert-success">
            ✓ Your Trickster application is running successfully
        </div>
        
        <div class="card">
            <h1>Welcome to [% app_name %]</h1>
            <p>A modern Perl web application powered by Trickster.</p>
        </div>
        
        <div class="card">
            <h2>Features</h2>
            <div class="features">
                <div class="feature">
                    <div class="feature-title">⚡ Fast Routing</div>
                    <div class="feature-desc">Advanced routing with constraints and named routes</div>
                </div>
                <div class="feature">
                    <div class="feature-title">🔐 Stateless Sessions</div>
                    <div class="feature-desc">Secure signed-cookie sessions for production</div>
                </div>
                <div class="feature">
                    <div class="feature-title">📦 Zero Dependencies</div>
                    <div class="feature-desc">Minimal core, maximum power</div>
                </div>
                <div class="feature">
                    <div class="feature-title">🚀 Production Ready</div>
                    <div class="feature-desc">Battle-tested patterns and middleware</div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h2>Quick Start</h2>
            <p>Generate a new controller:</p>
            <div class="code-block">trickster generate controller Home</div>
            <p style="margin-top: 1rem;">
                <a href="https://github.com/tricksterperl/trickster" class="btn btn-primary" target="_blank">View on GitHub</a>
                <a href="https://github.com/tricksterperl/trickster#readme" class="btn btn-secondary" target="_blank" style="margin-left: 0.5rem;">Documentation</a>
            </p>
        </div>
    </div>
    
    <div class="footer">
        Built with Trickster • <a href="https://github.com/tricksterperl/trickster" target="_blank">github.com/tricksterperl/trickster</a>
    </div>
</body>
</html>
EOF
    
    my $file = "$name/templates/home.tx";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "  Created: $file";
}

sub create_test {
    my ($self, $name) = @_;
    
    my $content = <<'EOF';
use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

require './app.psgi';
my $app = do './app.psgi';

test_psgi $app, sub {
    my $cb = shift;
    
    my $res = $cb->(GET '/');
    is $res->code, 200, 'GET / returns 200';
    like $res->content, qr/Welcome/, 'Home page contains welcome message';
};

done_testing;
EOF
    
    my $file = "$name/t/01-basic.t";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "  Created: $file";
}

sub cmd_generate {
    my ($self, $type, $name, @args) = @_;
    
    unless ($type && $name) {
        say "Error: Type and name required";
        say "Usage: trickster generate <type> <name>";
        say "Types: controller, model, template";
        exit 1;
    }
    
    my $method = "generate_$type";
    if ($self->can($method)) {
        $self->$method($name, @args);
    } else {
        say "Error: Unknown type '$type'";
        say "Available types: controller, model, template";
        exit 1;
    }
}

sub generate_controller {
    my ($self, $name) = @_;
    
    my $app_name = $self->detect_app_name;
    
    my $content = <<"EOF";
package ${app_name}::Controller::${name};

use strict;
use warnings;
use v5.14;

sub new {
    my (\$class) = \@_;
    return bless {}, \$class;
}

sub index {
    my (\$self, \$req, \$res) = \@_;
    
    return \$res->json({ message => 'Hello from ${name} controller' });
}

sub show {
    my (\$self, \$req, \$res) = \@_;
    my \$id = \$req->param('id');
    
    return \$res->json({ id => \$id });
}

1;
EOF
    
    my $file = "lib/${app_name}/Controller/${name}.pm";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "✓ Created controller: $file";
    say "";
    say "Add to your app.psgi:";
    say "  use ${app_name}::Controller::${name};";
    say "  my \$${name}_controller = ${app_name}::Controller::${name}->new;";
    say "  \$app->get('/${name}', sub { \$${name}_controller->index(\@_) });";
}

sub generate_model {
    my ($self, $name) = @_;
    
    my $app_name = $self->detect_app_name;
    
    my $content = <<"EOF";
package ${app_name}::Model::${name};

use strict;
use warnings;
use v5.14;

sub new {
    my (\$class, %opts) = \@_;
    
    return bless {
        data => {},
        %opts,
    }, \$class;
}

sub find {
    my (\$self, \$id) = \@_;
    return \$self->{data}{\$id};
}

sub all {
    my (\$self) = \@_;
    return [values %{\$self->{data}}];
}

sub create {
    my (\$self, \$data) = \@_;
    
    my \$id = time . int(rand(1000));
    \$self->{data}{\$id} = { id => \$id, %\$data };
    
    return \$self->{data}{\$id};
}

sub update {
    my (\$self, \$id, \$data) = \@_;
    
    return unless exists \$self->{data}{\$id};
    
    \$self->{data}{\$id} = { %{\$self->{data}{\$id}}, %\$data };
    
    return \$self->{data}{\$id};
}

sub delete {
    my (\$self, \$id) = \@_;
    return delete \$self->{data}{\$id};
}

1;
EOF
    
    my $file = "lib/${app_name}/Model/${name}.pm";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "✓ Created model: $file";
    say "";
    say "Use in your app:";
    say "  use ${app_name}::Model::${name};";
    say "  my \$${name}_model = ${app_name}::Model::${name}->new;";
}

sub generate_template {
    my ($self, $name) = @_;
    
    my $content = <<'EOF';
<div class="page">
    <h2>[% title %]</h2>
    <p>Template content goes here.</p>
</div>
EOF
    
    my $file = "templates/${name}.tx";
    open my $fh, '>', $file or die "Cannot create $file: $!";
    print $fh $content;
    close $fh;
    
    say "✓ Created template: $file";
    say "";
    say "Render in your route:";
    say "  my \$html = \$template->render('${name}.tx', { title => 'Page Title' });";
}

sub detect_app_name {
    my ($self) = @_;
    
    my $cwd = getcwd;
    my $app_name = (split '/', $cwd)[-1];
    
    # Capitalize first letter
    $app_name = ucfirst($app_name);
    
    return $app_name;
}

sub cmd_server {
    my ($self, @args) = @_;
    
    my $port = 5678;
    my $host = '0.0.0.0';
    my $reload = 0;
    
    GetOptionsFromArray(\@args,
        'port|p=i' => \$port,
        'host|h=s' => \$host,
        'reload|r' => \$reload,
    );
    
    unless (-f 'app.psgi') {
        say "Error: app.psgi not found";
        say "Run this command from your application directory";
        exit 1;
    }
    
    say "Starting Trickster development server...";
    say "Listening on http://$host:$port";
    say "Press Ctrl+C to stop";
    say "";
    
    my @cmd = ('plackup', '--port', $port, '--host', $host);
    push @cmd, '-R', 'lib,templates' if $reload;
    push @cmd, 'app.psgi';
    
    exec @cmd;
}

sub cmd_routes {
    my ($self) = @_;
    
    unless (-f 'app.psgi') {
        say "Error: app.psgi not found";
        exit 1;
    }
    
    say "Loading routes from app.psgi...";
    say "";
    
    # This is a simplified version - in a real implementation,
    # we'd need to parse the app.psgi file or load the app
    say "Note: Route inspection requires loading the application.";
    say "This feature will be enhanced in future versions.";
    say "";
    say "For now, check your app.psgi file for route definitions.";
}

1;

__END__

=head1 NAME

Trickster::CLI - Command-line interface for Trickster framework

=head1 SYNOPSIS

    use Trickster::CLI;
    
    Trickster::CLI->run(@ARGV);

=head1 DESCRIPTION

Trickster::CLI provides command-line tools for creating and managing
Trickster web applications.

=head1 COMMANDS

=head2 new <name>

Creates a new Trickster application with the following structure:

    myapp/
    ├── app.psgi
    ├── cpanfile
    ├── lib/
    │   └── MyApp/
    │       ├── Controller/
    │       └── Model/
    ├── templates/
    │   └── layouts/
    ├── public/
    │   ├── css/
    │   └── js/
    └── t/

=head2 generate <type> <name>

Generates a new component:

=over 4

=item * controller - Creates a new controller class

=item * model - Creates a new model class

=item * template - Creates a new template file

=back

=head2 server [options]

Starts the development server.

Options:

=over 4

=item * --port, -p - Port number (default: 5678)

=item * --host, -h - Host address (default: 0.0.0.0)

=item * --reload, -r - Auto-reload on file changes

=back

=head2 routes

Displays all registered routes in the application.

=head2 version

Shows the Trickster version.

=cut
