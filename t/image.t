use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Image::ExifTool;
use Test::Spec;
use Test::Exception;
# classes under test:
use HTFeed::Image::Grok;
use HTFeed::Image::Magick;

my $test_dir      = "/tmp/imgtest";
my $reference_dir = "/usr/local/feed/t/fixtures/reference_images";

describe "HTFeed::Image" => sub {
    before each => sub {
        # Clean copy of reference images for each test.
        system("rm -rf '$test_dir'");
        system("mkdir '$test_dir'");
    };
    # Put a fresh copy of the requested reference input file
    # in the testing directory before running a test.
    sub cp_to_test {
        my $imgname = shift;
        system("cp $reference_dir/$imgname $test_dir/$imgname");
    }
    # Assert that the 1st file is bigger than the 2nd (input order matters).
    sub bigger_than {
        ok(-s $_[0] > -s $_[1]);
    }
    # We want to fail a test that e.g. thinks it wrote a tiff but didn't.
    sub check_outfile {
        my $outfile = shift;
        # Check that outfile exists & isn't empty.
        ok(-f $outfile);
        ok(-s $outfile > 0);

        # Check file ext on outfile...
        my $ext = "";
        if ($outfile =~ m/\.(\S+)$/) {
            $ext = $1;
        } else {
            die "no ext on outfile\n";
        }

        # ... and compare file ext against exiftool's idea of filetype.
        my $exifTool = new Image::ExifTool;
        $exifTool->ExtractInfo($outfile, {Binary => 1});
        my $exif_filetype = $exifTool->GetValue("FileType");
        if ($ext eq "jp2") {
            ok($exif_filetype eq "JP2");
        } elsif ($ext eq "tif") {
            ok($exif_filetype eq "TIFF");
        } else {
            ok(0);
        }
    }
    it "can decompress a jpeg2000 to a tiff w/ Grok" => sub {
        #
    };
    it "can compress a tiff to a jpeg2000 w/ Grok" => sub {
        cp_to_test("autumn.tif");
        my $in  = "$test_dir/autumn.tif";
        my $out = "$test_dir/autumn_out.jp2";
        my $res = HTFeed::Image::Grok::compress($in, $out);
        ok($res);
        check_outfile($out);
        bigger_than($in, $out);
    };
    it "can convert a png to a tiff w/ Magick" => sub {
        cp_to_test("autumn.png");
        my $in   = "$test_dir/autumn.png";
        my $out  = "$test_dir/autumn_out.tif";
        my %args = (-compress => 'None', '-type' => 'TrueColor');
        my $res  = HTFeed::Image::Magick::compress($in, $out, %args);
        ok($res);
        check_outfile($out);
        bigger_than($out, $in);
    };
    it "can compress a jpg to a tiff w/ Magick" => sub {
        cp_to_test("plywood.jpg");
        my $in   = "$test_dir/plywood.jpg";
        my $out  = "$test_dir/plywood_out.tif";
        my %args = (-compress => 'None', '-type' => 'TrueColor');
        my $res  = HTFeed::Image::Magick::compress($in, $out, %args);
        ok($res);
        check_outfile($out);
        bigger_than($out, $in);
    };
    it "can convert a truecolor tiff to a jpeg2000 w/ Magick" => sub {
        cp_to_test("autumn.tif");
        my $in   = "$test_dir/autumn.tif";
        my $out  = "$test_dir/autumn_out.jp2";
        my %args = (-compress => 'None', '-type' => 'TrueColor');
        my $res  = HTFeed::Image::Magick::compress($in, $out, %args);
        ok($res);
        check_outfile($out);
        bigger_than($in, $out);
    };
    it "can convert a grayscale tiff to a jpeg2000 w/ Magick" => sub {
        cp_to_test("circuit_grayscale.tif");
        my $in   = "$test_dir/circuit_grayscale.tif";
        my $out  = "$test_dir/circuit_grayscale_out.jp2";
        my %args = (-compress => 'None', '-type' => 'Grayscale');
        my $res  = HTFeed::Image::Magick::compress($in, $out, %args);
        ok($res);
        check_outfile($out);
        bigger_than($in, $out);
    };
    it "catches error code in dollar-questionmark" => sub {
        cp_to_test("circuit_grayscale.tif");
        my $in   = "$test_dir/circuit_grayscale.tif";
        # bad extension ".bork", should trigger failure
        my $out  = "$test_dir/circuit_grayscale_out.bork";
        my $res  = HTFeed::Image::Grok::compress($in, $out);
        # expecting failure
        ok($res == 0);
        # expecting a non-zero failure code
        my $error_code = $?;
        ok($error_code > 0);
    };
};

runtests unless caller;
