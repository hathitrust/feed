package HTFeed::Namespace;

use warnings;
use strict;
use Algorithm::LUHN;
use Carp;
use HTFeed::PackageType;
use HTFeed::Config qw(get_config);

BEGIN{

    our $identifier = "namespace";
    our $config = {
        description => "Base class for HathiTrust namespaces",
        packagetypes => ['singleimage'],
        # timezone to use when not specified in dates. none by default
        default_timezone => ''
    };

}

use HTFeed::FactoryLoader 'load_subclasses';
use base qw(HTFeed::FactoryLoader);


sub new {
    my $class = shift;
    my $namespace_id = shift;
    my $packagetype = (shift or 'pkgtype');
    my $self = $class->SUPER::new($namespace_id);
    if(defined $packagetype) {
        my $allowed_packagetypes = ($self->get('packagetypes') or []);
        # always allow default packagetype
        if(not grep { $_ eq $packagetype } @{ $allowed_packagetypes } and $packagetype ne 'pkgtype') {
            croak("Invalid packagetype $packagetype for namespace $namespace_id");
        }
        # Can accept either a already-constructed HTFeed::PackageType or the package type identifier.
        if(!ref($packagetype)) {
            $packagetype = new HTFeed::PackageType($packagetype);
        }
        $self->{'packagetype'} = $packagetype;
    }
   
    else {
        croak("Missing packagetype for namespace $namespace_id"); 
    }

    return $self;
}

sub get {
    my $self = shift;
    my $config_var = shift;

    my $class = ref($self);

    no strict 'refs';

    my $packagetype_id; 
    my $ns_pkgtype_override; 
    my $ns_config = ${"${class}::config"};

    if(defined $self->{'packagetype'}) {
        $packagetype_id = $self->{'packagetype'}->get_identifier();
        $ns_pkgtype_override = ${"${class}::packagetype_overrides"}->{$packagetype_id};
    }

    if (defined $ns_pkgtype_override and defined $ns_pkgtype_override->{$config_var}) {
        return $ns_pkgtype_override->{$config_var};
    } elsif (defined $ns_config->{$config_var}) {
        return $ns_config->{$config_var};
    } elsif (defined $self->{'packagetype'}) {
        my $pkgtype_var = eval { $self->{'packagetype'}->get($config_var);
        };
        if($@) {
            croak("Can't find namespace/packagetype configuration variable $config_var");
        } else {
            return $pkgtype_var;
        }
    }

}

sub get_validation_overrides {
    my $self = shift;
    my $module = shift;

    return $self->_get_overrides('validation',$module);

}

# PREMIS events

sub get_event_configuration {


    my $self = shift;
    my $eventtype = shift;

    no strict 'refs';

    my $eventinfo = {};
    # no problem if it's not in main config.. but it had better be in overrides
    eval {
        $eventinfo = get_config('premis_events',$eventtype);
    };
    $self->_get_overrides('premis_overrides',$eventtype,$eventinfo);

    if( not defined $eventinfo->{type}
            or not defined $eventinfo->{executor}
            or not defined $eventinfo->{detail}) {
        use Data::Dumper;
        print Dumper($eventinfo);
        croak("Missing or incomplete configuration for premis event $eventtype") 
    }

    return $eventinfo;
}

# returns namespace identifier
sub get_namespace{
    my $self = shift;
    return $self->get_identifier();
}

# returns packagetype identifier
sub get_packagetype{
    my $self = shift;
    return $self->{packagetype}->get_identifier();
}

# Gathers overrides for things like validation, PREMIS events 
# from package type, namespace, pkgtype overrides.

sub _get_overrides {
    no strict 'refs'; 

    sub _copyhash {
        my $dest = shift;
        my $src = shift;
        my $subkey = shift;

        $src = $src->{$subkey} if(defined $src and defined $subkey);

        # falls through whether original source was undef or subkey is set and
        # subkey value is undef
        return if not defined $src;
        croak("Given empty destination hash") if not defined $dest;

        while(my ($key,$val) = each(%$src)) {
            $dest->{$key} = $val;
        }
    }

    my $self = shift;
    my $key = shift; # top-level key
    my $subkey = shift; # subkey of top-level key
    my $value = shift; # original values for field, optional
    my $class = ref($self);

    $value = {} if not defined $value;

    my $packagetype_id = $self->{'packagetype'}->get_identifier();

    my $ns_config = ${"${class}::config"};
    my $ns_override = $ns_config->{$key};
    _copyhash($value,$ns_override,$subkey);

    my $pkgtype_override = $self->{'packagetype'}->get($key);
    _copyhash($value,$pkgtype_override,$subkey);

    my $ns_pkgtype_override = ${"${class}::packagetype_overrides"}->{$packagetype_id};
    if(defined $ns_pkgtype_override) {
        my $ns_pkgtype_override = $ns_pkgtype_override->{$key};
        _copyhash($value,$ns_pkgtype_override,$subkey);
    }

    return $value;
}

sub get_gpg {
    my $self = shift;
    my $class = ref($self);

    no strict 'refs';
    if (defined ${"${class}::config"}->{gpg_key}){
        return ${"${class}::config"}->{gpg_key};
    }

    my $module_path = $class;
    $module_path =~ s/::/\//g;
    $module_path .= '.pm';
    $module_path = $INC{$module_path};
    $module_path =~ s/.pm$//;
    my $passphrase_file = sprintf('%s/%s',$module_path,'gpg');
    open(my $fh, '<', "$passphrase_file")
        or croak 'Can\'t open gpg passphrase file for ' . ref($self) . " at $passphrase_file";
    close($fh);

    ${"${class}::config"}->{gpg_key} = $passphrase_file;

    return $passphrase_file;
}

