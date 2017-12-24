# Freemius Server Monitoring with Email Alerts

This script monitors a linux server CPU(s), RAM, and Disk(s), and when the utilization of each metric reaches some limit 
it automatically sends an incident alert to a desired email address. Once the metric value goes down below the limit, the
incident will be closed and another alert will be sent to the address letting the sys-admin knowing that the incident is over.

The script supports multiple levels of limits so you can have a "warning" and "critical" alerts.

## Usage
Check your server's current info:

`bash server-monitoring.sh --info=true`

One time execution with debug mode:

`bash server-monitoring.sh --debug=true --from=server@yourdomain.com --to=admin@yourdomain.com --cpu=warning=20:critical=50 --memory=warning=30:critical=60 --disk=warning=40:critical=60:fatal=70`

### Explanation
- When the server's avg. CPU(s) consumption will increase above 20%, a `warning` CPU incident will be opened. If the CPU consumption will increase beyond 50%, a `critical` CPU incident will be opened.
- When the server's memory/RAM consumption will increase above 30%, a `warning` memory incident will be opened. If the RAM consumption will increase beyond 60%, a `critical` memory incident will be opened.
- When any mounted disk usage will increase above 40%, a `warning` disk incident will be opened. If a disk usage will increase beyond 60%, a `critical` disk incident will be opened. And if more than 70% of a disk will be utilized, it will trigger a `fatal` incident.

To set an ongoing monitoring:
1. Open the crontab file: `crontab -e`
2. Add the following line to the end of the file:

   `*/2 * * * * bash /server-monitoring/server-monitoring.sh --from=server@freemius.com --to=admin@freemius.com --cpu=warning=20:critical=50 --memory=warning=30:critical=60 --disk=warning=40:critical=60:fatal=70`
3. Type `:x` to save and exit.
