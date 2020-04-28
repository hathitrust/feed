# Prerequisites, Installation and Configuration

See INSTALL

# Introduction

Feed is a suite of tools to assist in preparing content for ingest into
HathiTrust. Feed can assist in transforming and remediating content and
technical metadata, prevalidating the content to HathiTrust specifications, and
packaging content into a submission inventory package (SIP).

Feed is not a general-purpose validation environment: it is narrowly targeted
towards the needs of ingesting digitized print material into HathiTrust. Major
functionality includes remediating and prevalidating TIFF and JPEG2000 images,
creating METS files with PREMIS metadata, and packing files into a .zip for
submission to HathiTrust.

Feed works best out of the box when input volumes consist of sequentually-named
images and text files within a directory whose name is the ID that will be used
for the HathiTrust object. For example:

```
  39015012345678/
     00000001.jp2
     00000001.txt
     00000002.tif
     00000002.txt
     00000003.tif
     00000003.txt
```

Feed is very extensible; it can be adapted to remediate and package input of
almost any type, but the farther the departure from the simple layout above,
the more work will be required.

This guide assumes fluency with perl and the command-line environment of Linux
or Mac OS X as well as familiarity with digitization and digital preservation.
Some introductory references to consult include:

- Learning Perl
- Programming Perl
- Introduction to Linux: http://www.tldp.org/LDP/intro-linux/html/index.html
- Library of Congress's Digital Preservation web site: http://www.digitalpreservation.gov/


# Basic Concepts

Feed consists of various components which are assembled together to create a
pipeline for transformation, validation and packaging of digital objects.

## Stages

A stage is a discrete step in the transformation or ingestion of a digital object. Some examples include:

- Validation
- METS file creation
- Zip file creation
- Fixity checking

## Package Type

A package type is a description of a set of objects that share similar
characteristics. Normally, all items digitized from a single source using a
consistent process will share a package type. For example, all items digitized
by Google share a package type, as do all items digitized by the Internet
Archive.

Normally, local digitization wil require the creation of a new package type. In
some cases, existing package types may be able to be re-used, for example if
two different local ingest projects are doing digitization using the same
software or following the same specifications. In other instances, a similar
package type can be extended or adapted.

## Remediation

Remediation is the process of transforming images to meet HathiTrust
specifications.  This can include adding or correcting various image metadata
fields as well as correcting structural problems with the image using tools
such as ImageMagick and ExifTool. Image remediation does not affect the content
of the image.

## Validation

Validation is the process of ensuring all components of the package meet
HathiTrust specifications. This primarily includes ensuring that all technical
and descriptive image metadata is present and has the expected values, but also
that the submission package is complete and consistent. Validation uses the
package type specification to ensure that the submitted package meets the
declared specification.

## METS

METS is the Metadata Encoding and Transmission Standard from the Library of Congress. (CITEME)
It is used to fulfill several purposes in digital preservation:

- To encapsulate technical, descriptive and administrative metadata about the preserved object 
- To contain a manifest of the individual files present in the digital object
- To record the structure of the digital object

Feed supports creation of METS files using the subset of METS supported by
HathiTrust -- certain features such as the `structLink` and
`behavior` elements are not supported.

## PREMIS

PREMIS (Preservation Metadata: Implementaiton Strategies) is an XML schema for
recording various preservation-specific metadata about digital objects.  Feed
primarily uses PREMIS to record events that happened to the digital object, in
particular the original digitization as well as events occurring during
remediation and packaging. Feed supports recording events in a straightforward
and consistent fashion. Feed has limited support for the PREMIS `object`
element and does not support the `agent` or `rights` entity.

# Sample Code

The provided scripts can assist you with validating images and packages and with
creating SIPs for submission to HathiTrust, or with creating your own scripts to
perform various tasks.

## Validation and Submission Tools

`validate_images.pl` - Validates all images in a given directory. You must
provide the package type, namespace and object ID the images came from. Before
using this script you must create a namespace for your content - see -- see
"Namespace Creation" below. Eventually, you'll need a package type for your
content (see "Package Type Creation"), but to start you can validate your
images using the 'google' package type.

`generate_sip.pl` - generate packages for submission to HathiTrust and copies it
to the directory specified on the command line. See the included perldoc for
more information. You will need a namespace and a package type before running
this code.

`validate_volume.pl` - Validates a volume by running all stages through METS
generation. See the included perldoc for more information. You will need a
namespace and a package type before using this code.

## Sample Code

`compress_tif_jp2.pl` - Converts TIFFs to JPEG2000 images compliant with HathiTrust standards
using the Kakadu library. See "Compressing TIFFs to JPEG2000 images" below.

`feed_env.pl` - Dumps the feed configuration.

`genmets.pl` - An example of using the included perl METS module to generate a source METS file
without using the rest of the HTFeed framework.

`test_stage.pl` - Runs one stage on a submission in process, for
testing/debugging purposes.


# Namespace Creation

A namespace represents a set of identifiers that are guaranteed to be unique
within that namespace. Usually, each institution submitting content has one
namespace for each kind of identifier under its control.

Before running the sample code, you'll need to create a perl package for your
namespace. Namespace are coordinated through HathiTrust. Let's assume you have
been assigned the namespace "foo". Then you would copy HTFeed/Namespace/Yale.pm
to HTFeed/Namespace/FOO.pm as a starting point and change it as follows:

Change:

```perl
	package HTFeed::Namespace::Yale;
```

To:
```perl
    package HTFeed::Namespace::FOO;
```
    
Change:
```perl
	our $identifier = 'yale';
```

To:
```perl
    our $identifier = 'foo';
```

	
The configuration block requires more explanation:

```perl
	our $config = {
	    packagetypes => [qw(ht yale)],
	    handle_prefix => '2027/yale',
	    description => 'Yale University',
	    tags => [qw(bib local report)]
	};
```


The packagetypes variable lists the allowed package types for your content.
'ht' is a base package type representing content that is already in the
repository. Once you create a new package type for your content, you can add it
as an allowed package type here. For now, just set packagetypes as follows:

```perl
        packagetypes => [qw(ht google)],
```

This will allow you to validate your images to the standard used for Google
images.

Update the description to the institution this namespace is for, and update
the handle prefix to reflect your namespace, '2027/foo' in this case.

The 'tags' variable can be left as is; it supports reporting functionality for
HathiTrust.

Finally you can implement a subroutine for barcode validation:

```perl
sub validate_barcode {
    my $self    = shift;
    my $barcode = shift;
    return $self->luhn_is_valid('39002',$barcode);
}
```

If your barcodes use the common 14-digit numeric "Codabar" barcodes, you can
just update '39002' to your library's prefix. Otherwise, you should implement a
subroutine that returns true for valid barcodes / object identifiers and false
otherwise. Or for testing purposes you can just always return true:

