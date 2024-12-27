#!/bin/bash

# Ensure the script is executed with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Download the secondary VNIC configuration script directly to /usr/local/sbin
wget https://raw.githubusercontent.com/oracle/terraform-examples/refs/heads/master/examples/oci/connect_vcns_using_multiple_vnics/scripts/secondary_vnic_all_configure.sh \
    -O /usr/local/sbin/secondary_vnic_all_configure.sh

# Make the script executable
chmod +x /usr/local/sbin/secondary_vnic_all_configure.sh

# Run the script to configure the secondary VNIC
/usr/local/sbin/secondary_vnic_all_configure.sh -c

# Create the systemd service file
cat > /etc/systemd/system/secondary_vnic.service << 'EOF'
[Unit]
Description=Setting the secondary vnic
After=default.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/secondary_vnic_all_configure.sh -c

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to apply changes
systemctl daemon-reload

# Enable the secondary VNIC service to start at boot
systemctl enable secondary_vnic.service

echo "Setup complete. The secondary VNIC service is enabled and will run on boot."
