#!/bin/bash

echo "========================================="
echo "SSL Certificate Diagnostic Tool"
echo "========================================="
echo ""

# 1. Check Apache configuration files
echo "1. Checking Apache configuration files..."
echo ""

if [ -d "/etc/apache2/sites-enabled" ]; then
    echo "Files in /etc/apache2/sites-enabled:"
    ls -la /etc/apache2/sites-enabled/
    echo ""
fi

if [ -d "/etc/httpd/conf.d" ]; then
    echo "Files in /etc/httpd/conf.d:"
    ls -la /etc/httpd/conf.d/
    echo ""
fi

# 2. Search for SSL certificate directives in all conf files
echo "2. Searching for SSL certificate directives..."
echo ""

for conf in /etc/apache2/sites-enabled/*.conf /etc/apache2/sites-available/*.conf /etc/httpd/conf.d/*.conf 2>/dev/null; do
    if [[ -f "$conf" ]]; then
        echo "--- Checking: $conf ---"
        grep -i "SSLCertificateFile\|SSLCertificateKeyFile" "$conf" 2>/dev/null || echo "No SSL directives found"
        echo ""
    fi
done

# 3. Search for certificate files in common locations
echo "3. Searching for certificate files in common locations..."
echo ""

SEARCH_PATHS=(
    "/etc/ssl/certs"
    "/etc/ssl/private"
    "/etc/apache2/ssl"
    "/etc/httpd/ssl"
    "/usr/local/ssl"
    "$HOME"
    "/root"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo "Checking $path:"
        find "$path" -maxdepth 2 -type f \( -name "*.crt" -o -name "*.pem" -o -name "*.key" \) 2>/dev/null | head -10
        echo ""
    fi
done

# 4. Check if there are any .crt or .key files created recently
echo "4. Recently created certificate files (last 7 days):"
echo ""
find /etc /home /root -type f \( -name "*.crt" -o -name "*.key" -o -name "*.pem" \) -mtime -7 2>/dev/null | head -20

echo ""
echo "5. Apache SSL module status:"
if command -v apache2ctl &> /dev/null; then
    apache2ctl -M 2>/dev/null | grep ssl
elif command -v apachectl &> /dev/null; then
    apachectl -M 2>/dev/null | grep ssl
fi

echo ""
echo "========================================="
echo "Diagnostic complete!"
echo "========================================="
