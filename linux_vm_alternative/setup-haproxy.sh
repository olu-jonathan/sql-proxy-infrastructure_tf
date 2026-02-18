#!/bin/bash
set -e

echo "Starting HAProxy installation and configuration..."

# Update package list
apt-get update

# Install HAProxy and dependencies
DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy net-tools vim curl

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Backup default HAProxy config
if [ -f /etc/haproxy/haproxy.cfg ]; then
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.original
fi

# Write HAProxy configuration
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # Default SSL material locations
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    # Security settings
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

# HAProxy Statistics
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats auth admin:admin
    stats admin if TRUE

#1#############################################################################################
# SERVER1 Frontend
frontend SERVER1_frontend
    bind *:4001
    mode tcp
    default_backend SERVER1_backend
 
# SERVER1 Backend
backend SERVER1_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER1 10.235.4.20:1433 check inter 10s fall 3 rise 2
#2#############################################################################################
# SERVER2 Frontend
frontend SERVER2_frontend
    bind *:4002
    mode tcp
    default_backend SERVER2_backend
 
# SERVER2 Backend
backend SERVER2_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER2 10.1.2.93:54499 check inter 10s fall 3 rise 2
#3#############################################################################################
# SERVER3 Frontend
frontend SERVER3_frontend
    bind *:4003
    mode tcp
    default_backend SERVER3_backend
 
# SERVER3 Backend
backend SERVER3_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER3 10.1.70.25:1433 check inter 10s fall 3 rise 2
#4#############################################################################################
# SERVER4 Frontend
frontend SERVER4_frontend
    bind *:4004
    mode tcp
    default_backend SERVER4_backend
 
# SERVER4 Backend
backend SERVER4_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER4 10.1.70.27:1433 check inter 10s fall 3 rise 2
#5#############################################################################################
# SERVER5 Frontend
frontend SERVER5_frontend
    bind *:4005
    mode tcp
    default_backend SERVER5_backend
 
# SERVER5 Backend
backend SERVER5_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER5 10.1.70.28:1433 check inter 10s fall 3 rise 2
#6#############################################################################################
# SERVER6 Frontend
frontend SERVER6_frontend
    bind *:4006
    mode tcp
    default_backend SERVER6_backend
 
# SERVER6 Backend
backend SERVER6_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER6 10.1.101.117:1007 check inter 10s fall 3 rise 2
#7#############################################################################################
# SERVER7 Frontend
frontend SERVER7_frontend
    bind *:4007
    mode tcp
    default_backend SERVER7_backend
 
# SERVER7 Backend
backend SERVER7_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER7 10.1.101.194:1007 check inter 10s fall 3 rise 2
#8###########################################################################################
# SERVER8 Frontend
frontend SERVER8_frontend
    bind *:4008
    mode tcp
    default_backend SERVER8_backend
 
# SERVER8 Backend
backend SERVER8_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER8 10.247.2.29:1433 check inter 10s fall 3 rise 2
#9###########################################################################################
# SERVER9 Frontend
frontend SERVER9_frontend
    bind *:4009
    mode tcp
    default_backend SERVER9_backend
 
# SERVER9 Backend
backend SERVER9_backend
    mode tcp
    balance roundrobin
    option tcp-check
    server SERVER9 10.1.101.157:1007 check inter 10s fall 3 rise 2
############################################################################################
 
############################################################################################
EOF

# Validate HAProxy configuration
haproxy -c -f /etc/haproxy/haproxy.cfg

# Enable and start HAProxy
systemctl enable haproxy
systemctl restart haproxy

# Wait for HAProxy to start
sleep 3

# Check HAProxy status
systemctl status haproxy

# Configure firewall
ufw --force enable
ufw allow 22/tcp
ufw allow 1433/tcp

#Change the port numbers below to match the ports you configured in HAProxy for your backends.
ufw allow 4001/tcp
ufw allow 4002/tcp
ufw allow 4003/tcp
ufw allow 4004/tcp
ufw allow 4005/tcp
ufw allow 4006/tcp
ufw allow 4007/tcp
ufw allow 4008/tcp
ufw allow 4009/tcp

ufw allow 8404/tcp

echo "HAProxy installation and configuration complete!"
echo "HAProxy is listening on ports 22, 1433 and 4001-4009"
echo "Statistics available at http://<vm-ip>:8404/stats (admin/admin)"
