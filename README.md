# Pleb-VPN
Pleb-VPN is a raspiblitz tool set that allows you to easily take your node
from a tor-only node to a hybrid solution with a public vps - either yours or
someone elses! It also includes a number of tools to facilitate this, including
an easy-to-install implementation of wireguard for private, secure VPN access
to your node anywhere, anytime, and the ability to automatically send recurring
payments over lightning via keysend (credit to m00ninite's excellent scripts,
found here: https://github.com/rootzoll/raspiblitz/pull/2404).

Pleb-VPN was born out of the realization that tor was always going to be
insufficient for routing nodes, and that most plebs either can't afford
or can't set up (or both) a vps with a vpn and enable hybrid mode on their
node. Enter Pleb-VPN! This enables easy vps sharing and lowers the cost of
going clearnet for plebs.

Pleb-VPN is free open-source software, and uses openvpn, wireguard, and scripts
to configure either LND or Core Lightning (or both!) for hybrid mode. You may
use this in conjunction with your own vps set up as an openvpn server or you may
contact me on TG @allyourbankarebelongtous or via email: 
allyourbankarebelongtous@protonmail.com, agree to a small monthly fee, and obtain
access to my vps to go clearnet. You would be paying for vps access/use, not for
Pleb-VPN.

# Install instructions:
1. Exit to command line from the menu (you should be in directory /home/admin).
2. From /home/admin, clone the repository `git clone https://github.com/allyourbankarebelongtous/Pleb-VPN.git`
3. Fix the permissions, run `sudo chmod -R 755 /home/admin/pleb-vpn`
4. Run the install script `sudo /home/admin/pleb-vpn/pleb-vpn.install.sh on`

Access Pleb-VPN from the menu and try it out!
