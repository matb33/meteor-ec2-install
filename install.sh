#!/bin/bash

# HOW TO EXECUTE:
#	1.	SSH into a fresh installation of Ubuntu 12.10 64-bit
#	2.	Put this script anywhere, such as /tmp/install.sh
#	3.	$ chmod +x /tmp/install.sh && /tmp/install.sh
#

# NOTES:
#	1.	IMPORTANT: You must create a .#production file in the root of your Meteor
#		app. An example .#production file looks like this:
#
# 		export MONGO_URL='mongodb://user:pass@linus.mongohq.com:10090/dbname'
# 		export ROOT_URL='http://www.mymeteorapp.com'
# 		export NODE_ENV='production'
# 		export PORT=80
#
#	2.	The APPHOST variable below should be updated to the hostname or elastic
#		IP of the EC2 instance you created.
#
#	3.	The SERVICENAME variable below can remain the same, but if you prefer
#		you can name it after your app (example: SERVICENAME=foobar).
#
#	4.	Logs for you app can be found under /var/log/[SERVICENAME].log
#

################################################################################
# Variables you should adjust for your setup
################################################################################

APPHOST=12.34.56.78
SERVICENAME=meteor_app

################################################################################
# Internal variables
################################################################################

MAINUSER=$(whoami)
MAINGROUP=$(id -g -n $MAINUSER)

GITBAREREPO=/home/$MAINUSER/$SERVICENAME.git
EXPORTFOLDER=/tmp/$SERVICENAME
APPFOLDER=/home/$MAINUSER/$SERVICENAME
APPEXECUTABLE=/home/$MAINUSER/.$SERVICENAME

################################################################################
# Utility functions
################################################################################

function replace {
	sudo perl -0777 -pi -e "s{\Q$2\E}{$3}gm" "$1"
}

function replace_noescape {
	sudo perl -0777 -pi -e "s{$2}{$3}gm" "$1"
}

function symlink {
	if [ ! -f $2 ]
		then
			sudo ln -s "$1" "$2"
	fi
}

function append {
	echo -e "$2" | sudo tee -a "$1" > /dev/null
}

################################################################################
# Task functions
################################################################################

function apt_update_upgrade {
	echo "--------------------------------------------------------------------------------"
	echo "Update and upgrade all packages"
	echo "--------------------------------------------------------------------------------"

	sudo apt-get -y update
	sudo apt-get -y upgrade
}

function install_fail2ban {
	echo "--------------------------------------------------------------------------------"
	echo "Install fail2ban"
	echo "--------------------------------------------------------------------------------"

	# Reference: http://plusbryan.com/my-first-5-minutes-on-a-server-or-essential-security-for-linux-servers
	sudo apt-get -y install fail2ban
}

function configure_firewall {
	echo "--------------------------------------------------------------------------------"
	echo "Configure firewall"
	echo "--------------------------------------------------------------------------------"

	# Reference: http://plusbryan.com/my-first-5-minutes-on-a-server-or-essential-security-for-linux-servers
	sudo ufw allow 22
	sudo ufw allow 80
	sudo ufw allow 443
}

function configure_automatic_security_updates {
	echo "--------------------------------------------------------------------------------"
	echo "Configure automatic security updates"
	echo "--------------------------------------------------------------------------------"

	# Reference: http://plusbryan.com/my-first-5-minutes-on-a-server-or-essential-security-for-linux-servers
	sudo apt-get -y install unattended-upgrades

	replace "/etc/apt/apt.conf.d/10periodic" \
'APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";' \
'APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";'
}

function install_git {
	echo "--------------------------------------------------------------------------------"
	echo "Install Git"
	echo "--------------------------------------------------------------------------------"

	sudo apt-get -y install git-core
	sudo git config --system user.email "$MAINUSER@$APPHOST"
	sudo git config --system user.name "$MAINUSER"
}

function install_nodejs {
	echo "--------------------------------------------------------------------------------"
	echo "Install Node.js"
	echo "--------------------------------------------------------------------------------"

	sudo apt-get -y install python-software-properties
	sudo add-apt-repository -y ppa:chris-lea/node.js
	sudo apt-get -y update
	sudo apt-get -y install nodejs
}

function install_mongodb {
	echo "--------------------------------------------------------------------------------"
	echo "Install MongoDB"
	echo "--------------------------------------------------------------------------------"

	sudo apt-get -y install mongodb
}

function install_meteor {
	echo "--------------------------------------------------------------------------------"
	echo "Install Meteor"
	echo "--------------------------------------------------------------------------------"

	curl https://install.meteor.com | /bin/sh
}

function setup_app_skeleton {
	echo "--------------------------------------------------------------------------------"
	echo "Setup app skeleton"
	echo "--------------------------------------------------------------------------------"

	rm -rf $APPFOLDER
	mkdir -p $APPFOLDER
	touch $APPFOLDER/main.js
}

