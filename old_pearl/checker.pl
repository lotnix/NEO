#!/usr/bin/perl
################## METADATA ##################
# AUTHOR: Marcus Siöström
# PURPOSE: Verify connectivity from different subnets and present in html
# DATE OF LAST CHANGE: 2018-12-02
##############################################

use warnings;
use strict;
use sigtrap qw/handler signal_handler normal-signals/; #Provides error handler
use IO::Socket::INET; #Provides TCP port checker
use Net::Netmask; #Privides netmask/ip matching


# Global vars
my $html_output_file = '/etc/nettest/html/result.html';
my $status_file = '/etc/nettest/html/status.html';
my ($dst, $tcp, $ping, $timeout) = @ARGV;
my %interfaces;
my @dst_addrs;
my $time = localtime;


# Secure inputs
$dst      =~ s/[^0-9a-zA-Z-\.,]//g;
$tcp      =~ s/[^0-9,]//g;
$ping     =~ s/[^(0|1)]//g;
$timeout  =~ s/[^0-9]//g;


# Create arrays from input strings
my @dst_input = split /,/, $dst;
my @tcp_ports = split /,/, $tcp;


# Create hash for interfaces. Data populated by Ansible variables
my %int_settings_INTSERVERS = (
  ip         => "10.99.4.5",
  gateway    => "10.99.4.1",
  network    => "10.99.4.0",
  prefix     => "24",
  interface  => "eth1.4",
);
$interfaces{INTSERVERS} = \%int_settings_INTSERVERS;
my %int_settings_WIFI_TESTDEVICES = (
  ip         => "10.99.8.5",
  gateway    => "10.99.8.1",
  network    => "10.99.8.0",
  prefix     => "24",
  interface  => "eth1.8",
);
$interfaces{WIFI_TESTDEVICES} = \%int_settings_WIFI_TESTDEVICES;
my %int_settings_PT = (
  ip         => "10.99.9.5",
  gateway    => "10.99.9.1",
  network    => "10.99.9.0",
  prefix     => "24",
  interface  => "eth1.9",
);
$interfaces{PT} = \%int_settings_PT;
my %int_settings_DIRECTORS = (
  ip         => "10.99.10.5",
  gateway    => "10.99.10.1",
  network    => "10.99.10.0",
  prefix     => "24",
  interface  => "eth1.10",
);
$interfaces{DIRECTORS} = \%int_settings_DIRECTORS;
my %int_settings_DEV = (
  ip         => "10.99.11.5",
  gateway    => "10.99.11.1",
  network    => "10.99.11.0",
  prefix     => "24",
  interface  => "eth1.11",
);
$interfaces{DEV} = \%int_settings_DEV;
my %int_settings_LAN = (
  ip         => "10.99.12.5",
  gateway    => "10.99.12.1",
  network    => "10.99.12.0",
  prefix     => "24",
  interface  => "eth1.12",
);
$interfaces{LAN} = \%int_settings_LAN;
my %int_settings_DEVOPS = (
  ip         => "10.99.13.5",
  gateway    => "10.99.13.1",
  network    => "10.99.13.0",
  prefix     => "24",
  interface  => "eth1.13",
);
$interfaces{DEVOPS} = \%int_settings_DEVOPS;
my %int_settings_HR = (
  ip         => "10.99.14.5",
  gateway    => "10.99.14.1",
  network    => "10.99.14.0",
  prefix     => "24",
  interface  => "eth1.14",
);
$interfaces{HR} = \%int_settings_HR;
my %int_settings_FINANCE = (
  ip         => "10.99.15.5",
  gateway    => "10.99.15.1",
  network    => "10.99.15.0",
  prefix     => "24",
  interface  => "eth1.15",
);
$interfaces{FINANCE} = \%int_settings_FINANCE;
my %int_settings_WIFI = (
  ip         => "10.99.16.5",
  gateway    => "10.99.16.1",
  network    => "10.99.16.0",
  prefix     => "24",
  interface  => "eth1.16",
);
$interfaces{WIFI} = \%int_settings_WIFI;
my %int_settings_WIFI_GUEST = (
  ip         => "10.99.17.5",
  gateway    => "10.99.17.1",
  network    => "10.99.17.0",
  prefix     => "24",
  interface  => "eth1.17",
);
$interfaces{WIFI_GUEST} = \%int_settings_WIFI_GUEST;
my %int_settings_WIFI_BYOD = (
  ip         => "10.99.19.5",
  gateway    => "10.99.19.1",
  network    => "10.99.19.0",
  prefix     => "24",
  interface  => "eth1.19",
);
$interfaces{WIFI_BYOD} = \%int_settings_WIFI_BYOD;
my %int_settings_UNTRUSTED = (
  ip         => "10.99.20.5",
  gateway    => "10.99.20.1",
  network    => "10.99.20.0",
  prefix     => "24",
  interface  => "eth1.20",
);
$interfaces{UNTRUSTED} = \%int_settings_UNTRUSTED;
my %int_settings_MGMT = (
  ip         => "10.99.0.5",
  gateway    => "10.99.0.1",
  network    => "10.99.0.0",
  prefix     => "24",
  interface  => "eth1",
);
$interfaces{MGMT} = \%int_settings_MGMT;
my %int_settings_IT = (
  ip         => "10.99.5.6",
  gateway    => "10.99.5.1",
  network    => "10.99.5.0",
  prefix     => "24",
  interface  => "eth0",
);
$interfaces{IT} = \%int_settings_IT;