```perl
sub validate_barcode {
    return 1;
}
```

You can examine the other included namespaces for samples of other barcode validation.

Namespaces can also be used to override package type defaults for cases when a
package type is used by more than one namespace but with slight variations; see
the sample namespaces for examples.

# Package Type Creation

The first step to prevalidating and packaging content for HathiTrust is the
package type description. Let's go over the process of creating a package type,
using the package type description for local digitization from Universidad
Complutense de Madrid as an example.

First, choose a package type identifier. If the package type is idiosyncratic
to your university, you might choose to use a common abbrevation of your
university as the identifier. For example, the package type identifier for
Universidad Complutense de Madrid is 'ucm'.

The perl module corresponding to the package should be named the upper-cased
version of the package type identifier, for example:

```perl
    package HTFeed::PackageType::UCM;
```

There are a few required `use` statements. To start, the
`HTFeed::PackageType` base class:

```perl
    use HTFeed::PackageType;
    use base qw(HTFeed::PackageType);
```

Required if there are any custom validation overrides:

```perl
    use HTFeed::XPathValidator qw(:closures);
```

Always `use strict;`!

```perl
    use strict;
```

The package type identifier is lexicalized using `our` so it is visible outside the class.

```perl
    our $identifier = 'ucm';
```

The bulk of the configuration goes in `$config`.

```perl
    our $config = {
```

First, pull in the default configuration from the superclass (see default configuration, below):

```perl
        %{$HTFeed::PackageType::config},
```

A short description of what the package type consists of

```perl
        description => 'Madrid-digitized book material',
```

A custom volume module for this package type (see custom volume module below)

```perl
        volume_module => 'HTFeed::PackageType::UCM::Volume',
```

A regular expression that matches only valid files in the SIP. In this example, valid files are xml files starting with `UCM_` and jpeg2000 files whose names are 8 digits. This is used in the validation step before packing the SIP into a zip file.

```perl
        valid_file_pattern => qr/^( UCM_\w+\.(xml) | \d{8}\.(jp2)$)/x,
```


Files in the SIP are split into various filegroups, for example images and OCR.
For Madrid, there is no OCR and all images are expected to be JPEG2000 images.

```perl
        filegroups => {
```

The key for each file group is arbitrary.

```perl
            image => {
```

The prefix to use on file IDs in the METS for files in this filegroup. This is technically arbitrary, but it's best to follow HathiTrust convention: IMG for images, OCR for plain text OCR, XML or HTML for coordinate OCR, and PDF for PDF. Coordinate with HathiTrust before adding another file type to your packages.

```perl
                prefix       => 'IMG',
```


Used to construct the `USE` attribute in the METS `fileSec` element. Should be one of `image`, ocr`, coordOCR`, and `pdf`. Use of an incorrect `USE` attribute may break display in HathiTrust.

```perl
                use          => 'image',
```

Regular expression that picks files in the SIP that will correspond to this file group.

```perl
                file_pattern => qr/^\d{8}.(jp2)$/,
```

Set to 1 if there must be a file for every page. This is typically always 1 for images; it may be 0 or 1 for OCR depending on whether OCR is produced for blank or non-OCRable pages. It is typically 0 for whole-book PDF.

```perl
                required     => 1,
```

Set to 1 if the file should be included in the final package in HathiTrust. Typically always set to 1.

```perl
                content      => 1,
```

Set to 1 if the files in this filegroup should be validated with JHOVE. Typically set to 1 for images.

```perl
                jhove        => 1,
```

Set to 1 if the files in this filegroup should be valid UTF-8. Typically set to 1 for OCR and coordinate OCR.

```perl
                utf8         => 0,
```

Defaults to 1; if 0 the file is not included in the structMap, for example PDF.

```perl
                structmap    => 1,
            },
        },
```


The stage map lists what actions should be taken to create a SIP. The keys are
the starting state; refer to each stage to determine what the ending state is.
Stop states are listed in the configuration file. For example if you only
wanted to prevalidate you could use the following stage map:

```perl
        stage_map => {
            ready             => 'HTFeed::PackageType::UCM::Unpack',
            unpacked          => 'HTFeed::PackageType::UCM::ImageRemediate',
            images_remediated => 'HTFeed::PackageType::UCM::SourceMETS',
            src_metsed        => 'HTFeed::VolumeValidator',
            validated         => 'HTFeed::Stage::Done',
        },
```

If you wanted to pack and collate the SIPs for delivery to HathiTrust you could use:

```perl
        stage_map => {
            ready             => 'HTFeed::PackageType::UCM::Unpack',
            unpacked          => 'HTFeed::PackageType::UCM::ImageRemediate',
            images_remediated => 'HTFeed::PackageType::UCM::SourceMETS',
            src_metsed        => 'HTFeed::VolumeValidator',
            validated         => 'HTFeed::Stage::Pack',
            packed            => 'HTFeed::Stage::Collate',
        },
```


The next section in the package type configuration lists PREMIS events to
include in the source METS file. PREMIS events are configured in the
premis.yaml configuration file (see below)

```perl
        # What PREMIS events to include in the source METS file
        source_premis_events => [
            # capture - included manually
            'image_compression',
            'source_mets_creation',
            'page_md5_create',
            'mets_validation',
        ],
```

A preingest directory can be used as a temporary working directory where
pre-submission files are staged for remediation. By default one is not created;
set use_preingest to 1 to create one in the preingest staging area (defined in
the config file) using the object ID (typically the barcode) as the identifier.

```perl
        use_preingest => 1,
```

The last section lists validation overrides. Validation consists of various tags such as `layers` and `resolution` that specify a condition that must be true. In this case the validator for JPEG2000 overrides the "layers" validator to check that the "layers" parameter in the "codingStyleDefault" context must be 8. It also overrides the validation for resolution -- by default the resolution must be exactly 300, 400, 500 or 600 DPI but this relaxes that check and just ensures the resolution is greater than 300 DPI. The default validators are set in subclasses of HTFeed::ModuleValidator, for example HTFeed::ModuleValidator::JPEG2000_hul. The validation routines are set in `set_validator` in each ModuleValidator sublcass and the contexts they refer to are set up in the corresponding HTFeed::QueryLib package (included in the JPEG2000_hul.pm file).  Refer to the perldoc for XPathValidator.pm and ModuleValidator.pm for more information. Consult HathiTrust before adding validation overrides!

```perl
        validation => {
          'HTFeed::ModuleValidator::JPEG2000_hul' => {
              'layers' => v_eq( 'codingStyleDefault', 'layers', '8' ),
              'resolution'      => v_and(
                  v_ge( 'xmp', 'xRes', 300 ), # should work even though resolution is specified as NNN/1
                  v_same( 'xmp', 'xRes', 'xmp', 'yRes' )
              ),
          }
        }

    };
```


