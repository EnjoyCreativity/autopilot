#!/bin/bash
#
# In order to fully automate this script and be rid of the prompt to accept
# the hosts file from the server, you'll need to add the following to your
# .drush/drushrc.php: $options['ssh-options'] = '-o StrictHostKeyChecking=no'
#
# You may also want to include this in cron for each site you want to update.
#

set -e

terminus="$HOME/bin/terminus"
site=$1
multidev="autopilot"


echo '=================================='
echo "BEGINNING AUTOPILOT FOR $1"
echo '=================================='
echo 'AUTHENTICATE WITH PANTHEON:'
$terminus auth login david@enjoycreativity.com
echo '=================================='
echo 'CHECKING FOR UPDATES ON LIVE:'
updatestatus="$($terminus drush "upc --security-only --no-core --check-updatedb=0 -n" --site=$site --env=test | grep 'SECURITY UPDATE available')"

if echo "$updatestatus"; then
		#mail -s "$site security updates" autopilot@enjoycreativity.com <<< "Updates available in the Test environment of $site. Go check it out! $updatestatus"

        echo '=================================='
        echo 'CHANGING MODE IN AUTOPILOT TO GIT:'
        $terminus site set-connection-mode --site=$site --env=dev --mode=git
	echo '=================================='
	echo 'APPLYING UPSTREAM UPDATES TO DEV:'
	$terminus site upstream-updates apply --yes --site=$site --env=dev --accept-upstream --updatedb
	echo '=================================='
	echo 'TESTING FOR AUTOPILOT ENVIRONMENT:'

	if $terminus site environments --site=$site | grep autopilot; then
		echo 'SYNCING CODE AND CONTENT TO MULTIDEV'
		$terminus site clone-content --site=$site --from-env=live --to-env=$multidev --yes
		$terminus site merge-from-dev --site=$site --env=$multidev

	else
		echo 'CREATING NEW ENV FOR AUTOPILOT:'
		$terminus site create-env --site=$site --from-env=dev --to-env=$multidev
	fi

	echo '=================================='
	echo 'CHANGING MODE IN AUTOPILOT TO SFTP:'
	$terminus site set-connection-mode --site=$site --env=$multidev --mode=sftp
	echo '=================================='
	echo 'APPLYING ALL SECURITY UPDATES:'
	$terminus drush "up --security-only --no-core -y" --site=$site --env=$multidev
	echo '=================================='
	echo 'COMMITTING THE CODE CHANGES:'
	$terminus site code commit --site=$site --env=$multidev --message="Enjoy Creativity Autopilot: Running security updates. $updatestatus" --yes
	echo '=================================='
	echo 'MERGING COMMIT INTO MASTER / DEV:'
	$terminus site merge-to-dev --site=$site --env=$multidev
	echo '=================================='
	echo 'DEPLOYING UPDATES INTO TEST'
	$terminus site deploy --site=$site --env=test --sync-content --cc --updatedb --note="Enjoy Creativity Autopilot: Running security updates and any other changes staged in Dev. Please double check the code tab to ensure only the updates are in this deployment before pushing to live.  $updatestatus"
	echo '=================================='
	echo 'SENDING EMAIL'
	echo -e "Updates available in the Test environment of $site. Go check it out! \n $updatestatus" | mail -s "$site security updates" autopilot@enjoycreativity.com
	echo '=================================='
	echo 'AUTOPILOT COMPLETE!'
	echo '=================================='

else
	echo '=================================='
	echo 'STOPPED: NO SECURITY UPDATES.'
fi

#https://pantheon.io/docs/articles/sites/code/applying-upstream-updates/
#https://github.com/pantheon-systems/terminus/wiki/Available-Commands
