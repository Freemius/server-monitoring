# Freemius Server Resources Monitoring (with Email Alerts)

This bash script is used for [Freemius](https://freemius.com)' servers monitoring. It monitors a Linux server CPU(s), RAM, and Disk(s) usage. When a resource reaches a specified threshold, it will automatically send an incident alert to the desired email address. Once the resource consumption is reduced back under the threshold, the incident will be closed, and an additional alert will be sent to the same address, letting the sys-admin knowing that the incident has ended.

The script supports unlimited levels of severity limits. For example, you can have a `warning` severity limit as well as `critical` alerts.

## System Requirements
This bash script was created for CentOS 6.X. It should also be compatible with RHEL and Amazon Linux. And thanks to [@gnanet](https://github.com/Freemius/server-monitoring/pull/2), it should work with Debian based systems and Ubuntu.

## Motivation
We've been using [NewRelic](https://newrelic.com) for years and love the product. Recently, they made changes to their plans and the cheapest plan that supports email alerts, which was one of the main features we've been using, starts at $300 per month. Paying $3,600 per year for email alerts doesn't make sense for us, so we decided to build this script for our internal use. Later, we decided to contribute it to the open-source community - saving others these several days of development. Enjoy!

## Usage
`bash server-monitoring.sh [options]`

|          Argument | Description                                                                |          |
|------------------:|----------------------------------------------------------------------------|----------|
|   `--debug`, `-d` | If set to `true` will echo the progress.                                   | Optional |
|    `--info`, `-i` | If set to `true` will output the server's CPU, RAM, and disks consumption. | Optional |
| `--hostname`,`-h` | The hostname that will be used in the email alerts.                        | Optional |
|     `--from`,`-f` | The email address incident alerts will be sent from.                       | Required |
|      `--to`, `-t` | The email address incident alerts will be sent to.                         | Required |
|     `--cpu`, `-c` | The avg. CPU consumption incident severity limits.                         | Required |
|  `--memory`, `-m` | The RAM consumption incident severity limits.                              | Required |
|    `--disk`, `-d` | The disk(s) consumption incident severity limits.                          | Required |

### Example
`bash server-monitoring.sh --debug=true --hostname=myAwesomeServer --from=server@yourdomain.com --to=admin@yourdomain.com --cpu=warning=20:critical=50 --memory=warning=30:critical=60 --disk=warning=40:critical=60:fatal=70`

### Instructions
1. Select an email address that will be the source for the server incident alerts. Something like `server@yourdomain.com`.
2. The script is using `sendmail`'s most basic functionality. 99% of those emails will go directly to your spam. Thus, whitelist all messages from the selected address.
3. Copy the script to your server. Since the script is going to generate files for open incidents, we recommend to create a new folder named `server-monitoring` and to copy the script into that folder.
4. To choose your resource consumption limits, first, execute the script in an `info` mode to learn your current server's resource consumption:

    `bash server-monitoring.sh --info=true`

    The output of the script will look like this:
    ```
    CPU:
    14
    MEMORY:
    26
    DISK:
    /dev/xvda
    34
    /dev/xvda1
    12
    ```
    The numbers represent the current resource consumption in percentages. For example, 34% of the disk `/dev/xvda` is used.
    
    If you're getting a `Command Not Found` error(s), try executing `dos2unix server-monitoring.sh` to convert the line endings to a Unix format.
5. After you know your resources normal state usage, assign the limits that you'd like to be alerted about.

`bash server-monitoring.sh --debug=true --from=server@yourdomain.com --to=admin@yourdomain.com --cpu=warning=20:critical=50 --memory=warning=30:critical=60 --disk=warning=40:critical=60:fatal=70`

### Explanation
- When the server's avg. CPU(s) consumption will increase above 20%; a `warning` CPU incident will be registered. If the CPU consumption increases beyond 50%, a `critical` CPU incident will be registered.
- When the server's memory/RAM consumption increases above 30%, a `warning` memory incident will be registered. If the RAM consumption increases beyond 60%, a `critical` memory incident will be registered.
- When any mounted disk usage increases above 40%, a `warning` disk incident will be registered. If disk usage increases above the 60% threshold, a `critical` disk incident is registered. Finally, when more than 70% of a disk is utilized, it will trigger a `fatal` incident.

## Ongoing Monitoring with a Cron Job
To set an ongoing monitoring:
1. Open the crontab file: `crontab -e`
2. Add the following line to the end of the file:

   `*/2 * * * * bash /server-monitoring/server-monitoring.sh --from=server@freemius.com --to=admin@freemius.com --cpu=warning=20:critical=50 --memory=warning=30:critical=60 --disk=warning=40:critical=60:fatal=70`
3. Type `:x` to save and exit.
