# Autopilot

Autopilot is a simple bash script to automate security updates on Drupal sites hosted on Pantheon. When run (autopilot SITE ENVIRONMENT PEMAIL EMAIL), it runs through the following actions:

 1. Authenticate with Pantheon via previously authenticated machine token.
 2. Checking for non-core security updates on the Live environment.
 3. Perform backups in every environment.
 4. Change Dev environment to Git mode.
 5. Apply upstream updates to Dev.
 6. Testing to see if there is a Multi-Dev environment for Autopilot.
 7. Creates one from Live, or syncs up from Live.
 8. Changes Autopilot environment to SFTP mode.
 9. Applies all security updates to the Autopilot environment.
 10. Apply and deploy these changes to Dev, and then Test environments.
 11. Send email to notify that there are updates ready to test in Test.

## Crontab
You may also want to include this in cron for each site you want to update. In this email, the script is run every 30 minutes, but you could set it to run only on Wednesdays (usual security release day). Note: this may not get security updates for Drupal 8, because they are sometimes released on odd days to coincide with security updates for dependant packages.
`*/30 * * * * sh /PATH/TO/autopilot/autopilot.sh SITE PEMAIL EMAIL`

In order to fully automate this script and be rid of the prompt to accept the hosts file from the server, you'll need to add the following to your .drush/drushrc.php:
`$options['ssh-options'] = '-o StrictHostKeyChecking=no'`

You can find more information about Terminus commands at:
https://pantheon.io/docs/articles/sites/code/applying-upstream-updates/
https://github.com/pantheon-systems/terminus/wiki/Available-Commands