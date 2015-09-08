#!/usr/bin/perl
use strict;
use warnings;

sub getLoggingTime {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "[%04d/%02d/%02d %02d:%02d:%02d] ",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $nice_timestamp;
}

# timestamped print
sub myprint {
    my $timestamp = getLoggingTime();
    print "$timestamp " . "@_";
}

# Subroutine to verify that the named IP routing table in param 1 has
# a default route.
# Param 2 can optionally specify verbose output
# Returns 1 if network has default route present, else return 0
sub hasdefaultroute {

    my $network = shift(@_);
    my $verbose = shift(@_);
    myprint "checking $network network\n" if "$verbose";
    my $command = "ip route show table $network | grep -i '^default'";
    my $result = system("$command >/dev/null 2>&1");
    if ($result) {
        myprint "WARN: No default route in table $network\n" if "$verbose";
        return 0;
    } else {
        myprint "Info: $network passes (has default route)\n" if "$verbose";
        return 1;
    }
}
# number of times we are allowed to fix the routes
# default 0 => do not try at all
my $fixes = 0;

my $override = shift @ARGV;
if ($override>0) {
    $fixes = $override;
}

my $mgmt_if    = shift @ARGV;
my $storage_if = shift @ARGV;
my $float_if   = shift @ARGV;

sub check_networks() {
    my $mgmt_stat = system("ifconfig $mgmt_if | grep 'inet addr' >/dev/null 2>&1");
    if ($mgmt_stat) {
	myprint"mgmt $mgmt_if down\n";
	return 0;
    }
    my $storage_stat = system("ifconfig $storage_if | grep 'inet addr' >/dev/null 2>&1");
    if ($storage_stat) {
	myprint"storage $storage_if down\n";
	return 0;
    }
    my $float_stat = system("ifconfig $float_if | grep 'inet addr' >/dev/null 2>&1");
    if ($float_stat) {
	myprint"float $float_if down\n";
	return 0;
    }
    return 1;
}


myprint "-----------------------------------------------------\n";
myprint "Service \"routemon \" starting ...\n";
myprint "-----------------------------------------------------\n";
myprint "Allowable fix attempts set to: $fixes\n";
myprint("Management interface specified: $mgmt_if\n");
myprint("Storage    interface specified: $storage_if\n");
myprint("Floating   interface specified: $float_if\n");

sub no_network_bail {
    if (!check_networks()) {
	# let's wait until the network is properly up.
	# upstart will respawn us
	sleep 10;
	myprint("routemon: Network not fully up - terminating\n");
	exit 0;
    }
}

no_network_bail();

# check and retain current status of routes for comparison later
my $mgmt_up    = hasdefaultroute ("mgmt", 1);
my $storage_up = hasdefaultroute ("storage", 1);

# true if either network lacks a default route
my $routedown = (!($mgmt_up && $storage_up));

sub fix_routes {
    if ($fixes>0) {
        myprint "Now attempting to fix default routes...\n";
        my $fixcommand = "/etc/network/if-up.d/bcpc-routing";
        system("$fixcommand");
        $fixes--;
        # check and see if the routes came back here
        $mgmt_up    = hasdefaultroute ("mgmt", 1);
        $storage_up = hasdefaultroute ("storage", 1);
        if ($mgmt_up && $storage_up) {
            myprint "Fixed. Remaining fixes: $fixes\n";
            $routedown = 0;
        } else {
	    myprint("routemon: Network not fully up - terminating\n");
	    sleep 10;
	    exit 0;
        }
    } else {
        myprint "No fixes left\n";
    }
}

# Attempt to start in a good state before we begin monitoring the IP
# subsystem
if ($routedown) {
    fix_routes();
}

myprint "Monitoring default routes status  ...\n";

# When routes go bad, print out the last few events for diagnostic
# purposes.
my @scrollback;

sub dump_scrollback() {
        
    myprint "-----------------------------------------------------\n";
    
    while (my $line = shift @scrollback) {
        myprint $line;
    }
    
    myprint "-----------------------------------------------------\n";
}


while (1) {
    
    myprint "Open \"ip monitor\" stream\n";
    
    # monitor all IP events and after each one check to see whether
    # the default route appeared or disappeared
    my $child = open (IPEVENTS, "ip monitor all |") or die "Failed $!\n";
    while (<IPEVENTS> )
    {
        my $LINE = $_;
        
        push @scrollback, $LINE;
        while ($#scrollback > 10) {
            shift @scrollback;          
        }
        
        my $currentmgmt = hasdefaultroute("mgmt",0);
        if ($currentmgmt != $mgmt_up) {
            if ($currentmgmt) {
                myprint "Info: Default route established on mgmt network, last events: \n";
            } else {
                $routedown = 1;
                myprint "WARN: Default route disappeared on mgmt network, last events: \n";
                dump_scrollback();
            }
        }
        $mgmt_up = $currentmgmt;
        
        my $currentstorage = hasdefaultroute("storage",0);
        if ($currentstorage != $storage_up) {
            if ($currentstorage) {
                myprint "Info: Default route established on storage network, last events: \n";
            } else {
                $routedown = 1;
                myprint "WARN: Default route disappeared on storage network, last events: \n ";
                dump_scrollback();
            }
        }
        $storage_up = $currentstorage;

	no_network_bail();
       
        if ($routedown) {
            fix_routes();
            # give up monitoring this particular stream - throw away the output
            last;
        }
    }

    # terminate the sub-process to avoid leaking memory
    kill 15, $child;
    close IPEVENTS;

    # make sure we don't print any stale ip events
    undef(@scrollback);
}
