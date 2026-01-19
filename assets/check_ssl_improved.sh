#!/bin/bash

# Output file
REPORT="report.json"
report=()

# Helper to append formatted key-value pairs
add_report() {
    key="$1"
    value="$2"
    report+=("\"$key\": \"$value\"")
}

# 1. Check if Apache is running
if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
    add_report "Apache Service" "✅ Apache is running."
else
    add_report "Apache Service" "❌ Apache is NOT running. Please start it with: sudo systemctl start apache2"
fi

# 2. Detect Apache control command (apache2ctl, apachectl, or absolute path)
if command -v apache2ctl &> /dev/null; then
    APACHE_CMD="apache2ctl"
elif command -v apachectl &> /dev/null; then
    APACHE_CMD="apachectl"
elif [[ -x /usr/sbin/apache2ctl ]]; then
    APACHE_CMD="/usr/sbin/apache2ctl"
elif [[ -x /usr/sbin/apachectl ]]; then
    APACHE_CMD="/usr/sbin/apachectl"
else
    APACHE_CMD=""
fi

# 3. Check if SSL module is enabled
if [[ -n "$APACHE_CMD" ]]; then
    MODULES=$($APACHE_CMD -M 2>/dev/null)
    if echo "$MODULES" | grep -q ssl_module; then
        add_report "SSL Module" "✅ The SSL module is enabled."
    else
        add_report "SSL Module" "❌ The SSL module is NOT enabled. Enable it with: sudo a2enmod ssl && sudo systemctl restart apache2"
    fi
else
    add_report "SSL Module" "⚠️ Apache control command not found. Make sure Apache is installed."
fi

# 4. Find certificate and key in Apache site configurations
CRT_PATH=""
KEY_PATH=""

# Search in both sites-enabled and sites-available
for conf in /etc/apache2/sites-enabled/*.conf /etc/apache2/sites-available/*.conf /etc/httpd/conf.d/*.conf; do
    [[ -f "$conf" ]] || continue
    crt=$(awk 'tolower($1)=="sslcertificatefile"{print $2; exit}' "$conf")
    key=$(awk 'tolower($1)=="sslcertificatekeyfile"{print $2; exit}' "$conf")
    
    # If paths are found in config, check if files exist
    if [[ -n "$crt" && -n "$key" ]]; then
        if [[ -f "$crt" && -f "$key" ]]; then
            CRT_PATH="$crt"
            KEY_PATH="$key"
            break
        fi
    fi
done

# If not found in configs, search common locations
if [[ -z "$CRT_PATH" || -z "$KEY_PATH" ]]; then
    # Common certificate locations
    COMMON_CERT_LOCATIONS=(
        "/etc/ssl/certs"
        "/etc/apache2/ssl"
        "/etc/httpd/ssl"
        "$HOME"
    )
    
    for location in "${COMMON_CERT_LOCATIONS[@]}"; do
        if [[ -d "$location" ]]; then
            # Look for .crt files
            if [[ -z "$CRT_PATH" ]]; then
                found_crt=$(find "$location" -maxdepth 2 -name "*.crt" -o -name "*cert.pem" 2>/dev/null | head -1)
                if [[ -n "$found_crt" && -f "$found_crt" ]]; then
                    CRT_PATH="$found_crt"
                fi
            fi
            
            # Look for .key files
            if [[ -z "$KEY_PATH" ]]; then
                found_key=$(find "$location" -maxdepth 2 -name "*.key" -o -name "*key.pem" 2>/dev/null | head -1)
                if [[ -n "$found_key" && -f "$found_key" ]]; then
                    KEY_PATH="$found_key"
                fi
            fi
        fi
    done
fi

# 5. Report certificate and key file presence
if [[ -n "$CRT_PATH" ]]; then
    add_report "Certificate File" "✅ Found certificate at $CRT_PATH"
else
    add_report "Certificate File" "❌ No certificate file found. Check your Apache SSL configuration."
fi

if [[ -n "$KEY_PATH" ]]; then
    add_report "Key File" "✅ Found private key at $KEY_PATH"
else
    add_report "Key File" "❌ No private key file found. Check your Apache SSL configuration."
fi

# 6. Validate certificate content
if [[ -n "$CRT_PATH" && -f "$CRT_PATH" ]]; then
    # Check if it's a valid certificate file
    if openssl x509 -in "$CRT_PATH" -noout -text &>/dev/null; then
        CN=$(openssl x509 -in "$CRT_PATH" -noout -subject | sed -n 's/.*CN *= *//p')
        EXPIRE_DATE=$(openssl x509 -in "$CRT_PATH" -noout -enddate | cut -d= -f2)
        EXPIRE_SECONDS=$(date --date="$EXPIRE_DATE" +%s 2>/dev/null || echo "0")
        NOW_SECONDS=$(date +%s)
        
        if [[ "$EXPIRE_SECONDS" != "0" ]]; then
            DAYS_LEFT=$(( (EXPIRE_SECONDS - NOW_SECONDS) / 86400 ))
            
            if [[ $DAYS_LEFT -gt 0 ]]; then
                add_report "Certificate Validity" "✅ Valid certificate. Common Name (CN): $CN"
                add_report "Days Until Expiry" "✅ The certificate will expire in $DAYS_LEFT days."
            else
                add_report "Certificate Validity" "❌ The certificate has expired. Please generate a new one."
            fi
        else
            add_report "Certificate Validity" "⚠️ Could not parse expiration date."
        fi
    else
        add_report "Certificate Validity" "❌ File exists but is not a valid X.509 certificate."
    fi
else
    add_report "Certificate Validity" "❌ Cannot validate the certificate. File not found or invalid format."
fi

# 7. Check if certificate and key match (if both exist)
if [[ -n "$CRT_PATH" && -f "$CRT_PATH" && -n "$KEY_PATH" && -f "$KEY_PATH" ]]; then
    CRT_MODULUS=$(openssl x509 -noout -modulus -in "$CRT_PATH" 2>/dev/null | openssl md5)
    KEY_MODULUS=$(openssl rsa -noout -modulus -in "$KEY_PATH" 2>/dev/null | openssl md5)
    
    if [[ "$CRT_MODULUS" == "$KEY_MODULUS" && -n "$CRT_MODULUS" ]]; then
        add_report "Certificate-Key Match" "✅ Certificate and private key match."
    else
        add_report "Certificate-Key Match" "❌ Certificate and private key do NOT match!"
    fi
fi

# 8. Output report.json with proper JSON formatting
{
    echo "{"
    for i in "${!report[@]}"; do
        echo -n "  ${report[$i]}"
        if [[ $i -lt $((${#report[@]} - 1)) ]]; then
            echo ","
        else
            echo ""
        fi
    done
    echo "}"
} > "$REPORT"

echo "✅ Validation complete. Check the report: $REPORT"
