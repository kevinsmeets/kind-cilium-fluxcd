#!/bin/bash
#
# Fix "too many open files" errors that can occur with KinD clusters.
# This adjusts systemd and inotify limits.
# A reboot or new terminal session may be required for changes to take effect.
#

echo "Value of /proc/sys/fs/file-max"
cat /proc/sys/fs/file-max

echo "ulimit -n"
ulimit -n

echo "ulimit -u"
ulimit -u

echo "ulimit -Sn"
ulimit -Sn

echo "ulimit -Su"
ulimit -Su

echo "Top 15 of processes with open files:"
sudo lsof | awk '{ print $1 " " $2 }' | sort -n | uniq -c | sort -rn | head -15

echo "Changing systemd configuration files..."
sudo sed -r -i -e "s/#DefaultLimitNOFILE=[0-9]+:[0-9]+/DefaultLimitNOFILE=524288:524288/g" /etc/systemd/system.conf

present_in_user_config=$(grep DefaultLimitNOFILE=524288:524288 /etc/systemd/user.conf)
if [ -z "$present_in_user_config" ]; then
    echo "DefaultLimitNOFILE=524288:524288" | sudo tee --append /etc/systemd/user.conf
fi

echo "Changing inotify configuration..."
present_in_sysctl=$(grep fs.inotify.max_user_instances=256 /etc/sysctl.conf)
if [ -z "$present_in_sysctl" ]; then
    echo "fs.inotify.max_user_instances=256" | sudo tee --append /etc/sysctl.conf
fi

echo "Reloading systemd configuration files..."
sudo systemctl daemon-reexec

echo "Open a new terminal and try 'ulimit -n' and 'sysctl fs.inotify.max_user_instances'..."