### PackageType Defaults

Next let's consider the defaults inherited from HTFeed::PackageType. These can
be overriden in your package type description!

```perl
    our $config = {
        description => "Base class for HathiTrust package types",
```

Set to 1 to allow gaps in numerical sequence of filenames.

```perl
        allow_sequence_gaps => 0,
```

If 0, allow only one image per page (i.e. .tif or .jp2). If 1, allow (but do not require) both a .tif and .jp2 image for a given sequence number.

```perl
        allow_multiple_pageimage_formats => 0,
```

If there is a separate checksum file (e.g. checksum.md5) that can be set here (see for example the MPubDCU package type)

```perl
        checksum_file => 0,
```

This is only used when ingesting a volume into HathiTrust.

```perl
        default_queue_state => 'ready',
```

The HTFeed::ModuleValidator subclass to use for validating files with the given extensions. This might be overriden in the future if HathiTrust supports validation of additional file types.

```perl
        module_validators => {
            'jp2'  => 'HTFeed::ModuleValidator::JPEG2000_hul',
            'tif'  => 'HTFeed::ModuleValidator::TIFF_hul',
        },
```

No stage maps or validation overrides by default.

```perl
        stage_map => { },
        validation => { },
```


See custom validation, below.

```perl
        validation_run_stages => [
            qw(validate_file_names
              validate_filegroups_nonempty
              validate_consistency
              validate_checksums
              validate_utf8
              validate_metadata)
        ],
```

No PREMIS overrides by default. You can set up package-type specific PREMIS events -- see the Yale package type for an example. The format is essentially the same as in the premis.yaml configuration. Also see the PREMIS section below.

```perl
        premis_overrides => { },
```

List of extensions not to compress in the ZIP file.

```perl
        uncompressed_extensions => [qw(tif jp2)],
```

Use a preingest directory -- will typically set to 1 when any remediation is required.

```perl
        use_preingest = 0,
```

By default, Feed uses XML schema caching when validating XML. This might break for some package types where the same XML namespace is used for metadata that might have different schemas in different volumes; in such a case set use_schema_caching to 0.

```perl
        use_schema_caching => 1,
```

HTFeed::Volume is used as the basic volume module by default.

```perl
        volume_module => 'HTFeed::Volume',

    }
```

# Volume Customization

Feed provides a simple default volume module, `HTFeed::Volume`, as well
as several volume modules customized to particular package types that can be
extended or used as examples. Volume subclasses specific to a particular
package type should be named `HTFeed::PackageType::<em>YourPackageType</em>::Volume`.

See the `HTFeed::Volume` perldoc for an exhaustive list of all methods
that can be overridden or extended in Volume subclasses. Typically you will not
need to override any default Volume methods for remediation and prevalidation; however,
a custom Volume module may be a convenient place to put methods that fetch metadata
about a volume that might be used by multiple stages.

Methods in Volume subclasses should not alter the files in the staging directory in any
way -- that should only be done by Stage modules.

The base `HTFeed::Volume` class also provides a number of convenience
methods for obtaining staging directory locations and basic volume metadata.
Custom module documentation shows usage for some of these methods; again, see
the perldoc for an extensive listing. 

# Custom Stage Creation

Stages are the backbone of the remediation process. To remediate and
prevalidate your content you will need to create several custom stages.

Stages inherit from a subclass of `HTFeed::Stage`. Subclasses 
generally implement or override the `run` method. A bare-bone stage
that does nothing works as follows:

```perl
    sub run{
        my $self = shift;
        my $volume = $self->{volume};
     
        $self->_set_done();
        return $self->succeeded();
    }
```

Stages must call `$self->_set_done()` or the runner framework will assume that
the stage did not finish. By default `succeeded()` returns true unless
`set_error()` has been called at some point. See the
`HTFeed::Stage` perldoc for more detail.


## Fetch/Unpack

The first stage in your pipeline should be a subclass of the Fetch or Unpack
stage. These stages copy (for Fetch) or unzip (for Unpack) the
original source material to a working directory for remediation. Let's review
sample implementations for each.

### Unpack

If your source material is in a .zip or .tar.gz archive then Unpack is the appropriate stage to extend.

Let's take a look at a simple Unpack subclass.

```perl
    sub run{
        my $self = shift;
        # make staging directories
        $self->SUPER::run();
        my $volume = $self->{volume};
    
    
        $self->untgz_file($volume->get_download_location(),
             $volume->get_staging_directory(),"--strip-components 1") or return;
    
        $self->_set_done();
        return $self->succeeded();
    }
```

We first call the superclass run method; this is important to call in any Fetch
or Unpack subclass so that the staging directories (temporary working
directories) are properly created. (This method is defined in
`HTFeed::Stage::DirectoryMaker`, the common parent of both Fetch and
Unpack.)

Next, we determine the file to unpack. By default, `get_download_location` uses
the download staging area (defined in the config file) and the package type
`get_SIP_filename` parameter to construct a path to an archive to
extract.

Finally, we call the superclass `untgz_file` method with the archive to extract,
the area to extract it to, and any extra parameters to the 'tar' command. In
this case we extract to the main staging directory rather than the preingest
directory because no remediation is required, but if the files did need
remediation we could have used `get_preingest_directory`. As written,
`untgz_file` shells out to tar because the perl Archive::Tar implementation is
very slow.

`HTFeed::Stage::Unpack` also has an `unzip_file` method which shells out
to unzip to extract a zip file. You can also of course implement your own
extraction method so long as it ultimately places the package files where they
will be needed for the next stage in the pipeline.

### Fetch

Alternately, if your files are already unpacked, you might just want to copy
them to a staging area for remediation and/or validation. The Fetch stage 
implements this behavior. Let's review a sample Fetch subclass.

```perl
    sub run {
        my $self = shift;

        my $objid = $self->{volume}->get_objid;
        my $fetch_dir = get_config('staging' => 'fetch');
        my $source = "$fetch_dir/$objid";

        my $dest = get_config('staging' => 'preingest');

        $self->fetch_from_source($source,$dest);

        $self->_set_done();
        return $self->succeeded();

    
    }
```


The essential method here is `fetch_from_source`, which by default
shells out to cp to implement a copy-on-write strategy: source files are
symlinked to the destination directory; when the files are opened and rewritten
the symlink is overwritten with a new file.

The layout for the fetch area will depend on local conventions. Again, the
destination should be the preingest staging area if remediation is required.
In this case the base preingest staging area is used because `fetch_from_source`
by default copies the entire directory.

If only subsets of files shoudl be fetched or if the source material has a
complex layout, a custom Fetch subclass can be used to collect files in the
preingest area.

