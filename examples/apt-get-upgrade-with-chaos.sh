#!/bin/bash
# assumes run as root

RANDOM_NUM=$(shuf -i 1-5 -n 1)
if [[ $RANDOM_NUM -eq 1 ]]; then
    echo "Adding failure"

    cat << EOF > /etc/systemd/system/kustodian-restart.service
[Unit]
Description=Add failure for kustodian

[Service]
Type=simple
ExecStart=/bin/bash -c "sudo reboot"

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable kustodian-restart.service
    touch /var/run/reboot-required

    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
wait_for_apt_locks() {
  while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
    echo 'Waiting for release of apt locks'
    sleep 3
  done
}
wait_for_reboot() {
  while fuser /var/run/reboot-required >/dev/null 2>&1; do
    echo 'Waiting for reboot'
    sleep 3
  done
}
wait_for_reboot
wait_for_apt_locks
apt-get update
wait_for_apt_locks
apt-mark unhold $(apt-mark showhold | grep -v 'kube')
apt-get upgrade -y
wait_for_apt_locks
apt-get upgrade -y $(apt-mark showmanual | grep -v 'kube')
wait_for_apt_locks
sleep 60 # wait a bit for apt to mark /var/run-reboot-required
wait_for_reboot
echo 'Exiting successfully'