mdns-proxy
==========

mdns-proxy is a DNS proxy that accepts DNS queries and proxies them to Avahi for a multicast DNS lookup.

Description
-----------

When you're on a LAN, multicast DNS is a handy way to find machines, and generally alleviates the need for assigning static IPs to local machines.  But when connecting to that same LAN via a VPN, multicast DNS often isn't available, and suddenly you have to remember a bunch of IPs if you want to access the servers there.

mdns-proxy is designed to act as an authoritative DNS server that responds to domain X (e.g. ".vpn") and proxies to the multicast DNS "Avahi" daemon using multicast domain Y (e.g. ".local").

On your local DNS server, you can manually delegate domain X to the mdns-proxy server.  Now, if you query e.g. "myserver.vpn", mdns-proxy will receive your query and resolve it using Avahi as e.g. "myserver.local".  In essence, domain X becomes a remote mirror of multicast domain Y, even though you have no way to do normal mDNS to the LAN over your VPN link.

Usage
-----

You'll need to edit the constants at the top to reflect your network configuration.  Then just run the proxy.

If you're using a caching DNS proxy like djbdns's "dnscache", you'll probably need to listen on the standard DNS port (53), which requires root privileges.  If run as root, mdns-proxy will change to the "nobody" user after creating the UDP socket.  (Alternatively, you can use NAT rules to allow you to listen on another port.)

License
-------

mdns-proxy is released under the standard 2-clause BSD license.  See COPYING for details.

Todo
----

* IPv6 support (if the internet ever finally switches)
