# Technical-Assessment


# About
Using Docker to encapsulate a tool called Mkdocs
(​http://www.mkdocs.org/​) to produce and serve a website because we don’t want to
install Mkdocs locally.
The idea is to:
● Create a Git project that builds a Docker image. 
● This Docker image, when run, should accept a directory from your local
filesystem as input and use Mkdocs to produce and serve a website.
● This local directory is the root of a valid Mkdocs project with which this tool
can create the site.

Build and serve your existing mkdocs project over http



## Implementing monitoring solution

A monitoring solution for Docker hosts and containers with [Prometheus](https://prometheus.io/), [Grafana](http://grafana.org/), [cAdvisor](https://github.com/google/cadvisor),
[NodeExporter](https://github.com/prometheus/node_exporter) and alerting with [AlertManager](https://github.com/prometheus/alertmanager).

***If you're looking for the Docker Swarm version please go to [stefanprodan/swarmprom](https://github.com/stefanprodan/swarmprom)***




Prerequisites:

* Docker Engine >= 1.13
* Docker Compose >= 1.11

Containers:

* Prometheus (metrics database) `http://<host-ip>:9090`
* Prometheus-Pushgateway (push acceptor for ephemeral and batch jobs) `http://<host-ip>:9091`
* AlertManager (alerts management) `http://<host-ip>:9093`
* Grafana (visualize metrics) `http://<host-ip>:3000`
* NodeExporter (host metrics collector)
* cAdvisor (containers metrics collector)
* Caddy (reverse proxy and basic auth provider for prometheus and alertmanager)

## Setup Grafana

Navigate to `http://<host-ip>:3000` and login with user ***admin*** password ***admin***. You can change the credentials in the compose file or by supplying the `ADMIN_USER` and `ADMIN_PASSWORD` environment variables on compose up. The config file can be added directly in grafana part like this
```
grafana:
  image: grafana/grafana:7.2.0
  env_file:
    - config

```
and the config file format should have this content
```
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=changeme
GF_USERS_ALLOW_SIGN_UP=false
```
If you want to change the password, you have to remove this entry, otherwise the change will not take effect
```
- grafana_data:/var/lib/grafana
```



Prerequisites:

* Docker Engine >= 1.13
* Docker Compose >= 1.11

Containers:

* Prometheus (metrics database) `http://<host-ip>:9090`
* Prometheus-Pushgateway (push acceptor for ephemeral and batch jobs) `http://<host-ip>:9091`
* AlertManager (alerts management) `http://<host-ip>:9093`
* Grafana (visualize metrics) `http://<host-ip>:3000`
* NodeExporter (host metrics collector)
* cAdvisor (containers metrics collector)
* Caddy (reverse proxy and basic auth provider for prometheus and alertmanager)



Grafana is preconfigured with dashboards and Prometheus as the default data source:

* Name: Prometheus
* Type: Prometheus
* Url: http://prometheus:9090
* Access: proxy

***Docker Host Dashboard***

![Host](https://raw.githubusercontent.com/stefanprodan/dockprom/master/screens/Grafana_Docker_Host.png)

The Docker Host Dashboard shows key metrics for monitoring the resource usage of your server:

* Server uptime, CPU idle percent, number of CPU cores, available memory, swap and storage
* System load average graph, running and blocked by IO processes graph, interrupts graph
* CPU usage graph by mode (guest, idle, iowait, irq, nice, softirq, steal, system, user)
* Memory usage graph by distribution (used, free, buffers, cached)
* IO usage graph (read Bps, read Bps and IO time)
* Network usage graph by device (inbound Bps, Outbound Bps)
* Swap usage and activity graphs

For storage and particularly Free Storage graph, you have to specify the fstype in grafana graph request.
You can find it in `grafana/dashboards/docker_host.json`, at line 480 :

      "expr": "sum(node_filesystem_free_bytes{fstype=\"btrfs\"})",

I work on BTRFS, so i need to change `aufs` to `btrfs`.

You can find right value for your system in Prometheus `http://<host-ip>:9090` launching this request :

      node_filesystem_free_bytes

***Docker Containers Dashboard***

![Containers](https://raw.githubusercontent.com/stefanprodan/dockprom/master/screens/Grafana_Docker_Containers.png)

The Docker Containers Dashboard shows key metrics for monitoring running containers:

* Total containers CPU load, memory and storage usage
* Running containers graph, system load graph, IO usage graph
* Container CPU usage graph
* Container memory usage graph
* Container cached memory usage graph
* Container network inbound usage graph
* Container network outbound usage graph

Note that this dashboard doesn't show the containers that are part of the monitoring stack.

***Monitor Services Dashboard***

![Monitor Services](https://raw.githubusercontent.com/stefanprodan/dockprom/master/screens/Grafana_Prometheus.png)

The Monitor Services Dashboard shows key metrics for monitoring the containers that make up the monitoring stack:

* Prometheus container uptime, monitoring stack total memory usage, Prometheus local storage memory chunks and series
* Container CPU usage graph
* Container memory usage graph
* Prometheus chunks to persist and persistence urgency graphs
* Prometheus chunks ops and checkpoint duration graphs
* Prometheus samples ingested rate, target scrapes and scrape duration graphs
* Prometheus HTTP requests graph
* Prometheus alerts graph

## Define alerts

Three alert groups have been setup within the [alert.rules](https://github.com/stefanprodan/dockprom/blob/master/prometheus/alert.rules) configuration file:

* Monitoring services alerts [targets](https://github.com/stefanprodan/dockprom/blob/master/prometheus/alert.rules#L2-L11)
* Docker Host alerts [host](https://github.com/stefanprodan/dockprom/blob/master/prometheus/alert.rules#L13-L40)
* Docker Containers alerts [containers](https://github.com/stefanprodan/dockprom/blob/master/prometheus/alert.rules#L42-L69)

You can modify the alert rules and reload them by making a HTTP POST call to Prometheus:

```
curl -X POST http://admin:admin@<host-ip>:9090/-/reload
```

***Monitoring services alerts***

Trigger an alert if any of the monitoring targets (node-exporter and cAdvisor) are down for more than 30 seconds:

```yaml
- alert: monitor_service_down
    expr: up == 0
    for: 30s
    labels:
      severity: critical
    annotations:
      summary: "Monitor service non-operational"
      description: "Service {{ $labels.instance }} is down."
```

***Docker Host alerts***

Trigger an alert if the Docker host CPU is under high load for more than 30 seconds:

```yaml
- alert: high_cpu_load
    expr: node_load1 > 1.5
    for: 30s
    labels:
      severity: warning
    annotations:
      summary: "Server under high load"
      description: "Docker host is under high load, the avg load 1m is at {{ $value}}. Reported by instance {{ $labels.instance }} of job {{ $labels.job }}."
```

Modify the load threshold based on your CPU cores.

Trigger an alert if the Docker host memory is almost full:

```yaml
- alert: high_memory_load
    expr: (sum(node_memory_MemTotal_bytes) - sum(node_memory_MemFree_bytes + node_memory_Buffers_bytes + node_memory_Cached_bytes) ) / sum(node_memory_MemTotal_bytes) * 100 > 85
    for: 30s
    labels:
      severity: warning
    annotations:
      summary: "Server memory is almost full"
      description: "Docker host memory usage is {{ humanize $value}}%. Reported by instance {{ $labels.instance }} of job {{ $labels.job }}."
```

Trigger an alert if the Docker host storage is almost full:

```yaml
- alert: high_storage_load
    expr: (node_filesystem_size_bytes{fstype="aufs"} - node_filesystem_free_bytes{fstype="aufs"}) / node_filesystem_size_bytes{fstype="aufs"}  * 100 > 85
    for: 30s
    labels:
      severity: warning
    annotations:
      summary: "Server storage is almost full"
      description: "Docker host storage usage is {{ humanize $value}}%. Reported by instance {{ $labels.instance }} of job {{ $labels.job }}."
```

***Docker Containers alerts***

Trigger an alert if a container is down for more than 30 seconds:

```yaml
- alert: jenkins_down
    expr: absent(container_memory_usage_bytes{name="jenkins"})
    for: 30s
    labels:
      severity: critical
    annotations:
      summary: "Jenkins down"
      description: "Jenkins container is down for more than 30 seconds."
```

Trigger an alert if a container is using more than 10% of total CPU cores for more than 30 seconds:

```yaml
- alert: jenkins_high_cpu
    expr: sum(rate(container_cpu_usage_seconds_total{name="jenkins"}[1m])) / count(node_cpu_seconds_total{mode="system"}) * 100 > 10
    for: 30s
    labels:
      severity: warning
    annotations:
      summary: "Jenkins high CPU usage"
      description: "Jenkins CPU usage is {{ humanize $value}}%."
```

Trigger an alert if a container is using more than 1.2GB of RAM for more than 30 seconds:

```yaml
- alert: jenkins_high_memory
    expr: sum(container_memory_usage_bytes{name="jenkins"}) > 1200000000
    for: 30s
    labels:
      severity: warning
    annotations:
      summary: "Jenkins high memory usage"
      description: "Jenkins memory consumption is at {{ humanize $value}}."
```

## Setup alerting

The AlertManager service is responsible for handling alerts sent by Prometheus server.
AlertManager can send notifications via email, Pushover, Slack, HipChat or any other system that exposes a webhook interface.
A complete list of integrations can be found [here](https://prometheus.io/docs/alerting/configuration).

You can view and silence notifications by accessing `http://<host-ip>:9093`.

The notification receivers can be configured in [alertmanager/config.yml](https://github.com/stefanprodan/dockprom/blob/master/alertmanager/config.yml) file.

To receive alerts via Slack you need to make a custom integration by choose ***incoming web hooks*** in your Slack team app page.
You can find more details on setting up Slack integration [here](http://www.robustperception.io/using-slack-with-the-alertmanager/).

Copy the Slack Webhook URL into the ***api_url*** field and specify a Slack ***channel***.

```yaml
route:
    receiver: 'slack'

receivers:
    - name: 'slack'
      slack_configs:
          - send_resolved: true
            text: "{{ .CommonAnnotations.description }}"
            username: 'Prometheus'
            channel: '#<channel>'
            api_url: 'https://hooks.slack.com/services/<webhook-id>'
```

![Slack Notifications](https://raw.githubusercontent.com/stefanprodan/dockprom/master/screens/Slack_Notifications.png)




# nginx docker 

## Reverse proxy advantage
The reverse proxy receives data from the internal server and sends it to the client. This prevents direct access to the internal server and acts as a relay for indirect access. The reverse proxy has many security advantages.


## How to build docker

Build an image from a Dockerfile with following command.
You can use the following command to build an image from a Dockerfile.

```bash
$ make
```
 
## How to run nginx image 

Open docker-compose.yml in a text editor and add the following content:

```yaml
version: '3'
services:
   prep:
      image: 'iconloop/prep-node:1912090356xb1e1fe-dev'
      container_name: prep
      restart: "always"
      environment:
         LOOPCHAIN_LOG_LEVEL: "SPAM"
         ICON_LOG_LEVEL: "DEBUG"
         DEFAULT_PATH: "/data/loopchain"
         LOG_OUTPUT_TYPE: "file"
         PRIVATE_PATH: "/cert/{==YOUR_KEYSTORE or YOUR_CERTKEY FILENAME==}"
         PRIVATE_PASSWORD: "{==YOUR_KEY_PASSWORD==}"
         CERT_PATH: "/cert"
         SERVICE: "zicon"
         FASTEST_START: "yes"
         SWITCH_BH_VERSION4: 1587271
      cap_add:
         - SYS_TIME
      volumes:
         - ./data:/data
         - ./cert:/cert:ro


   nginx_throttle:
      image: 'looploy/nginx:1.17.1-1a'
      container_name: nginx_throttle
      restart: "always"
      environment:
         NGINX_LOG_OUTPUT: 'file'
         NGINX_LOG_TYPE: 'main'
         NGINX_USER: 'root'
         VIEW_CONFIG: "yes"
         USE_NGINX_THROTTLE: "yes"
         NGINX_THROTTLE_BY_IP_VAR: "$$binary_remote_addr"
         NGINX_THROTTLE_BY_URI: "no"
         NGINX_THROTTLE_BY_IP: "yes"
         NGINX_RATE_LIMIT: "700r/s"
         NGINX_BURST: "5"
         NGINX_SET_NODELAY: "no"
         GRPC_PROXY_MODE: "yes"
         USE_VTS_STATUS: "yes"
         TZ: "GMT-9"
         SET_REAL_IP_FROM: "0.0.0.0/0"
         PREP_MODE: "yes"
         NODE_CONTAINER_NAME: "prep"
         PREP_NGINX_ALLOWIP: "no"
         #PREP_NODE_LIST_API: "https://zicon.net.solidwallet/api/v3"
         NGINX_ALLOW_IP: "0.0.0.0/0"
         NGINX_LOG_FORMAT: '$$realip_remote_addr $$remote_addr  $$remote_user [$$time_local] $$request $$status $$body_bytes_sent $$http_referer "$$http_user_agent" $$http_x_forwarded_for $$request_body $$server_protocol $$request_time'
      volumes:
         - ./data/loopchain/nginx:/var/log/nginx
         - ./manual_acl:/etc/nginx/manual_acl
      ports:
         - '7100:7100'
         - '9000:9000'


```

run docker-compose
```yaml
$ docker-compose up -d
```



## nginx docker ENV settings
###### made date at 2019-12-17 13:49:49 
| Environment variable | Description|Default value| Allowed value|
|--------|--------|-------|-------|
 TRACKER\_IPLIST| Required for tracker to monitor prep|15.164.151.101 15.164.183.120 52.79.145.149 54.180.178.129 ||
 ENDPOINT\_IPLIST|18.176.140.116 3.115.235.90 15.164.9.144 52.79.53.18 100.20.198.12 100.21.153.11 3.232.240.113 35.173.107.66 18.162.69.96 18.162.80.224 18.140.251.111 18.141.27.125 58.234.156.141 58.234.156.140 210.180.69.103|18.176.140.116 3.115.235.90 15.164.9.144 52.79.53.18 100.20.198.12 100.21.153.11 3.232.240.113 35.173.107.66 18.162.69.96 18.162.80.224 18.140.251.111 18.141.27.125 58.234.156.141 58.234.156.140 210.180.69.103||
 PREP\_NGINX\_ALLOWIP| `no` :  Set allow come to anyone. `yes`: Set nginx allow ip to whitelist accessible IPs from P|no ||
 PREP\_MODE| PREP\_MODE mode whitelist based nginx usage|no |   (yes/no)|
 NODE\_CONTAINER\_NAME| container name in order to connect to prep|prep ||
 PREP\_LISTEN\_PORT| Choose a prep|9000 ||
 PREP\_PROXY\_PASS\_ENDPOINT| prep's container name for RPC API  (if you selected `PREP\_MODE`, Required input)|http||
 PREP\_NODE\_LIST\_API| In order to get prep's white ip list, ENDPOINT API URL (Required input)|${PREP\_PROXY\_PASS\_ENDPOINT/api/v3 ||
 PREP\_AVAIL\_API|http://localhost:9000/api/v1/status/peer|http||
 CONTAINER\_GW|get container gateway, Required to call loopback|`ip route | grep default | awk '{print $3'` | container's gateway IP|
 USE\_DOCKERIZE| `go template` usage ( yes/no )|yes  ||
 VIEW\_CONFIG| Config print at launch ( yes/no )|no       ||
 UPSTREAM| upstream setting|localhost||
 DOMAIN| domain setting|localhost          ||
 LOCATION|ADD\_LOCATION|| additional location setting|
 WEBROOT| webroot setting|/var/www/public  ||
 NGINX\_EXTRACONF| additional conf settings| ||
 USE\_DEFAULT\_SERVER| nginx's default conf setting|no  ||
 USE\_DEFAULT\_SERVER\_CONF| nginx's default server conf setting| ||
 NGINX\_USER|www|wwwdata  ||
 NGINX\_SET\_NODELAY| Delay option if rate limit is exceeded|no  | ( yes/no )|
 WEB\_SOCKET\_URIS| URI for using nginx as a websocket proxy|/api/ws/* /api/node/* ||
 NUMBER\_PROC| worker processes count|$(nproc)  |  max number of processes|
 WORKER\_CONNECTIONS| setting WORKER\_CONNECTIONS|4096  ||
 GRPC\_LISTEN\_PORT| Used by gRPC Listen port|7100 ||
 LISTEN\_PORT|${GRPC\_LISTEN\_PORT}|${GRPC\_LISTEN\_PORT||
 SENDFILE|on|on||
 SERVER\_TOKENS|off|off||
 KEEPALIVE\_TIMEOUT|65|65||
 KEEPALIVE\_REQUESTS|15|15||
 TCP\_NODELAY|on|on||
 TCP\_NOPUSH|on|on||
 CLIENT\_BODY\_BUFFER\_SIZE|3m|3m||
 CLIENT\_HEADER\_BUFFER\_SIZE|16k|16k||
 CLIENT\_MAX\_BODY\_SIZE|100m|100m||
 FASTCGI\_BUFFER\_SIZE|256K|256K||
 FASTCGI\_BUFFERS|8192 4k|8192 4k||
 FASTCGI\_READ\_TIMEOUT|60|60||
 FASTCGI\_SEND\_TIMEOUT|60|60||
 TYPES\_HASH\_MAX\_SIZE|2048|2048||
 NGINX\_LOG\_TYPE| output log format type|default  |  (json/default)|
 NGINX\_LOG\_FORMAT|  '$realip\_remote\_addr $remote\_addr|   ||
 NGINX\_LOG\_OUTPUT| output log type|file | stdout or file  or off|
 NGINX\_LOG\_OPTION| for json logging option|escape=none | escape=json, escape=none|
 USE\_VTS\_STATUS| vts monitoring usage|yes   | (yes/no)|
 USE\_NGINX\_STATUS| nginx status monitoring usage|yes |(yes/no)|
 NGINX\_STATUS\_URI| nginx\_status URI|nginx\_status ||
 NGINX\_STATUS\_URI\_ALLOWIP| nginx\_status URI is only allow requests from this IP address|127.0.0.1 ||
 USE\_PHP\_STATUS|no|no||
 PHP\_STATUS\_URI|php\_status|php\_status||
 PHP\_STATUS\_URI\_ALLOWIP|127.0.0.1|127.0.0.1||
 PRIORTY\_RULE|allow|allow||
 NGINX\_ALLOW\_IP| Administrator IP addr for detail monitoring|    ||
 NGINX\_DENY\_IP||||
 NGINX\_LOG\_OFF\_URI||||
 NGINX\_LOG\_OFF\_STATUS||||
 DEFAULT\_EXT\_LOCATION| extension setting  ~/.jsp ~/.php|php  ||
 PROXY\_MODE| gRPC proxy mode usage|no   | (yes/no)|
 GRPC\_PROXY\_MODE| gRPC proxy mode usage|no | (yes/no)|
 USE\_NGINX\_THROTTLE| rate limit usage|no |  (yes/no)|
 NGINX\_THROTTLE\_BY\_URI| URI based rate limit usage (yes/no)|no ||
 NGINX\_THROTTLE\_BY\_IP| IP based rate limit usage (yes/no)|no  ||
 NGINX\_THROTTLE\_BY\_IP\_VAR| IP variable to be used for rate limit|'$http\_true\_client\_ip' ||
 PROXY\_PASS\_ENDPOINT| proxy endporint of gRPC|grpc||
 NGINX\_ZONE\_MEMORY| Sets the shared memory zone for `rate limit`|10m    ||
 NGINX\_RATE\_LIMIT| rate limiting value|100r/s   ||
 NGINX\_BURST|Excessive requests are delayed until their number exceeds the maximum burst size,  maximum queue value ( If the value is `10`, apply from `11`)|10                 ||
 SET\_REAL\_IP\_FROM| SET\_REAL\_IP\_FROM|0.0.0.0/0   ||
 NGINX\_PROXY\_TIMEOUT|90|90||



# Docker Bench for Security

![Docker Bench for Security running](https://raw.githubusercontent.com/docker/docker-bench-security/master/benchmark_log.png)

## Running Docker Bench for Security

We packaged docker bench as a small container for your convenience. Note that
this container is being run with a *lot* of privilege -- sharing the host's
filesystem, pid and network namespaces, due to portions of the benchmark
applying to the running host.

The easiest way to run your hosts against the Docker Bench for Security is by
running our pre-built container:

```sh
docker run --rm --net host --pid host --userns host --cap-add audit_control \
    -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
    -v /etc:/etc:ro \
    -v /usr/bin/containerd:/usr/bin/containerd:ro \
    -v /usr/bin/runc:/usr/bin/runc:ro \
    -v /usr/lib/systemd:/usr/lib/systemd:ro \
    -v /var/lib:/var/lib:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    --label docker_bench_security \
    docker/docker-bench-security


## Building Docker Bench for Security

If you wish to build and run this container yourself, you can follow the
following steps:

```sh
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
docker build --no-cache -t docker-bench-security .
```

followed by an appropriate `docker run` command as stated above
or use [Docker Compose](https://docs.docker.com/compose/):

```sh
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
docker-compose run --rm docker-bench-security
```

Also, this script can also be simply run from your base host by running:

```sh
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
sudo sh docker-bench-security.sh
```

