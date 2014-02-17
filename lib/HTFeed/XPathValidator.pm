package HTFeed::XPathValidator;

use warnings;
use strict;
use Carp;
use Log::Log4perl qw(get_logger);
use Exporter;

use base qw(HTFeed::SuccessOrFailure Exporter);

use XML::LibXML;

sub _xpathInit{
    my $self = shift;

    $$self{contexts} = {};
    $$self{fail} = 0;

    $self->_set_required_querylib();

    unless(Log::Log4perl->initialized()){
        croak 'Log4Perl not initialized, cannot report errors';
    }

    return 1;
}

# ** methods to impliment SuccessOrFailure **

# returns 0 if tests succeeded, non-0 if tests failed
sub failed{
    my $self = shift;
    return $$self{fail};
}

# set fail, log errors
# absract
sub set_error{
    croak("This is an abstract method");
}

#
# ** Methods for Running XPath Queries **
# 
# subclasses should stick to these methods to run XPath queries
# if they aren't sufficient, extend these if possible, rather than directly running queries
#
# qn = query name (to search for)
# base = query base, the context to search in
# cn = context name (to search for)
# 

# (base, qn)
# returns nodelist object
sub _findnodes{
    my $self = shift;
    my $base = shift;
    my $qn = shift;

    # get query out of qlib
    my $query = $self->{qlib}->query($base,$qn);

    my $base_node = $self->{contexts}->{$base}->{node};
    my $xpc = $self->{contexts}->{$base}->{xpc};

    if ($xpc && $query){
        my $nodelist = $xpc->findnodes($query,$base_node);
        return $nodelist;
    }

    $self->set_error("MissingField", $self->get_details($base,$qn));
    return;
}

# (cn)
# returns nodelist object
sub _findcontexts{
    my $self = shift;
    my $cn = shift;
    my $base = $self->{qlib}->context_parent($cn);

    # get query out of qlib
    my $query = $self->{qlib}->context($cn);

    my $base_node = $self->{contexts}->{$base}->{node};
    my $xpc = $self->{contexts}->{$base}->{xpc};

    if ($xpc && $query){
        my $nodelist = $xpc->findnodes($query,$base_node);
        return $nodelist;
    }

    return;
}

# (base, qn)
# returns only node found or
# sets error and returns undef
sub _findonenode{
    my $self = shift;
    my ($base,$qn) = @_ or croak("_findonenode: invalid args");

    # run query
    my $nodelist = $self->_findnodes(@_);

    # detect error in _findnodes, fail
    unless ($nodelist){
        $self->set_error("MissingField", $self->get_details($base,$qn));
        return;
    }

    # if hit count != 1 fail
    unless ($nodelist->size() == 1){
        my $error_msg = "";
        $error_msg .= $nodelist->size();
        $error_msg .= " hits for context query; exactly one expected";
        $self->set_error("BadField", $self->get_details($base,$qn), detail => $error_msg);
        return;
    }

    my $node = $nodelist->pop();
    return $node;
}

# (base, qn)
# returns scalar value (generally a string)
sub _findvalue{
    my $self = shift;
    my $base = shift;
    my $query = shift;

    # check/get query
    my $query_info = $self->{qlib}->query_info($base, $query) or croak ("_findvalue: invalid args");
    my $queryObj = $query_info->{query};
    my $context_name = $self->{qlib}->context_name($base);

    my $context_info = 
    # verbose logging for debug
    get_logger()->trace("  looking for value of $query_info->{desc} in $context_name (remediable=$query_info->{remediable})...");

    # get root xpc, context node
    my $context_node = $self->{contexts}->{$base}->{node};
    my $xpc = $self->{contexts}->{$base}->{xpc};

    return unless defined $xpc;
    # run query
    if($xpc && $queryObj) {
        return $xpc->findvalue($queryObj,$context_node);
    }
    $self->set_error("MissingField", $self->get_details($base,$query));
    return;
}

# (base, qn)
# returns scalar value of only node found or
# sets error and returns false
sub _findone{
    my $self = shift;
    unless($self->_findonenode(@_)){ 
        return;
    }
    else{
        return $self->_findvalue(@_);
    }
}

# (base, qn, text)
# "text" is the expected output of the query
# returns 1 or sets error and returns false
sub _validateone{
    my ($self,$base,$qn,$expected) = @_;

    my $actual = $self->_findone($base,$qn);
    if (defined($actual) and $expected eq $actual){
        return 1;
    }
    else{
        $self->set_error("BadValue", $self->get_details($base,$qn), actual => $actual, expected => $expected);
        return 0;
    }
}

# (base1, qn1, base2, qn2)
# requires that value of query 1 equal value of query2
sub _require_same {
    my $self = shift;
    my ($base1, $qn1, $base2, $qn2) = @_;
    my $found1 = $self->_findone($base1,$qn1);
    my $found2 = $self->_findone($base2,$qn2);
    if(defined($found1) and defined($found2) and $found1 eq $found2) {
        return 1;
    } elsif(defined($found1) and defined($found2)) {
        $self->set_error("NotEqualValues", $self->get_details($base1,$qn1,$base2,$qn2), 
            actual => {"${base1}_${qn1}" => $found1,
                "${base2}_${qn2}" => $found2});
    }
    return 0;
}