## OCR Remediation

The convention for HathiTrust is to have one plain-text OCR file per page, and
optionally one coordinate OCR XML or HTML file per page. There is currently no
required format for coordinate OCR; bit-level preservation only is done, and by
default they are validated as UTF-8 text, but no checking for well-formedness
or validity is done.

Because input formats for OCR are so varied there is no default or base class
for OCR remediation. Existing modules for OCR extraction include:

  * `HTFeed::PackageType::Kirtas::ExtractOCR`: extracts page-level plain text OCR from page-level ALTO XML OCR.
  * `HTFeed::PackageType::IA::OCRSplit`: Splits volume-level coordinate OCR in DjVuXML format to page-level plain text and XML OCR.
  * `HTFeed::PackageType::DLXS::OCRSplit`: Splits volume-level OCR from DLXS-derived .txt or .xml file to page-level plain text OCR.

These modules can be extended or used as examples to create your own OCR splitting module.

You should read in OCR from the preingest directory
(`$volume->get_preingest_directory()`) and write it out to one file per
page in the main staging directory (`$volume->get_staging_directory()`).
You should also record a PREMIS event for OCR normalization:

```perl
   $volume->record_premis_event("ocr_normalize");
```

The `ocr_normalize` PREMIS event should have a description added in the PREMIS
override section of your package type configuration, for example:

```perl
    premis_overrides => {
        'ocr_normalize' =>
          { detail => 'Splitting of IA XML OCR into one plain text OCR file and one XML file (with coordinates) per page', }
    },
```

You will also need to add a `stage_info` method if your stage inherits directly from HTFeed::Stage:

```perl
    sub stage_info{
        return {success_state => 'ocr_extracted', failure_state => ''};
    }
```

The `success_state` is used as the key for the next stage in the `stage_map` in
your package type configuration.  Typically failure to extract OCR is a fatal
error, so the default failure state is used.


## Image Remediate

Feed can automatically remediate a variety of problems with both TIFFs and
JPEG2000 images. Since TIFFs normally use lossless compression, the range of
problems that can be fixed is somewhat wider than with JPEG2000 images.

A partial list of issues that can be fixed for TIFFs:

  * Errors as reported by JHOVE:
    * IFD offset not word-aligned
    * Value offset not word-aligned
    * Tag 269 out of sequence
    * Invalid DateTime separator
    * PhotometricInterpretation not defined

  * Incorrectly formatted ModifyDate
  * Incorrect (non-Group 4) compression
  * Incorrect PhotometricInterpretation (not WhiteIsZero)
  * Missing Orientation (assumed to be Horizontal (normal))

  * Missing BitsPerSample/SamplesPerPixel (in some cases)
  * Missing DocumentName
    

In addition you can provide the correct values for required fields
such as Artist and ModifyDate and image remediation can add them.

For JPEG2000 images, the following issues can be fixed:

  * Automatically fixes missing or inconsistent XMP headers:
    * tiff:ImageWidth, tiff:ImageHeight
    * tiff:Compression
    * tiff:Make (if IFD0:Make is present)
    * tiff:Model (if IFD0:Model is present)
    * tiff:BitsPerSample
    * tiff:SamplesPerPixel
    * tiff:PhotometricInterpretation
    * tiff:Orientation (assumed to be Horizontal (normal))
    * tiff:XResolution, tiff:YResolution, tiff:ResolutionUnit, if JPEG2000 resolution headers are present.
    * dc:source

  * Other missing metadata in XMP, if provided:
    * tiff:Artist
    * tiff:DateTime

  Because JPEG2000 compression is normally lossy, there are many other kinds of problems that
  cannot be remediated with JPEG2000. The only option is to go back to the source image and
  recompress.

### Running Image Remediation

You will need to create a stage customized to your particular package as a wrapper
for the main Image Remediation stage. The wrapper can provide various missing metadata
and determine exactly how images will be remediated.

Let's review a sample ImageRemediate subclass for remediating images created by
Kirtas' BookScan software.

```perl
    package HTFeed::PackageType::Kirtas::ImageRemediate;
```

Like all custom stages, it is in the namespace for the specific PackageType it pertains to.
    
```perl
    use warnings;
    use strict;
    use base qw(HTFeed::Stage::ImageRemediate);
    
    use Log::Log4perl qw(get_logger);
    use File::Basename qw(dirname);
```

Declare this is a subclass of HTFeed::Stage::ImageRemediate and bring in logging and utility functions.
    
```perl
    sub run{
        my $self = shift;
        my $volume = $self->{volume};

        my $mets_xc = $volume->get_kirtas_mets_xpc();
```

Implemented in HTFeed::PackageType::Kirtas::Volume -- gets an
XML::LibXML::XPathContext object to a METS file that is created by the Kirtas
software.

```perl
        my $stage_path = $volume->get_staging_directory();
        my $objid = $volume->get_objid();
    
        print STDERR "Prevalidating and remediating images..";
    
        my $capture_time = $volume->get_capture_time();
```

Again, implemented in the Volume subclass; the function looks in the metadata
generated by the Kirtas software to determine when the volume as originally
scanned.
    
```perl
        my @tiffs = ();
        my $tiffpath = undef;
        foreach my $image_node (
            $mets_xc->findnodes(
                '//mets:fileGrp[@ID="BSEGRP"]/mets:file/mets:FLocat/@xlink:href')
```

Looks in the Kirtas METS file to find all images to remediate.

```perl
        )
        {
    
            my $img_dospath = $image_node->nodeValue();
            $img_dospath =~ s/JPG$/JP2/;
            my $img_submitted_path = $volume->dospath_to_path($img_dospath);
```

Some Kirtas METS files we received refer to JPG files that were converted to
JP2 after the fact.  Addtionally, the path is specified in the Kirtas METS file
as as a relative DOS path; the Volume subclass implements a function to find
the corresponding path on our filesystem.
    
```perl
            $img_dospath =~ /($objid)_(\d+)\.(JP2|TIF)/i;
            my $img_remediated = lc("$1_$2.$3");
            my $imgtype = lc($3);
            my $img_remediated_path = lc("$stage_path/$img_remediated");
```

Transforms the path to the source image to a path where the remediated image
will be deposited. This should normally be in $volume->get_staging_directory(),
the directory where the output object will be assembled.
    
```perl
            if($imgtype eq 'jp2') {
                $self->remediate_image( $img_submitted_path, $img_remediated_path,
                    {'XMP-dc:source' => "$objid/$img_remediated",
                        'XMP-tiff:Artist' => 'Kirtas Technologies, Inc.',
                        'XMP-tiff:DateTime' => $capture_time}, {} );
```

