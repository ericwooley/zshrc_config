#!/bin/bash
set -e

# Terminate any existing manual VNC sessions on port 1
vncserver -kill :1 2>/dev/null || true
tightvncserver -kill :1 2>/dev/null || true
pkill -u "${USER}" -f 'Xvnc.*:1|Xtigervnc.*:1' 2>/dev/null || true

# Stop common stale VNC units so this script owns display :1.
sudo systemctl disable --now \
  vncserver@:1.service \
  vncserver@1.service \
  tigervncserver@:1.service \
  tigervncserver@1.service \
  x0vncserver.service \
  2>/dev/null || true

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
ExecStart=/usr/bin/vncserver -localhost yes -SecurityTypes None -BlacklistTimeout 0 -BlacklistThreshold 100000 :1
ExecStop=/usr/bin/vncserver -kill :1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Apply systemd configurations and launch
sudo systemctl daemon-reload
sudo systemctl restart vncserver 2>/dev/null || true
sudo systemctl enable --now vncserver

# Verify the service state
sudo systemctl status vncserver --no-pager
ss -ltnp | grep -E '(:5901|:5900)' || true

cat << 'EOF'

TigerVNC is configured as localhost-only with no VNC password auth.
Connect through an SSH tunnel from your local machine:

  ssh -L 5901:localhost:5901 <host>

Then point TigerVNC Viewer at:

  localhost:5901

Do not connect directly to <host>:5901; the service intentionally listens only
on the remote loopback interface.
EOF