# Loop trough array of destinations. If hostname, replace with DNS
foreach my $dst ( @dst_input ) {

  # Check if DNS name
  if ($dst =~ m/[^0-9\.]/) {

    # Try to resolve
    my @resolved_addrs = resolve_dns($dst);
    push(@dst_addrs, @resolved_addrs);
    print "Resolved: \n";
    foreach my $resolved_addr ( @resolved_addrs ) {
      print "$resolved_addr\n";
    }

  } else {
    push(@dst_addrs, $dst);
  }
}



# Calculate ETA
my $eta_int     = keys %interfaces;
my $eta_dst     = @dst_addrs;
my $eta_port    = @tcp_ports;
my $eta_checks  = $eta_port + $ping;
my $eta         = $eta_int * $eta_dst * $eta_checks * $timeout;


# Save start timestamp
open(my $status_fh, '>', $status_file) or die "Could not open file '$status_file' $!";
print $status_fh "Start: $time CET<br />\n";
print $status_fh "Max ETA: $eta sec<br />\n";
print $status_fh "Scan is running. Please wait..<br />\n";
close $status_fh;
undef $status_fh;


# Clear html result from previous run
open(my $fh, '>', $html_output_file) or die "Could not open file '$html_output_file' $!";
print $fh "<table class=\"result-table\">\n";
close $fh;
undef $fh;





# Main program. Loop trough interfaces
foreach my $int (keys %interfaces) {

  # Create result arrau with headers
  my @result_array = ("$int", "source: $interfaces{$int}{ip}");

  # Set def GW for current interface being tested
  set_gateway($interfaces{$int}{gateway});

  # Loop trough array of destination IP addresses to check
  foreach my $dst_addr ( @dst_addrs ) {

    #Split IP and DNS
    my @dst_array = split /</, $dst_addr;

    # Keep track of interfaces brought down by next function so we can restore them
    my $disabled_interface;

    # If destination is in a directly attached network that we are not currently scanning from, disable it.
    foreach my $other_int (keys %interfaces) {
      my $directly_attached_subnet = Net::Netmask->new("$interfaces{$other_int}{network}/$interfaces{$other_int}{prefix}");
      my $current_source_subnet = Net::Netmask->new("$interfaces{$int}{network}/$interfaces{$int}{prefix}");
      if ($directly_attached_subnet->match($dst_array[0]) && !($current_source_subnet->match($dst_array[0]))) {
        interface_state("down","$interfaces{$other_int}{interface}");
        $disabled_interface = "$interfaces{$other_int}{interface}";
      }
    }

    # Loop trough array of tcp ports and check connectivity
    foreach my $tcp_port ( @tcp_ports ) {
      my $result = check_port($interfaces{$int}{ip}, $dst_addr, $tcp_port, $timeout);
      push @result_array, split /,/, $result;
    }

    # If ping variable is set, check ping
    if ($ping) {
      my $result = check_ping($interfaces{$int}{ip}, $dst_addr, $timeout);
      push @result_array, split /,/, $result;
    }

    # Bring up disabled interface
    if ($disabled_interface) {
      interface_state("up","$disabled_interface");
    }

  }

  # Grenrate html table
  html_generator(\@result_array);

}

# Close result table
open($fh, '>>', $html_output_file) or die "Could not open file '$html_output_file' $!";
print $fh "</table>\n";
close $fh;
undef $fh;


# Reset default gateway and bring up IT interface at end of program
set_gateway($interfaces{IT}{gateway});
interface_state("up","$interfaces{IT}{interface}");


# Save end timestamp
$time = localtime;
open($status_fh, '>>', $status_file) or die "Could not open file '$status_file' $!";
print $status_fh "Finished: $time CET<br />\n";
print $status_fh "Scan is done.\n";
close $status_fh;
undef $status_fh;