For JPEG2000 images, we'll force dc:source to BARCODE/FILENAME (the format required
for dc:source in all JPEG2000 images) as well as forcing tiff:Artist and tiff:DateTime
to particular values. The "XMP-tiff:Artist" notation reflects the way Image::ExifTool
names image headers. See the perldoc for HTFeed::Stage::ImageRemediate for more information
on how to pass extra metadata to the remediate_image call.


```perl
            } else {


                if(defined $tiffpath and dirname($img_submitted_path) ne $tiffpath) {
                    $self->set_error("UnexpectedError",detail => "two image paths $tiffpath and $img_submitted_path!");
                }
                $tiffpath = dirname($img_submitted_path);
                push(@tiffs,$img_remediated);
```

Otherwise (for TIFF images) we'll collect a list of TIFF images to remediate
and then handle them all at once; this is so we can run JHOVE in a batch on all
the TIFF images at once. We also check that all the submitted TIFF images are in
the same source path.

```perl
            }
    
        }
    
        # remediate tiffs
        $self->remediate_tiffs($volume,$tiffpath,\@tiffs,
            sub { my $file = shift; return
            {   'IFD0:DocumentName' => "$objid/$file",
                'IFD0:Artist' => 'Kirtas Technologies, Inc.',
                'IFD0:ModifyDate' => $capture_time}, {}} );
```

Again see the perldoc for HTFeed::Stage::ImageRemediate for more info; the gist is that
we run JHOVE on all the TIFF files at once and then call the supplied callback to obtain
the metadata to set for each file.
    
```perl
        $volume->record_premis_event('image_header_modification');
    
        $self->_set_done();
        return $self->succeeded();

    }
```

Finally if everything went well we record the PREMIS event and indicate that the stage is
completed.


### Compressing TIFFs to JPEG2000 images

HathiTrust has adopted JPEG2000 as the preferred format for continuous tone
images, following the recommendations of (CITE ABRAMS PAPER). For an example of
compressing TIFFs to JPEG2000 images and adding all required metadata (assuming
the metadata is present in the TIFFs), see `compress_tif_jp2.pl.`

This code uses Kakadu (not free software) to compress the JPEG2000 images.
While it should be possible to modify this code to use another JPEG2000
compression library such as JasPer, it may not be straightforward to adapt all
of the options such as the slope rate distortion parameter. That means that
while it should be possible to produce JPEG2000 images that can pass HathiTrust
validation, they still may not have been created in an optimal fashion.

# Source METS creation

The source METS is the repository for all metadata in the SIP. The METS library
and the HTFeed::SourceMETS module provide some basic tools for creating source
METS. HTFeed::SourceMETS can be extended to include additional metadata in the
source METS that you generate.

A basic outline of the METS creation process is as follows:

  * Add required XML namespaces and schemas (_add_schemas)
  * Add METS header (_add_header)
  * Add descriptive metadata (_add_dmdsecs)
  * Add technical metadata (_add_techmds)
  * Add manifest of files in SIP (_add_filesecs)
  * Add basic structural metadata (_add_struct_map)
  * Add PREMIS metadata (_add_premis)
  * Add any additional administrative metadata (_add_amdsecs)
  * Save METS to filesystem
  * Validate METS using Xerces

## Schemas and Header

By default the METS and PREMIS2 namespaces schemas are included. You can extend
_add_schemas to add any additional schemas for metadata that you plan to embed
in the source METS.

Override `mets_header_agent_name` in your local configuration to set the agent
name that appears in the METS header.

## What Metadata To Include

The source METS is the home for all metadata included with the SIP: there
should not be any separately-included files with metadata.

Appropriate metadata to include is any metadata with preservation value. This
is a subjective determination that is up to the submitting institution.

However, the following guidelines should be applied:

  * Do not include redundant or duplicative metadata. 
  * Do not include metadata that can be programatically generated from image files, e.g. MIX metadata.
  * Do not include rights metadata. This information is separately determined

Appropriate metadata could include:

  * MARC or Dublin Core descriptive metadata. This metadata is for disaster recovery and archaeological purposes only: the primary descriptive metadata for the object is submitted separately and included in the HathiTrust catalog.

  * Technical metadata about the scanning process that is not embedded in the included images.  
 
  * Metadata about the quality of the scan, either automatically or manually determined

  * Metadata about the reading and scanning order of the material (TODO: add reference to example)

## Adding Descriptive Metadata

To include descriptive metadata (e.g. MARC), extend the _add_dmdsecs element. A
predefined helper method, `_add_marc_from_file`, can be used to add the MARC from
a valid MARCXML file. It will also validate and remediate the MARCXML for
several common errors such as invalid leaders and invalid characters.

For an example of a typical implementation of the _add_dmdsecs method, see  the
PackageType::IA::SourceMETS.pm package:

First we get some file locations:

```perl
    sub _add_dmdsecs {
        my $self = shift;
        my $volume = $self->{volume};
        my $objid = $volume->get_objid();
        my $download_directory = $volume->get_download_directory();
        my $ia_id = $volume->get_ia_id();
        my $marc_path = "$download_directory/${ia_id}_marc.xml";
        my $metaxml_path = "$download_directory/${ia_id}_meta.xml";
```

Then we call the existing `_add_marc_from_file` helper method:

```perl
        $self->_add_marc_from_file($marc_path);
```

Then we include an extra descriptive metadata file from the Internet Archive,
but first we check that the embedded identifier in the file matches the
expected one.

```perl
        # Verify arkid in meta.xml matches given arkid
        my $parser = new XML::LibXML;
        my $metaxml = $parser->parse_file("$download_directory/${ia_id}_meta.xml");
        my $meta_arkid = $metaxml->findvalue("//identifier-ark");
        if($meta_arkid ne $volume->get_objid()) {
            $self->set_error("NotEqualValues",field=>"identifier-ark",expected=>$objid,actual=>$meta_arkid);
        }
```


The METS::MetadataSection wraps the XML file. See the perldoc for more information.

```perl
        my $dmdsec = new METS::MetadataSection( 'dmdSec', 'id' => $self->_get_subsec_id("DMD"));
        $dmdsec->set_xml_file(
            $metaxml_path,
            mdtype => 'OTHER',
            label  => 'IA metadata'
        );
```

Finally we add the new metadata section to the METS object.

```perl
        $self->{mets}->add_dmd_sec($dmdsec);
    }
```


## Adding Page Numbering and Tagging

If you have page tags for the content you are submitting there is a standard way to
include those in the source METS.

In your custom source METS class, set $self->{pagedata} to a subroutine that
will return the page data given a filename. The format is a hash with the
following values:

```perl
    return  { orderlabel => $pagenum, label => $tags }
```

where $pagenum is the printed page number and $tags is a comma-separated list
of page tags. For example, if page tags are currently in a tab-separated file,
we might have a pagedata function that looks like:

