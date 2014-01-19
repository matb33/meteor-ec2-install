# Meteor EC2 installation script (1.0.1)

Automated server installation for Meteor 0.6.0+ on a fresh AWS EC2 Ubuntu Server
12.10+ installation.

Use git to deploy: `git push ec2 master`.

## How to setup:

1.	SSH into a fresh installation of Ubuntu 12.10 64-bit
2.	Put this script anywhere, such as `/tmp/install.sh`
3.	Modify `APPHOST` and `SERVICENAME` at the top of the file:
	- 	The `APPHOST` variable should be updated to the hostname or elastic IP
		of the EC2 instance you created
	-	The `SERVICENAME` variable can remain the same, but if you prefer you
		can name it after your app (example: `SERVICENAME=foobar`)
4.	`$ chmod +x /tmp/install.sh && /tmp/install.sh`

## Configuring your Meteor app:

__IMPORTANT__: You must create `config/[branch]/env.sh` and
`config/[branch]/settings.json` files for your Meteor app for each branch you
plan on maintaining. At a minimum, you should have a `master` branch for
production and a `develop` branch for development (use your own flavor of branch
names of course).

*Examples:*

### config/master/env.sh:

```shell
#!/bin/bash

export MONGO_URL="mongodb://127.0.0.1:27017/meteor"
export ROOT_URL="http://www.mymeteorapp.com"
export NODE_ENV="production"
export PORT="80"
export METEOR_SETTINGS="$(cat config/master/settings.json)"
```

### config/master/settings.json:

```json
{
	"s3": {
		"accessKeyID": "AJKGLKFJGLKJFGKJLKFF",
		"secretAccessKey": "39487593gh8475h9g3h9347h5g93874hg89347g4"
	},
	"public": {
		"maxPostsPerPage": 10
	}
}
```

See [docs.meteor.com](http://docs.meteor.com/#meteor_settings) for more
information on `settings.json`.

*NOTE: You could potentially store the `config` folder as a separate git
repository and pull it in as a submodule. If you take this approach,
you will need to know your way around git and make some minor
modifications to this script so that it knows to pull in submodules (start
near the `git archive` of `setup_post_update_hook`).*

## Notes:

1.	Logs for your app can be found under `/var/log/[SERVICENAME].log`

## Running locally:

To load your `settings.json` when developing locally, create a file in the root
of your project called `meteor` (and make it executable, such as
`chmod +x meteor`). For then on, start meteor by typing `./meteor` instead of
`meteor`. The appropriate `settings.json` file will be loaded for you based on
the branch you're currently working from.

Contents of your project's `meteor` file:

```shell
#!/bin/bash
meteor --settings "config/$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')/settings.json"
```