#!/bin/bash

echo "========================================="
echo "Checking your Apache SSL configuration"
echo "========================================="
echo ""

# Check default-ssl.conf
echo "1. Content of default-ssl.conf (SSL certificate lines only):"
echo ""
if [ -f "/etc/apache2/sites-available/default-ssl.conf" ]; then
    grep -n "SSLCertificate" /etc/apache2/sites-available/default-ssl.conf
    echo ""
    
    # Extract the paths
    CERT_PATH=$(grep "SSLCertificateFile" /etc/apache2/sites-available/default-ssl.conf | grep -v "^#" | awk '{print $2}' | head -1)
    KEY_PATH=$(grep "SSLCertificateKeyFile" /etc/apache2/sites-available/default-ssl.conf | grep -v "^#" | awk '{print $2}' | head -1)
    
    echo "Certificate path in config: $CERT_PATH"
    echo "Key path in config: $KEY_PATH"
    echo ""
    
    # Check if those files exist
    echo "2. Do these files exist?"
    if [ -n "$CERT_PATH" ]; then
        if [ -f "$CERT_PATH" ]; then
            echo "✅ Certificate file exists: $CERT_PATH"
            ls -lh "$CERT_PATH"
        else
            echo "❌ Certificate file NOT found: $CERT_PATH"
        fi
    else
        echo "⚠️  No SSLCertificateFile directive found (or it's commented out)"
    fi
    echo ""
    
    if [ -n "$KEY_PATH" ]; then
        if [ -f "$KEY_PATH" ]; then
            echo "✅ Key file exists: $KEY_PATH"
            ls -lh "$KEY_PATH"
        else
            echo "❌ Key file NOT found: $KEY_PATH"
        fi
    else
        echo "⚠️  No SSLCertificateKeyFile directive found (or it's commented out)"
    fi
else
    echo "❌ File /etc/apache2/sites-available/default-ssl.conf NOT found!"
fi

echo ""
echo "3. Where are your certificate files actually located?"
echo ""
echo "Searching common locations..."

# Search for .crt files
echo "Certificate files (.crt):"
find /etc/ssl /home /root -name "*.crt" 2>/dev/null | head -10
echo ""

# Search for .key files
echo "Private key files (.key):"
find /etc/ssl /home /root -name "*.key" 2>/dev/null | head -10
echo ""

echo "========================================="
echo "NEXT STEPS:"
echo "========================================="
echo "If the files exist but are in different locations,"
echo "you need to update /etc/apache2/sites-available/default-ssl.conf"
echo ""
echo "Edit the file with:"
echo "  sudo nano /etc/apache2/sites-available/default-ssl.conf"
echo ""
echo "And update these lines:"
echo "  SSLCertificateFile /path/to/your/certificate.crt"
echo "  SSLCertificateKeyFile /path/to/your/private.key"
echo ""
echo "Then restart Apache:"
echo "  sudo systemctl restart apache2"
echo "========================================="