```perl
sub get_srcmets_page_data {
    my $self = shift;
    my $file = shift;
```


The keys in the page data file are sequence numbers, so that has to be 
extracted from the given file name.

```perl
    (my $seqnum) = ($file =~ /(\d+)\./);
    croak("Can't extract sequence number from file $file") unless $seqnum;
```

Cache the page data so we don't have to re-read the file each time.

```perl
    if(not defined $self->{'page_data'}) {
        my $pagedata = {};
```

The file is named pageview.dat and is in the preingest directory.

```perl
        my $pageview = $self->get_preingest_directory() . "/pageview.dat";
        if(-e $pageview) {
            open(my $pageview_fh,"<$pageview") or croak("Can't open pageview.dat: $!");
            <$pageview_fh>; # skip first line - column headers
            while(my $line = <$pageview_fh>) {
                # clear line endings
                $line =~ s/[\r\n]//;
```

Extract the page number and tags from the file

```perl
                my(undef,$order,$detected_pagenum,undef,$tags) = split(/\t/,$line);
                $detected_pagenum =~ s/^0+//; # remove leading zeroes from pagenum
                if (defined $tags) {
                    $tags = join(', ',split(/\s/,$tags));
                }
```

Save the page number and tags

```perl
                $pagedata->{$order} = {
                    orderlabel => $detected_pagenum,
                    label => $tags
                }
            }
            $self->{page_data} = $pagedata;
        }
    }
```

Finally, return the requested page data.

```perl
    return $self->{page_data}{$seqnum};
}
```



## Including Structural Metadata

By default the HTFeed::SourceMETS module will construct a simple flat structmap
using the page numbering and tagging (if any) as described above. For each
page, a file from each file group will be included (if one is present.) By
default files are collated and ordered based on a numeric string in the
filename. So for example you could have files named like:

    00000001.tif
    00000001.txt
    00000002.jp2
    00000002.txt

etc. To support other naming schemes it may be easier to add a custom structmap
rather than extend the default structmap.

To create a custom structmap, use the METS::StructMap module. Let's see how the
default structmap is created using METS::StructMap:


```perl
    sub _add_struct_map {
        my $self   = shift;
        my $mets   = $self->{mets};
        my $volume = $self->{volume};
```

This is the custom function used to get page data.

```perl
        my $get_pagedata = $self->{pagedata};
```

First create a new METS::StructMap object.

```perl
        my $struct_map = new METS::StructMap( id => 'SM1', type => 'physical' );
```

Then add a top-level div.

```perl
        my $voldiv = new METS::StructMap::Div( type => 'volume' );
        $struct_map->add_div($voldiv);
        my $order               = 1;
```

The `get_structmap_file_groups_by_page` function returns a data structure that maps 
directly to how the default structmap is generated.

```perl
        my $file_groups_by_page = $volume->get_structmap_file_groups_by_page();
```

In the returned has the keys are sequence numbers

```perl
        foreach my $seqnum ( sort( keys(%$file_groups_by_page) ) ) {
```

The values are a hash from the filegroup name to filenames, for example
1 => { image => '00000001.tif', ocr => '00000001.txt' }, 2 => { image => '00000002.jp2', ocr => '00000002.txt' },

```perl
            my $pagefiles   = $file_groups_by_page->{$seqnum};
            my $pagediv_ids = [];
            my $pagedata;
            my @pagedata;
            while ( my ( $filegroup_name, $files ) = each(%$pagefiles) ) {
```


```perl
                foreach my $file (@$files) {
```

We look in the filegroup corresponding to each file to get the file ID for reference.
For example the ID for 00000001.tif might be IMG00000001.

```perl
                    my $fileid =
                      $self->{filegroups}{$filegroup_name}->get_file_id($file);
                    if ( not defined $fileid ) {
                        $self->set_error(
                            "MissingField",
                            field     => "fileid",
                            file      => $file,

                            filegroup => $filegroup_name,
                            detail    => "Can't find ID for file in file group"
                        );
                        next;
                    }
```

If a custom page data function is installed, we next try to get the page data
for this file. We also make sure it matches the page data for any other files
for this page.

```perl
                    if(defined $get_pagedata) {
                        # try to find page number & page tags for this page
                        if ( not defined $pagedata ) {
                            $pagedata = &$get_pagedata($file);
                            @pagedata = %$pagedata if defined $pagedata;
                        }
                        else {
                            my $other_pagedata = &$get_pagedata($file);
                            while ( my ( $key, $val ) = each(%$pagedata) ) {
                                my $val1 = $other_pagedata->{$key};
                                $self->set_error(
                                    "NotEqualValues",
                                    actual => "other=$val ,$fileid=$val1",
                                    detail =>
        "Mismatched page data for different files in pagefiles"
                                  )
                                  unless ( not defined $val and not defined $val1 )
                                  or ( $val eq $val1 );
                            }

                        }
                    }

                    push( @$pagediv_ids, $fileid );
                }
            }
```

We then add a div for each page. The @pagedata variable can include the the
orderlabel and label attributes.

```perl
            $voldiv->add_file_div(
                $pagediv_ids,
                order => $order++,
                type  => 'page',
                @pagedata
            );
        }
```

Finally we add the finished struct map.

```perl
        $mets->add_struct_map($struct_map);

    }
```


Custom structMaps can include additional logical structure or use other ways of
determining what files belong to a page. A structMap with additional structure
could be added as a structmap with type=logical. However, a flat physical
structMap should also be included for use in generating the HathiTrust METS.


## Required PREMIS events

The basic PREMIS events that are required for all packages are:

- `capture`
- `page_md5_create`
- `source_mets_creation`
- `mets_validation`

Additionally, if image header modificaiton or ocr normalization are performed
those events should be included as well.

Events are defined in the premis.yml configuration file. See there for more
information on each event.

Events that occur during the course of running feed are automatically recorded
and included in the METS files. However, the capture event must be manually
created since feed has no way of knowing when the images were originally
scanned or photographed.

Therefore, the SourceMETS subclass for your package must include a function
like `_add_capture_event`. The following example shows how to format a capture date
and generate a PREMIs event using the PREMIS module:

```perl
sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};
    my $premis = $self->{premis};
        
```

Use ExifTool to extract a header from one of the volume images.

```perl
    my $exifTool = new Image::ExifTool;
    $exifTool->ExtractInfo($volume->get_staging_directory() . "/00000001.tif");
    my $capture_date = $exifTool->GetValue('ModifyDate','IFD0');
```

Format the date appropriately for PREMIS
        
```perl
    $capture_date =~ s/(\d{4}).(\d{2}).(\d{2}).(\d{2}).(\d{2}).(\d{2})(.*)/$1-$2-$3T$4:$5:$6$7/; 
    
```

