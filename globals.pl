# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Jacob Steenhagen <jake@bugzilla.org>
#                 Bradley Baetz <bbaetz@student.usyd.edu.au>
#                 Christopher Aillon <christopher@aillon.com>
#                 Joel Peshkin <bugreport@peshkin.net>
#                 Dave Lawrence <dkl@redhat.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>
#                 Lance Larsh <lance.larsh@oracle.com>

# Contains some global variables and routines used throughout bugzilla.

use strict;

use Bugzilla::DB qw(:DEFAULT :deprecated);
use Bugzilla::Constants;
use Bugzilla::Util;
# Bring ChmodDataFile in until this is all moved to the module
use Bugzilla::Config qw(:DEFAULT ChmodDataFile $localconfig $datadir);
use Bugzilla::User;
use Bugzilla::Error;

# Shut up misguided -w warnings about "used only once".  For some reason,
# "use vars" chokes on me when I try it here.

sub globals_pl_sillyness {
    my $zz;
    $zz = @main::legal_bug_status;
    $zz = @main::legal_opsys;
    $zz = @main::legal_platform;
    $zz = @main::legal_priority;
    $zz = @main::legal_severity;
}

#
# Here are the --LOCAL-- variables defined in 'localconfig' that we'll use
# here
# 

# XXX - Move this to Bugzilla::Config once code which uses these has moved out
# of globals.pl
do $localconfig;

use DBI;

use Date::Format;               # For time2str().
use Date::Parse;               # For str2time().

# Use standard Perl libraries for cross-platform file/directory manipulation.
use File::Spec;

# XXXX - this needs to go away
sub GenerateVersionTable {
    my $dbh = Bugzilla->dbh;

    @::legal_priority   = get_legal_field_values("priority");
    @::legal_severity   = get_legal_field_values("bug_severity");
    @::legal_platform   = get_legal_field_values("rep_platform");
    @::legal_opsys      = get_legal_field_values("op_sys");
    @::legal_bug_status = get_legal_field_values("bug_status");
    @::legal_resolution = get_legal_field_values("resolution");

    # 'settable_resolution' is the list of resolutions that may be set 
    # directly by hand in the bug form. Start with the list of legal 
    # resolutions and remove 'MOVED' and 'DUPLICATE' because setting 
    # bugs to those resolutions requires a special process.
    #
    @::settable_resolution = @::legal_resolution;
    my $w = lsearch(\@::settable_resolution, "DUPLICATE");
    if ($w >= 0) {
        splice(@::settable_resolution, $w, 1);
    }
    my $z = lsearch(\@::settable_resolution, "MOVED");
    if ($z >= 0) {
        splice(@::settable_resolution, $z, 1);
    }

    require File::Temp;
    my ($fh, $tmpname) = File::Temp::tempfile("versioncache.XXXXX",
                                              DIR => "$datadir");

    print $fh "#\n";
    print $fh "# DO NOT EDIT!\n";
    print $fh "# This file is automatically generated at least once every\n";
    print $fh "# hour by the GenerateVersionTable() sub in globals.pl.\n";
    print $fh "# Any changes you make will be overwritten.\n";
    print $fh "#\n";

    require Data::Dumper;

    print $fh (Data::Dumper->Dump([\@::legal_priority, \@::legal_severity,
                                   \@::legal_platform, \@::legal_opsys,
                                   \@::legal_bug_status, \@::legal_resolution],
                                  ['*::legal_priority', '*::legal_severity',
                                   '*::legal_platform', '*::legal_opsys',
                                   '*::legal_bug_status', '*::legal_resolution']));

    print $fh (Data::Dumper->Dump([\@::settable_resolution],
                                  ['*::settable_resolution']));

    print $fh "1;\n";
    close $fh;

    rename ($tmpname, "$datadir/versioncache")
        || die "Can't rename $tmpname to versioncache";
    ChmodDataFile("$datadir/versioncache", 0666);
}


$::VersionTableLoaded = 0;
sub GetVersionTable {
    return if $::VersionTableLoaded;
    my $file_generated = 0;
    if (!-r "$datadir/versioncache") {
        GenerateVersionTable();
        $file_generated = 1;
    }
    require "$datadir/versioncache";
    $::VersionTableLoaded = 1;
}

sub DBID_to_name {
    my ($id) = (@_);
    return "__UNKNOWN__" if !defined $id;
    # $id should always be a positive integer
    if ($id =~ m/^([1-9][0-9]*)$/) {
        $id = $1;
    } else {
        $::cachedNameArray{$id} = "__UNKNOWN__";
    }
    if (!defined $::cachedNameArray{$id}) {
        PushGlobalSQLState();
        SendSQL("SELECT login_name FROM profiles WHERE userid = $id");
        my $r = FetchOneColumn();
        PopGlobalSQLState();
        if (!defined $r || $r eq "") {
            $r = "__UNKNOWN__";
        }
        $::cachedNameArray{$id} = $r;
    }
    return $::cachedNameArray{$id};
}

# Returns a list of all the legal values for a field that has a
# list of legal values, like rep_platform or resolution.
sub get_legal_field_values {
    my ($field) = @_;
    my $dbh = Bugzilla->dbh;
    my $result_ref = $dbh->selectcol_arrayref(
         "SELECT value FROM $field
           WHERE isactive = ?
        ORDER BY sortkey, value", undef, (1));
    return @$result_ref;
}

############# Live code below here (that is, not subroutine defs) #############

use Bugzilla;

1;