# (name => "name",node => $node,xpc => $xpc)
# xpc required unless we can get it from a parent
# node required if you don't want to always be searching from the root
#
# saves node, xpc as context of record for cn
sub _setcontext{
    my $self = shift;
    my %arg_hash = (
        name	=> undef,
        node	=> undef,
        xpc		=> undef,
        @_,
    );
    my $cn = $arg_hash{name};
    my $node = $arg_hash{node};
    my $xpc = $arg_hash{xpc};

    # check parameters
    croak "_setcontext: context name undef" unless($cn);
    croak "_setcontext: can't set context to undef" unless(defined($node) or defined($xpc));

    if (! $xpc){
        # get root xpc from parent
        my $parent_name = $self->{qlib}->context_parent($cn);
        $xpc = $self->{contexts}->{$parent_name}->{xpc};
    }
    # set
    $self->{contexts}->{$cn} = {node => $node, xpc => $xpc};
    return 1;

}

# (cn)
# finds and saves a node as context node of record for cn
# or returns false and sets error
sub _openonecontext{
    my $self = shift;
    my ($cn) = @_ or croak("_openonecontext: invalid args");

    # run query
    my $nodelist = $self->_findcontexts(@_);

    # if hit count != 1 fail
    unless ($nodelist and $nodelist->size() == 1){
        my $error_msg = "";
        $error_msg .= $nodelist->size();
        $error_msg .= " hits for context query: $cn exactly one expected";
        $self->set_error("BadValue", detail => $error_msg, $self->get_details($cn));
        return;
    }
    my $node = $nodelist->pop();

    $self->_setcontext(name => $cn, node => $node);
    return 1;
}

# Validation closures

our @EXPORT_OK = qw(v_and v_exists v_same v_gt v_lt v_ge v_le v_eq v_between v_in);
our %EXPORT_TAGS = ( 'closures' => \@EXPORT_OK );

# Returns a sub that returns true if all of the parameter subs return true
sub v_and {
    my @subs = @_;

    return sub {
        my $self = shift;
        my $ok = 1;
        # don't short circuit
        foreach my $sub (@subs) {
            &$sub($self) or $ok = 0;
        }
        return $ok;
    }

}

sub v_exists {
    my @params = @_;
    return sub {
        my $self = shift;
        return $self->_findone(@params);
    }
}

sub v_same {
    my @params = @_;
    return sub {
        my $self = shift;
        return $self->_require_same(@params);
    }
}

sub _make_op_compare {
    my ($ctx,$query,$expected,$op) = @_;
    croak('Usage: _make_op_compare $ctx $query $expected $op') unless defined $ctx and defined $query and defined $expected and defined $op;
    return eval <<EOT;
sub {
    my \$self = shift;
    my \$actual = \$self->_findone(\$ctx, \$query);
    if('$op' ne 'eq' and \$actual =~ /^(\\d+)/) {
        \$actual = \$1;
    }
    if (\$actual $op \$expected) {
    return 1;
    } else {
        my \$report_op = '$op ';
        \$report_op = '' if \$report_op eq 'eq ';
    \$self->set_error("BadValue", \$self->get_details(\$ctx, \$query), actual => \$actual, expected => "\$report_op\$expected");
    return;
    }
}
EOT

}

# Numeric greater/less/greater-or-equal/less-or-equal
sub v_gt { return _make_op_compare(@_,">"); }
sub v_lt { return _make_op_compare(@_,"<"); }
sub v_ge { return _make_op_compare(@_,">="); }
sub v_le { return _make_op_compare(@_,"<="); }
# String equality
sub v_eq { return _make_op_compare(@_,"eq"); }

# Inclusive range
sub v_between {
    my ($ctx,$query,$lower,$upper) = @_;
    return v_and(v_ge($ctx,$query,$lower), v_le($ctx,$query,$upper));
}

# actual must be string-equal to one in @$allowed
sub v_in { 
    my ($ctx,$query,$allowed) = @_;

    return sub {
        my $self = shift;
        my $actual = $self->_findone($ctx,$query);
        foreach my $expected (@$allowed) {
            return 1 if ($actual eq $expected);
        }

        $self->set_error("BadValue", $self->get_details($ctx,$query), actual => $actual, expected => "one of (" . join(", ",@$allowed) . ")");
    }
}

# get additional information about fields that failed from the querylib module
# for logging errors
sub get_details {
    my $self = shift;
    my $ctx = shift;
    my $query = shift;
    my $ctx2 = shift;
    my $query2 = shift;

    my $desc = $self->{qlib}->context_name($ctx);
    my $remediable = 0;
    if(defined $query) {
        my $query_info = $self->{qlib}->query_info($ctx, $query) or croak ("_findvalue: invalid args");
        $desc = "in $desc - $query_info->{desc}";
        $remediable = $query_info->{remediable} if $query_info->{remediable};
    }

    if(defined $ctx2) {
        my $desc2 = $self->{qlib}->context_name($ctx2);
        if(defined $query2) {
            my $query_info = $self->{qlib}->query_info($ctx2, $query2) or croak ("_findvalue: invalid args");
            $desc2 = "in $desc2 - $query_info->{desc}";
            if( ($query_info->{remediable} or $remediable)
                and not ($query_info->{remediable} and $remediable)) {
                # if one or the other field is remediable, say 'possibly remediable'
                $remediable = 2;
            } 
        }
        $desc .= ", $desc2";
    }


    return (field => $desc, remediable => $remediable);

}


1;

__END__;
