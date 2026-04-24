#!/usr/bin/python3
# Ensure the Shebang above is the absolute first line with no leading spaces.

import psycopg2
import sys
import socket
import syslog

# Database connection parameters
# In a production environment, use environment variables for passwords.
conn_params = {
    "host": "10.0.3.3",
    "database": "healthconnect_db",
    "user": "hc_admin",
    "password": "SecurePassword123"
}

# Get the local hostname of the VM serving this specific request
vm_hostname = socket.gethostname()

try:
    # Attempting to connect to the PostgreSQL backend
    conn = psycopg2.connect(**conn_params)
    cur = conn.cursor()
    cur.execute("SELECT name, status, last_visit FROM patients;")
    rows = cur.fetchall()

    # Standard CGI Header: Content-Type must be followed by a blank line
    print("Content-Type: text/html")
    print()

    # HTML Body Output
    print("<html>")
    print("<head><title>HealthConnect Live Data</title></head>")
    print("<body>")
    print("<h1>HealthConnect Secure Portal</h1>")
    
    # Identify which web server handled the request for Load Balancer verification
    print(f"<p style='color:blue;'><b>Backend Instance:</b> {vm_hostname}</p>")
    print("<hr>")
    
    print("<h2>Patient Data (Live Database Feed)</h2>")
    print("<ul>")
    for row in rows:
        # Displaying data retrieved from the hc-db-vm
        print(f"<li><b>Patient:</b> {row[0]} | <b>Status:</b> {row[1]}</li>")
    print("</ul>")
    print("<p style='color:green;'><b>✔ Backend Connected:</b> System operational.</p>")
    print("</body></html>")

    cur.close()
    conn.close()

except Exception as e:
    # LOGGING CRITICAL: Write error to stderr so Google Cloud Logging captures it
    # We use a unique prefix "DB_ERROR:" to make searching in Logs Explorer easier
    syslog.syslog(syslog.LOG_ERR, f"DB_ERROR: Connection Failed - {str(e)}")

    # Display error to the web browser
    print("Content-Type: text/html")
    print()
    print("<html><body>")
    print("<h2>HealthConnect System Error</h2>")
    
    # Even in an error state, identify which node is reporting the failure
    print(f"<p style='color:blue;'><b>Reporting Instance:</b> {vm_hostname}</p>")
    
    print("<p style='color:red;'><b>✘ Connection Failed:</b> Unable to reach database.</p>")
    print(f"<pre>Error Details: {e}</pre>")
    print("</body></html>")
