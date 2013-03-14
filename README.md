[![Build Status](https://travis-ci.org/cloudfoundry/vmc-plugins.png)](https://travis-ci.org/cloudfoundry/vmc-plugins)

## Plugins Included

* [Admin](#admin)
* [Console](#console)
* [Manifests](#manifests)
* [Micro Cloud Foundry](#micro-cloud-foundry)
* [Tunnel](#tunnel)

## Admin
### Info
This plugin allows you to make manual HTTP requests to the Cloud Foundry REST API.

### Installation
```
gem install appfog-admin-vmc-plugin
```

### Usage

```
curl MODE PATH HEADERS...                       Execute a raw request
service-auth-tokens                           	List service auth tokens
create-service-auth-token [LABEL] [PROVIDER]  	Create a service auth token
update-service-auth-token [SERVICE_AUTH_TOKEN]	Update a service auth token
delete-service-auth-token [SERVICE_AUTH_TOKEN]	Delete a service auth token
```

## Console
### Info
This plugin lets you connect to a Cloud Foundry application via telnet.

### Installation
```
gem install appfog-console-vmc-plugin
```

### Usage
```
console APP          Open a console connected to your app
```

## Manifests
### Info
With this plugin enabled, any configuration changes you make using the VMC `start`, `restart`, `instances`, `logs`, `env`, `health`, `stats`, `scale`, and `app` commands will be saved to a file called *manifest.yml*.

### Installation
```
gem install manifests-vmc-plugin
```

## Micro Cloud Foundry
### Info
This plugin allows you to manage your Micro Cloud Foundry VM.

### Installation
```
gem install mcf-vmc-plugin
```

### Usage
```
micro-status VMX [PASSWORD]   Display Micro Cloud Foundry VM status
micro-offline VMX [PASSWORD]	Micro Cloud Foundry offline mode
micro-online VMX [PASSWORD] 	Micro Cloud Foundry online mode
```

## Tunnel
### Info
This plugin allows you to connect to a Cloud Foundry service using your own command line client. By default, the plugin supports *redis*, *mysql*, *mongodb*, and *postgresql*.

### Installation
```
gem install appfog-tunnel-vmc-plugin
```

### Usage
```
tunnel [INSTANCE] [CLIENT]        Create a local tunnel to a service.
```

You can add support for other command-line clients by providing a `~/.vmc/clients.yml` file with the following format:

```yaml
service_name:
  client_program_name: command line arguments
  client_program_name_2:
    command: command line arguments
    environment:
      - ENV_VAR_NAME=env_var_value
```

## File a Bug

To file a bug against Cloud Foundry Open Source and its components, sign up and use our bug tracking system: [http://cloudfoundry.atlassian.net](http://cloudfoundry.atlassian.net)
