#!/bin/bash

echo "========================================="
echo "Apache SSL Configuration Check"
echo "========================================="
echo ""

# 1. List enabled sites
echo "1. Apache enabled sites:"
ls -la /etc/apache2/sites-enabled/
echo ""

# 2. Check default-ssl configuration
echo "2. Checking default-ssl.conf:"
if [ -f "/etc/apache2/sites-available/default-ssl.conf" ]; then
    echo "File exists: /etc/apache2/sites-available/default-ssl.conf"
    echo ""
    echo "SSL Certificate directives:"
    grep -E "SSLCertificateFile|SSLCertificateKeyFile" /etc/apache2/sites-available/default-ssl.conf
    echo ""
else
    echo "default-ssl.conf NOT found!"
    echo ""
fi

# 3. Check if default-ssl is enabled
echo "3. Is default-ssl enabled?"
if [ -L "/etc/apache2/sites-enabled/default-ssl.conf" ]; then
    echo "✅ YES - default-ssl is enabled"
else
    echo "❌ NO - default-ssl is NOT enabled"
    echo "   Enable it with: sudo a2ensite default-ssl"
fi
echo ""

# 4. Search for certificate files
echo "4. Searching for certificate files..."
echo ""

echo "In /etc/ssl/certs/:"
ls -lh /etc/ssl/certs/*.crt /etc/ssl/certs/*.pem 2>/dev/null | grep -v "^d" || echo "No .crt or .pem files found"
echo ""

echo "In /etc/ssl/private/:"
ls -lh /etc/ssl/private/*.key 2>/dev/null || echo "No .key files found"
echo ""

echo "In current directory:"
ls -lh *.crt *.key *.pem 2>/dev/null || echo "No certificate files in current directory"
echo ""

# 5. Check Apache modules
echo "5. SSL module status:"
apache2ctl -M 2>/dev/null | grep ssl || echo "SSL module not loaded"
echo ""

# 6. Show recent .crt and .key files
echo "6. Recently created certificate files (last 7 days):"
find /etc /home -name "*.crt" -o -name "*.key" 2>/dev/null | xargs ls -lt 2>/dev/null | head -10
echo ""

echo "========================================="
echo "To view a specific config file, run:"
echo "cat /etc/apache2/sites-available/default-ssl.conf"
echo "========================================="