function setup_app_service {
	echo "--------------------------------------------------------------------------------"
	echo "Setup app service"
	echo "--------------------------------------------------------------------------------"

	local SERVICEFILE=/etc/init/$SERVICENAME.conf
	local LOGFILE=/var/log/$SERVICENAME.log

	sudo rm -f $SERVICEFILE

	append $SERVICEFILE "description \"$SERVICENAME\""
	append $SERVICEFILE "author      \"Mathieu Bouchard <matb33@gmail.com>\""

	append $SERVICEFILE "start on runlevel [2345]"
	append $SERVICEFILE "stop on restart"
	append $SERVICEFILE "respawn"

	append $SERVICEFILE "pre-start script"
	append $SERVICEFILE "  echo \"[\$(/bin/date -u +%Y-%m-%dT%T.%3NZ)] (sys) Starting\" >> $LOGFILE"
	append $SERVICEFILE "end script"

	append $SERVICEFILE "pre-stop script"
	append $SERVICEFILE "  rm -f /var/run/$SERVICENAME.pid"
	append $SERVICEFILE "  echo \"[$(/bin/date -u +%Y-%m-%dT%T.%3NZ)] (sys) Stopping\" >> $LOGFILE"
	append $SERVICEFILE "end script"

	append $SERVICEFILE "script"
	append $SERVICEFILE "  echo \$\$ > /var/run/$SERVICENAME.pid"
	append $SERVICEFILE "  $APPEXECUTABLE \"$LOGFILE\""
	append $SERVICEFILE "end script"
}

function setup_bare_repo {
	echo "--------------------------------------------------------------------------------"
	echo "Setup bare repo"
	echo "--------------------------------------------------------------------------------"

	rm -rf $GITBAREREPO
	mkdir -p $GITBAREREPO
	cd $GITBAREREPO

	git init --bare
	git update-server-info
}

function setup_post_update_hook {
	echo "--------------------------------------------------------------------------------"
	echo "Setup post update hook"
	echo "--------------------------------------------------------------------------------"

	local HOOK=$GITBAREREPO/hooks/post-receive
	local RSYNCSOURCE=$EXPORTFOLDER/app_rsync

	rm -f $HOOK

	append $HOOK "#!/bin/bash"
	append $HOOK "unset \$(git rev-parse --local-env-vars)"

	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "echo \"Exporting app from git repo\""
	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "rm -rf $EXPORTFOLDER"
	append $HOOK "mkdir -p $EXPORTFOLDER"
	append $HOOK "git archive master | tar -x -C $EXPORTFOLDER"

	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "echo \"Updating production executable\""
	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "sudo mv -f $EXPORTFOLDER/.#production $APPEXECUTABLE"
	append $HOOK "echo -e \"\\\n\\\n/usr/bin/node $APPFOLDER/main.js >> \\\$1 2>&1\" >> $APPEXECUTABLE"
	append $HOOK "chmod 700 $APPEXECUTABLE"

	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "echo \"Bundling app as a standalone Node.js app\""
	append $HOOK "echo \"------------------------------------------------------------------------\""
	append $HOOK "cd $EXPORTFOLDER"
	append $HOOK "meteor update"
	append $HOOK "meteor bundle $EXPORTFOLDER/bundle.tar.gz"
	append $HOOK "if [ -f $EXPORTFOLDER/bundle.tar.gz ]; then"
	append $HOOK "  mkdir -p $RSYNCSOURCE"
	append $HOOK "  tar -zxf $EXPORTFOLDER/bundle.tar.gz --strip-components 1 -C $RSYNCSOURCE"

	append $HOOK "  if [ -f $RSYNCSOURCE/main.js ]; then"
	append $HOOK "    echo \"------------------------------------------------------------------------\""
	append $HOOK "    echo \"Building Fibers\""
	append $HOOK "    echo \"------------------------------------------------------------------------\""
	append $HOOK "    cd $RSYNCSOURCE/server/node_modules"
	append $HOOK "    rm -rf fibers"
	append $HOOK "    npm install fibers@1.0.0"

	append $HOOK "    echo \"------------------------------------------------------------------------\""
	append $HOOK "    echo \"Rsync standalone app to active app location\""
	append $HOOK "    echo \"------------------------------------------------------------------------\""
	append $HOOK "    rsync --checksum --recursive --update --delete --times $RSYNCSOURCE/ $APPFOLDER/"

	append $HOOK "    echo \"------------------------------------------------------------------------\""
	append $HOOK "    echo \"Restart app\""
	append $HOOK "    echo \"------------------------------------------------------------------------\""
	append $HOOK "    sudo service $SERVICENAME restart"
	append $HOOK "  fi"

	# Clean-up
	append $HOOK "  cd $APPFOLDER"
	append $HOOK "  rm -rf $EXPORTFOLDER"
	append $HOOK "fi"

	append $HOOK "echo \"\n\n--- Done.\""

	sudo chown $MAINUSER:$MAINGROUP $HOOK
	chmod +x $HOOK
}

function show_conclusion {
	echo -e "\n\n\n\n\n"
	echo "########################################################################"
	echo " On your local development server"
	echo "########################################################################"
	echo ""
	echo "Add remote repository:"
	echo "$ git remote add ec2 $MAINUSER@$APPHOST:$SERVICENAME.git"
	echo ""
	echo "Add to your ~/.ssh/config:"
	echo -e "Host $APPHOST\n  Hostname $APPHOST\n  IdentityFile PRIVATE_KEY_YOU_GOT_FROM_AWS.pem"
	echo ""
	echo "To deploy:"
	echo "$ git push ec2 master"
	echo ""
	echo "########################################################################"
	echo " Manual commands to run to finish off installation"
	echo "########################################################################"
	echo ""
	echo "Run the following command:"
	echo "$ sudo ufw enable"
	echo ""
	echo "Reboot to complete the installation. Example:"
	echo "$ sudo reboot"
	echo ""
}

################################################################################

apt_update_upgrade
install_fail2ban
configure_firewall
configure_automatic_security_updates
install_git
install_nodejs
install_mongodb
install_meteor
setup_app_skeleton
setup_app_service
setup_bare_repo
setup_post_update_hook
show_conclusion