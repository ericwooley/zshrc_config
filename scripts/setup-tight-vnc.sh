#!/bin/bash
set -e

# Terminate any existing manual VNC sessions on port 1
vncserver -kill :1 2>/dev/null || true
tightvncserver -kill :1 2>/dev/null || true

# Remove legacy/conflicting packages
sudo apt purge -y tightvncserver tightvncpasswd

# Install XFCE, TigerVNC, and required D-Bus utilities for session rendering
sudo apt update
sudo apt install -y xfce4 xfce4-goodies tigervnc-standalone-server dbus-x11

# Configure XFCE startup for the current user
mkdir -p ~/.vnc
cat << 'EOF' > ~/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup

# Configure the systemd service dynamically for the executing user
sudo tee /etc/systemd/system/vncserver.service > /dev/null << EOF
[Unit]
Description=TigerVNC Persistent Server
After=network.target

[Service]
Type=forking
User=${USER}
WorkingDirectory=${HOME}
ExecStartPre=-/usr/bin/vncserver -kill :1
ExecStart=/usr/bin/vncserver -localhost yes -SecurityTypes None :1
ExecStop=/usr/bin/vncserver -kill :1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Apply systemd configurations and launch
sudo systemctl daemon-reload
sudo systemctl enable --now vncserver

# Verify the service state
sudo systemctl status vncserver --no-pager