# Subroutines
sub set_gateway {
  # Get arguments
  my ($gateway) = @_;

  # Find all current def gateways and put into array
  my $get_all_def_gw = `/usr/sbin/route -n | awk '{print \$2}' | grep 10.99`;
  my @def_gws = split /\n/, $get_all_def_gw;

  # Unset all def GWs found
  foreach my $def_gw ( @def_gws ) {
    `/usr/sbin/route del default gw $def_gw`;
  }

  # Set new def GW
  `/usr/sbin/route add default gw $gateway`;
}


sub interface_state {
  my ($desired_state,$interface) = @_;

  # Get current status of interface
  my $int_status = `cat /sys/class/net/$interface/operstate 2>/dev/null`;
  chomp($int_status);

  if ($desired_state eq "up") {
    # Start int if it is down
    if ($int_status ne "up") {
      `/usr/sbin/ifup $interface`;
    }
  } else {
    # Stop int if it is up
    if ($int_status eq "up") {
      `/usr/sbin/ifdown $interface`;
    }
  }
}


sub resolve_dns {
  # Get arguments
  my ($dns_name) = @_;

  my @ip_array = `host -t A -W 10 "$dns_name" 2>/dev/null | awk '/has address/ {print \$4}' | sed "s/\$/<$dns_name/"`;
  chomp @ip_array;
  return @ip_array;
}


sub check_ping {
  # Get arguments
  my ($src_ip, $dst_ip, $timeout) = @_;

  my @dst_array = split /</, $dst_ip;

  # Check connectivity
  my $socket = `ping -4 -I $src_ip -c1 -q -n -W $timeout $dst_array[0] 2>&1`;

  # Return status
  if ($dst_array[1]) {
    if ($socket =~ /.*1 packets transmitted, 1 received.*/) {
      return "$dst_array[1] => $dst_array[0],ICMP,OPEN";
    } elsif ($socket =~ /.*1 packets transmitted, 0 received.*/) {
      return "$dst_array[1] => $dst_array[0],ICMP,CLOSED";
    } else {
      return "$dst_array[1] => $dst_array[0],ICMP,ERROR";
    }
  } else {
    if ($socket =~ /.*1 packets transmitted, 1 received.*/) {
      return "$dst_array[0],ICMP,OPEN";
    } elsif ($socket =~ /.*1 packets transmitted, 0 received.*/) {
      return "$dst_array[0],ICMP,CLOSED";
    } else {
      return "$dst_array[0],ICMP,ERROR";
    }
  }
}


sub check_port {
  # Get arguments
  my ($src_ip, $dst_ip, $port, $timeout) = @_;

  my @dst_array = split /</, $dst_ip;

  # Check connectivity
  my $socket = IO::Socket::INET->new(PeerAddr => $dst_array[0],
    PeerPort    => $port,
    Proto       => 'tcp',
    LocalAddr   => $src_ip,
    Timeout     => $timeout);

  # Return status
  if ($dst_array[1]) {
    if ($socket) {
      return "$dst_array[1] => $dst_array[0],TCP/$port,OPEN";
      $socket->close();
    } else {
      return "$dst_array[1] => $dst_array[0],TCP/$port,CLOSED";
    }
  } else {
    if ($socket) {
      return "$dst_array[0],TCP/$port,OPEN";
      $socket->close();
    } else {
      return "$dst_array[0],TCP/$port,CLOSED";
    }
  }
}


sub html_generator {
  my @result_array = @{$_[0]};
  my $int = shift @result_array;
  my $src = shift @result_array;

  open($fh, '>>', $html_output_file) or die "Could not open file '$html_output_file' $!";
  print $fh "  <tr>\n";
  print $fh "    <td>\n";
  print $fh "      $int\n";
  print $fh "    </td>\n";
  print $fh "    <td>\n";
  print $fh "      $src\n";
  print $fh "    </td>\n";
  print $fh "  </tr>\n";

  while(my ($x,$y,$z) = splice(@result_array,0,3)) {
    print $fh "  <tr class=\"data-tr\">\n";
    print $fh "    <td>\n";
    print $fh "      $x\n";
    print $fh "    </td>\n";
    print $fh "    <td>\n";
    print $fh "      $y\n";
    print $fh "    </td>\n";

    if ($z eq "OPEN") {
      print $fh "    <td class=\"td-green\">\n";
    } else {
      print $fh "    <td class=\"td-red\">\n";
    }

    print $fh "      $z\n";
    print $fh "    </td>\n";
    print $fh "  </tr>\n";
  }

  print $fh "  <tr class=\"tr-spacer\">\n";
  print $fh "  </tr>\n";

  close $fh;
  undef $fh;

}


sub signal_handler {
  # Error handler. Reset def gateway to IT in case program is killed.
  print "Caught kill. Resetting def GW to main network\n";
  interface_state("up","$interfaces{IT}{interface}");
  set_gateway($interfaces{IT}{gateway});
  die "Caught a signal $!";
}
