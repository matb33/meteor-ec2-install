# Meteor EC2 installation script

Automated server installation for Meteor 0.6.0+ on a fresh AWS EC2 Ubuntu Server 12.10 installation.

Similarly to Heroku, deploy with a simple `git push ec2 master`. Awesome!

*NOTE: Although MongoDB is installed, I only tested against having my database remotely on MongoHQ. Let me know if you have issues with a local DB.*