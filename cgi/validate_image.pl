#!/usr/bin/perl

BEGIN {
    $ENV{HTFEED_CONFIG} = '/htapps/aelkiss.babel/feed/etc/config_dev.yaml';
    print "Content-type: text/html\n\n";
}

use strict;
use lib "/htapps/aelkiss.babel/feed/lib";
use CGI;
use Data::Dumper;
use HTFeed::Log {root_logger => 'INFO, html'};
use HTFeed::Config qw(set_config);
use HTFeed::TestVolume;
use Log::Log4perl qw(get_logger);
use File::Temp qw(tempfile);
use File::Basename qw(basename dirname);
use HTFeed::XMLNamespaces qw(register_namespaces);

my $q = new CGI;
$CGI::POST_MAX = 1024*1024*16384;
my $upload_filename = $q->param('file');
my $namespace = $q->param('namespace');
my $packagetype = $q->param('packagetype');
my $objid = $q->param('objid');

$namespace = 'mdp' unless defined $namespace;
$packagetype = 'google' unless defined $packagetype;

my $suffix;

print <<EOT;
<html>
<head>
<style>
body {
  font-family: Trebuchet MS, Helvetica, sans-serif;
}
p {
    font-size: 10pt;
}

</style>
</head>
<body>
<h3>Validation report for $upload_filename</h3>
EOT

if($upload_filename =~ /(\.jp2|\.tif)$/) {
    $suffix = $1;
} else {
    print "Only JPEG2000 (.jp2) and TIFF (.tif) files are supported!";
    exit(1);
}

my ($temp_fh, $temp_filename) = tempfile(SUFFIX => $suffix);

my $upload_fh = $q->upload('file');

while(<$upload_fh>) {
    print $temp_fh $_;
}

close($temp_fh);
close($upload_fh);

# now try to run jhove?!?

# run validation
my $volume;
my $dir = dirname($temp_filename);
$volume = HTFeed::TestVolume->new(namespace => $namespace,packagetype => $packagetype,dir=>$dir,objid=>$objid) if (defined $objid);
$volume = HTFeed::TestVolume->new(namespace => $namespace,packagetype => $packagetype,dir=>$dir) if (! defined $objid);

my $vol_val = HTFeed::VolumeValidator->new(volume => $volume);

$vol_val->run_jhove($volume,$dir,[basename($temp_filename)], sub {
        my ($volume,$file,$node) = @_;

        my $xpc = XML::LibXML::XPathContext->new($node);
        register_namespaces($xpc);

        get_logger()->trace("validating $file");
        my $mod_val = HTFeed::ModuleValidator->new(
            xpc => $xpc,

            #node    => $node,
            volume   => $volume,
            # use original filename
            filename => $q->param('file')
        );
        $mod_val->run();

        # check, log success
        if ( $mod_val->succeeded() ) {
            print qq(<h4 style="color: #228022">File validation succeeded!</h4>);
            get_logger()->debug( "File validation succeeded",
                file => $file );
        }
        else {
            $vol_val->set_error( "BadFile", file => $file );
        }
    });

unlink($temp_filename);

print <<EOT;
</body>
</html>
EOT