Create a PREMIS event using the default description, etc for the
capture event:

```perl
    my $eventconfig = $volume->get_nspkg()->get_event_configuration('capture');
    $eventconfig->{'eventid'} = $volume->make_premis_uuid($eventconfig->{'type'},$capture_date);
    $eventconfig->{'executor'} = 'MiU';
    $eventconfig->{'executor_type'} = 'MARC21 Code';
    $eventconfig->{'date'} = $capture_date;
```

Lastly, save the event for this volume.

```perl
    my $event = $self->add_premis_event($eventconfig);
} 
```



## Custom PREMIS events

To add a custom PREMIS event, add the same configuration as in premis.yml but
in the package type configuration file. The tool names are references to tools
configured in premis.yml as well. Type is the PREMIS eventType and detail is
the PREMIS eventDetail. The executor (whoever is responsible for this event)
will have a MARC21 organization code in most cases.  If not check with
HathiTrust before using a different executor type.

```perl
    premis_overrides => {
        'boilerplate_remove' =>
          { type => 'image modification',
            detail => 'Replace boilerplate images with blank images' ,
            executor => 'MiU',
            executor_type => 'MARC21 Code',
            tools => ['GROOVE']
          },
    },
```

Custom PREMIS events are often associated with custom stages (see below.) To
record a custom PREMIS event, just call:

```perl
    $volume->record_premis_event('boilerplate_remove);
```

The default date is the current date. That can be overridden by passing a date
parameter.  If there is a outcome that should be associated with this PREMIS
event, you can pass that as well a second parameter -- see PREMIS::Outcome for
more information. For example:

```perl
    $volume->record_premis_event('boilerplate_remove', 
                         date => $my_date, 
                         outcome => new PREMIS::Outcome('success'));
```

# Validation

The main validation stage is HTFeed::VolumeValidator. There are several
separate methods in VolumeValidator that validate differents parts of the
package.

## Validation stages

`validate_file_names`: Ensures every file in the AIP staging directory is valid
for the volume based on the allowed filenames in the package type configuration.

`validate_filegroups_nonempty`: Ensure that every listed filegroup (image, ocr,
etc.) contains at least one file.

`validate_consistency`: Make sure every listed file in each file group tagged as
'required' in the package type configuration (ocr, image, etc) has exactly one
corresponding file in each other file group and that there are no skips in the
numeric sequence of filenames (unless `allow_sequence_skips` is set in the
package type configuration).

`validate_checksums`: Validate each file against a precomputed list of checksums.
This just ensures that the checksums in the generated source METS match the
checksums of the files on disk.

`validate_utf8`: Opens and tries to decode each file that should be UTF-8 as
configured in the package type configuration and ensures that it is valid UTF8
and does not contain any control characters other than tab and CR.

`validate_metadata`: This is the meat of validation. It runs JHOVE on each file
in each filegroup where the 'jhove' flag is set in the package type
configuration, and processes its output through the appropriate
HTFeed::ModuleValidator subclass.

# Logging and Errors

Errors can be printed to the screen, logged to a database (see below), saved to
a file, or some combination thereof. You can also specify the verbosity of
logging on the command line with the -level flag. See HTFeed::Log for more
information.

Error fields -- Each error that is logged has several fields.

level: The level of the warning, e.g. INFO, DEBUG, ERROR, etc.

timestamp: The time the error was logged

namespace, id: The volume being processed when the error was encountered.

operation: The operation that failed (if applicable) for example download,
copy, etc.

message: A generic description of the error.

file: The content file where the error occurred.

field: The metadata field where the error occurred. The name here can refer to
an ExifTool tag or to a JHOVE field. For JHOVE fields, the names used refer to
XPath expressions defined in the `HTFeed::ModuleValidator::TIFF_hul` and
`HTFeed::ModuleValidator::JPEG2000_hul` packages. For example if the field is
`repInfo_status` this refers to a query performed for `jhove:status` in the
context defined as `/jhove:jhove/jhove:repInfo`" 

actual: The actual value of the field in the file 

expected: The expected value of the field

detail: Any additional human-readable information about the error


Some sample errors: 

```
        level: ERROR
    timestamp: 2012-04-21 20:35:03
    namespace: uc1
           id: $b616568
      message: Missing field value
         file: UCAL_$B616568_00000002.jp2
        field: xmp_dateTime
```

The XMP DateTime header is missing. It might need to be manually added or a custom image remediation stage could be used to automatically add it.

```
        level: ERROR
    timestamp: 2011-12-15 18:55:59
    namespace: umn
           id: 31951d00623234x
      message: Invalid value for field
         file: 00000001.tif
        field: mix_xRes
       actual: 400
     expected: eq 600
```

The resolution of the image appears to be 400 DPI, but all TIFF images are
expected to be 600 DPI. A new image would have to be manually generated either
by upscaling and binarizing a contone master or by rescanning. 

```
        level: ERROR
    timestamp: 2012-04-09 22:43:45
    namespace: mdp
           id: 39015031653523
      message: Invalid value for field
         file: 00000001.tif
        field: repInfo_status
       actual: Well-Formed, but not valid
     expected: eq Well-Formed and valid
```

JHOVE is reporting that 00000001.tif is "Well-Formed but not valid". The next step
would be to run JHOVE manually on the file to determine what was wrong with it. 
Normally the JHOVE error field will give some more information.

```
      level: ERROR
    timestamp: 2012-05-03 11:14:09
    namespace: mdp
         id: 39015068552556
    message: Invalid value for field
       file: 00000413.tif
      field: documentname
     actual: 39015068552556/00000414.tif
    expected: 39015068552556/00000413.tif
```

The documentname field refers to a header that can be obtained from various
places. In TIFFs it refers to the field called DocmentName [sic] by JHOVE or
IFD0:DocumentName by ExifTool. This field should be populated with the value
BARCODE/FILENAME but in this case the file is named 00000413.tif but the
DocumentName field contains 39015068552556/00000414.tif. Most likely the files
were renamed after the DocumentName header was populated.

```
       level: ERROR
    timestamp: 2012-05-03 13:14:22
    namespace: mdp
           id: 39015068426967
      message: Mismatched/invalid value for field
         file: 00000001.jp2
        field: colorspace
       actual: $VAR1 = {
              'xmp_samplesPerPixel' => '1',
              'jp2Meta_colorSpace' => 'Greyscale',
              'mix_bitsPerSample' => '8',
              'mix_samplesPerPixel' => '1',
              'xmp_colorSpace' => '0'
            };
```

