These are various hand-generated test fixtures demonstrating different
scenarios for validating and normalizing images.

For various scenarios involving invalid metadata, it may be difficult to get
ExifTool or other tools to be willing to add the invalid metadata. 

An example of adding metadata in its raw format with ExifTool using perl:

```perl
use Image::ExifTool;

my $e = Image::ExifTool->new();
$e->SetNewValue("IFD0:ModifyDate" => "", Type => 'Raw');
$e->WriteInfo("00000001.tif");
```

The same method could be used to write invalid or nonsensical resolution
information or units, etc; the key is the `Type => 'Raw'` to avoid ExifTool's
built-in normalization and validation.