# UTILITIES FOR SUBCLASSES

sub luhn_is_valid {
    my $self = shift;
    my $itemtype_systemid = shift;
    my $barcode = shift;

    croak("Expected 5-digit item type + systemid") if $itemtype_systemid !~ /^\d{5}$/;
    return ($barcode =~ /^$itemtype_systemid\d{9}$/ and Algorithm::LUHN::is_valid($barcode));

}

sub ia_ark_id_is_valid {
    my $self = shift;
    my $ark_id = shift;

    # match ia scheme
    return unless ( $ark_id =~ m|ark:/13960/t\d[a-z\d][a-z\d]\d[a-z\d][a-z\d]\d[a-z\d]| );
    # trim off ark:/
    $ark_id =~ s/^ark:\///;
    # validate check char
    return unless ( noid_checkchar( $ark_id ) );

    return 1;
}


# NOID check character routine - from Noid.pm 
# Extended digits array.  Maps ordinal value to ASCII character.
my @xdig = (
    '0', '1', '2', '3', '4',   '5', '6', '7', '8', '9',
    'b', 'c', 'd', 'f', 'g',   'h', 'j', 'k', 'm', 'n',
    'p', 'q', 'r', 's', 't',   'v', 'w', 'x', 'z'
);
# $legalstring should be 0123456789bcdfghjkmnpqrstvwxz
my $legalstring = join('', @xdig);
my $alphacount = scalar(@xdig);        # extended digits count
my $digitcount = 10;           # pure digit count

# Ordinal value hash for extended digits.  Maps ASCII characters to ordinals.
my %ordxdig = (
    '0' =>  0,  '1' =>  1,  '2' =>  2,  '3' =>  3,  '4' =>  4,
    '5' =>  5,  '6' =>  6,  '7' =>  7,  '8' =>  8,  '9' =>  9,

    'b' => 10,  'c' => 11,  'd' => 12,  'f' => 13,  'g' => 14,
    'h' => 15,  'j' => 16,  'k' => 17,  'm' => 18,  'n' => 19,

    'p' => 20,  'q' => 21,  'r' => 22,  's' => 23,  't' => 24,
    'v' => 25,  'w' => 26,  'x' => 27,  'z' => 28
);

# Compute check character for given identifier.  If identifier ends in '+'
# (plus), replace it with a check character computed from the preceding chars,
# and return the modified identifier.  If not, isolate the last char and
# compute a check character using the preceding chars; return the original
# identifier if the computed char matches the isolated char, or undef if not.

# User explanation:  check digits help systems to catch transcription
# errors that users might not be aware of upon retrieval; while users
# often have other knowledge with which to determine that the wrong
# retrieval occurred, this error is sometimes not readily apparent.
# Check digits reduce the chances of this kind of error.
# yyy ask Steve Silberstein (of III) about check digits?

sub noid_checkchar{ my( $id )=@_;
    return undef
        if (! $id );
    my $lastchar = chop($id);
    my $pos = 1;
    my $sum = 0;
    my $c;
    for $c (split(//, $id)) {
        # if character undefined, it's ordinal value is zero
        $sum += $pos * (defined($ordxdig{"$c"}) ? $ordxdig{"$c"} : 0);
        $pos++;
    }
    my $checkchar = $xdig[$sum % $alphacount];
    #print "RADIX=$alphacount, mod=", $sum % $alphacount, "\n";
    return $id . $checkchar
        if ($lastchar eq "+" || $lastchar eq $checkchar);
    return undef;       # must be request to check, but failed match
    # xxx test if check char changes on permutations
    # XXX include test of length to make sure < than 29 (R) chars long
    # yyy will this work for doi/handles?
}


1;
__END__

=head1 NAME

HTFeed::Namespace -- Feed namespace management

=head1 SYNOPSIS

 use HTFeed::Namespace;

 $namespace = new HTFeed::Namespace('mdp','google');
 $grinid = $namespace->get('grinid');

=head1 Description

This is the superclass for all namespaces. It provides a common interface to get configuration 
variables and overrides for namespace/package type combinations.

=head2 METHODS

=over 4

=item new()

=item get()

Returns a given configuration variable. First searches the packagetype override
for a given configuration variable. If not found there, uses the namespace base
configuration, and if not there, the package type base configuration.

$value = get($config);

=item get_validation_overrides()

Collects the validation overrides from the current namespace and package type
for the given validation module (e.g. HTFeed::ModuleValidator::JPEG2000_hul) 

$overrides = get_validation_overrides($module);

=item get_namespace()

=item ia_ark_id_is_valid()

=item get_packagetype()

=item noid_checkchar()

=item get_event_configuration()

=item get_event_description()

Collects the info for a given PREMIS event type, as specified in the global configuration
and optionally overridden in package type and namespace configuration.

$desc = get_event_description($eventtype);

=item get_gpg()

=item load_gpg()

Returns the gpg passphrase string from the file gpg in the namespace directory

=item luhn_is_valid()

Returns true if the given barcode is valid for a book according to the common
'codabar mod 10' barcode scheme and has the given system ID.

luhn_is_valid($systemid, $barcode);

=back

INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
