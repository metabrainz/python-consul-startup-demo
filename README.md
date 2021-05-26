# MetaBrainz consul startup example

An example of a python image based on metabrainz' consul base image. This is based on the
phusion base image.

Configuration is performed by consul. The base images have a copy of `consul-template` allowing
them to connect to consul and render config files.

The general overview of the application startup process is as follows:
1. install services into /etc/services
2. rc.local enables a service based on environment variables set at startup
3. the service starts, running consul-template with a configuration specific to this service
4. consul-template renders the config file
5. once the config file is successfully rendered, consul-template starts the service as a child process
6. the child process is managed by consul-template (if a setting changes) or by runit (if it quits)

### Installation of service files

* `./docker/services/[servicename]/[servicename].service` -> `/etc/service/[servicename]/run`
* `./docker/services/[servicename]/[servicename].finish` -> `/etc/service/[servicename]/finish`
* `./docker/services/[servicename]/consul-template-[servicename].conf` -> `/etc/consul-template-[servicename].conf`

`run` and `finish` should have the `+x` permission set.

The `consul-template-[servicename].conf` file identifies the source consul template file and target file.
The file has an `exec` block which is called after the template(s) files are rendered.

### Enabling services

In Python MetaBrainz apps, we use a single image for all services. This is in order to make it easier
to build and deploy images. This means that if we need to run 6 services, we create 6 directories in 
`/etc/service`, all with a `down` file in it, disabling the service.

The `/etc/rc.local` file is run before runit is loaded. We use this to remove a `down` file for 
a given service, based on environment variables

#### Cron

consul-template will restart the child process defined in the `exec` block if a config value changes.
For this reason, we don't want to run cron as a child process, as it could get restarted while it's
running an important task.

Because of this, we start up 2 cron services. `/etc/service/cron` is present in the base image, 
this starts the cron daemon.
`/etc/service/cron-config` is a service which starts consul-template to render any necessary config
files. It has no `exec` block. There is a small risk that 

### Reporting when configuration isn't complete

By default, the `{{ key }}` template in consul-template blocks if the key doesn't exist in the consul
server. Consul-template outputs nothing when this is happening.

In order to quickly identify when this is the case, we instead use `{{ keyOrDefault }}` which
allows us to output a sentinel value if the key doesn't exist. 
The `run-lb-command` checks if a config file contains this known sentinel and if so exits with
a known status code.

### Reporting when applications quit

If we want to report when an application has failed to start or been restarted, we use runit's `finish`
script. This is called when `run` exits, and takes the exit status of `run` as its first argument.
We use this to output some logging and optionally report a message to sentry.

### Debugging

On startup, you will probably see the following output.
```
web_1               | 2021/05/26 08:40:31 [DEBUG] (logging) enabling syslog on LOCAL0
web_1               | Consul Template returned errors:
web_1               | error setting up syslog logger: Unix syslog delivery error
web_1               | May 26 08:40:31 1efb0ac8ea33 syslog-ng[23]: syslog-ng starting up; version='3.5.6'
web_1               | 2021/05/26 08:40:41 [DEBUG] (logging) enabling syslog on LOCAL0
```

The first 3 lines are from consul-template. It's saying that it started up but couldn't connect
to syslog, so it exited. `syslog-ng starting up` shows syslog starting up, and then the last line
is consul-template starting up and connecting to syslog. It should be silent after this.