This error might be difficult to interpret without some understanding of the
JPEG2000 headers. Specifically, the xmp_colorSpace query is defined as a query
for //tiff:PhotometricInterpretation in the XMP, and that tag is set to 0
(WhiteIsZero). However, for greyscale JPEG2000 images we expect the tag to be 1
(BlackIsZero).

```
        level: ERROR
    timestamp: 2011-12-15 15:33:59
    namespace: mdp
           id: 39015037903963
      message: UTF-8 validation error
         file: 00000061.html
        field: utf8
       detail: Invalid control characters in file 00000061.html at /htapps/babel/feed/bin/../lib/HTFeed/Run.pm line 42
```

An hOCR file (00000061.html) contains invalid UTF-8 characters. It would need
to be manually fixed, or if it were a systematic problem a custom stage could
be used to strip invalid characters.

```
        level: ERROR
    timestamp: 2011-10-25 17:07:22
    namespace: uc2
           id: ark:/13960/t9668c22n
      message: Unexpected error
       detail: $VAR1 = bless( {
                     'num1' => 0,
                     'file' => '/htprep/download/ia/cricketc00steerich/cricketc00steerich_marc.xml',
                     'message' => 'Start tag expected, \'<\' not found
    ',
                     'domain' => 1,
```

A MARC file (used in creating a source METS) was not well-formed and so could
not be used. The detail is a dump of the error from Xerces.

```
        level: ERROR
    timestamp: 2011-10-25 18:24:55
    namespace: uc2
           id: ark:/13960/t9f47k95t
      message: Unexpected error
       detail: Can't mkdir /ram/feed/preingest/ark+=13960=t9f47k95t: No such file or directory at /htapps/babel/feed/bin/../lib/HTFeed/Run.pm line 42
```

For some reason the staging directory couldn't be created. It looks like the
base directory (/ram) might not exist or might have been deleted out from
underneath the script. The next step would be to ensure the staging location
exists, is writable and is correctly configured.


# Packaging

The HTFeed::Pack stage packages up the SIP. It includes the source METS and all
files listed in filegroups with the 'content' flag set. It generates a ZIP file
in a staging directory specified in the staging -> zip configuration.

# Custom Stages

Some content may need more extensive preparation than is provided by the
provided stages. In such a case a custom stage can be created. 

Suppose that when a scan was originally created a page with some boilerplate
acknowledging the donor was included. However, when the volume is submitted to
HathiTrust this template needs to be removed because the donor will be
acknowledged in the interface itself. Luckily, there is a directory that lists
the images that need to be removed. Because just removing the page might mess
up the pagination, we need to replace the page with a generated blank image.

A custom stage can be used to perform this task.

First we set it up in the stage map in the package type configuration:

```perl
    stage_map => {
        ready             => 'HTFeed::PackageType::MyInstitution::Fetch',
        fetched           => 'HTFeed::PackageType::MyInstitution::ExtractOCR',
        ocr_extracted     => 'HTFeed::PackageType::MyInstitution::BoilerplateRemove',
        boilerplate_removed => 'HTFeed::PackageType::MyInstitution::ImageRemediate',
        images_remediated => 'HTFeed::PackageType::MyInstitution::SourceMETS',
        src_metsed        => 'HTFeed::VolumeValidator',
        validated         => 'HTFeed::Stage::Pack',
    },
```

And add a custom PREMIS event for this stage as well:

```perl
    premis_overrides => {
        'boilerplate_remove' =>
          { type => 'image modification',
            detail => 'Replace boilerplate images with blank images' ,
            executor => 'MyInstitution',
            executor_type => 'MARC21 Code',
          },
    },
```



Now for the custom stage itself:


The custom stage should be placed under the package type it applies to:

```perl
    package HTFeed::PackageType::MyInstitution::BoilerplateRemove;

    use warnings;
    use strict;
```

It inherits from the base HTFeed::Stage class.

```perl
    use base qw(HTFeed::Stage);
    use Image::ExifTool;
    use File::Basename;
    use HTFeed::Config qw(get_config);


    use Log::Log4perl qw(get_logger);

    sub run{
        my $self = shift;
        my $volume = $self->{volume};
```

The preingest directory is where the original source files are staged for remediation.

```perl
        my $preingest_dir = $volume->get_preingest_directory();
        my $objid = $volume->get_objid();

        my @removed = ();
```
        
All the files listed in the images/2restore/bookplate directory correspond to images
where the boilerplate has been added.

```perl
        foreach my $bookplate (map { basename($_)} ( glob("$preingest_dir/images/2restore/bookplate/*jp2"))) {
            my $toblank = "$preingest_dir/images/$bookplate";
```

If we expected a file based on its presence in images/2restore/bookplate that appears to be missing in the main image area, throw an error

```perl
            if(!-e $toblank) {
                $self->set_error("MissingFile",file=>$toblank,detail=>"Found in 2restore/bookplate but missing in images");
                next;
            }

            get_logger()->debug("Blanking image $bookplate");
```

Try to generate a blank image of the same size as the image with the boilerplate.

```perl
            my $imconvert = get_config('imagemagick');
            if( system("$imconvert '$toblank' -threshold -1 +matte '$toblank'") )  {
                $self->set_error("OperationFailed",file=>$toblank,operation=>"blanking",detail=>"ImageMagick returned $?");
                next;
            } 
```

Add back in some header information that is required but stripped by
ImageMagick. (In this case the resolution for all images was expected to be 300
DPI anyway.)

```perl
            # force resolution info, since imagemagick strips it :(
            my $exiftool = new Image::ExifTool;
            $exiftool->SetNewValue("XMP-tiff:XResolution",300);
            $exiftool->SetNewValue("XMP-tiff:YResolution",300);
            $exiftool->SetNewValue("XMP-tiff:ResolutionUnit","inches");
            if(!$exiftool->WriteInfo($toblank)) {
                $self->set_error("OperationFailed",file=>$toblank,operation=>"fix resolution info",
                    detail=>"ExifTool returned ". $exiftool->GetValue('Error'));
                next;
            } 
```

Add the image to a list of pages that have been blanked.

```perl
            push(@removed,$bookplate);

        }
```


Finally, add a PREMIS event with a custom outcome that lists the files that
had boilerplate removed.

```perl
        if(!$self->{failed}) {
            my $outcome = new PREMIS::Outcome('success');
            $outcome->add_file_list_detail( "boiler plate images replaced",
                            "replaced", \@removed);
            $volume->record_premis_event('boilerplate_remove',outcome => $outcome);
            
        }

        $self->_set_done();
        return $self->succeeded();

    }
```

The `stage_info` is used in the `stage_list` in the package type configuration to
find the next state. An empty `failure_state` means the failure of this stage is
fatal.

```perl
    sub stage_info{
        return {success_state => 'boilerplate_removed', failure_state => ''};
    }

    1;

    __END__
```

