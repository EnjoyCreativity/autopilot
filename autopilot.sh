#!/bin/bash

set -e

# You'll want to change this to where you run Terminus
terminus="$HOME/bin/terminus"
# The Pantheon website these updates are being applied to
site=$1
# The email you previously authenticated with machine tokens
pemail=$2
# The email you'd like notifications to be sent to
email=$3
# What should the multidev environment be called?
multidev="autopilot"

echo '=================================='
echo "BEGINNING AUTOPILOT FOR $1"
echo '=================================='
echo 'AUTHENTICATE WITH PANTHEON:'
$terminus auth login $2
echo '=================================='
echo 'CHECKING FOR UPDATES ON LIVE:'
updatestatus="$($terminus drush "upc --security-only --no-core --check-updatedb=0 -n" --site=$site --env=test | grep 'SECURITY UPDATE available')"

if echo "$updatestatus"; then
    echo '=================================='
    echo 'BACKUP EVERY ENVIRONMENT:'
    $terminus site backups create --site=$site --env=dev --element=all
    $terminus site backups create --site=$site --env=test --element=all
    $terminus site backups create --site=$site --env=live --element=all
    echo '=================================='
    echo 'CHANGING MODE IN DEV TO GIT:'
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
	$terminus site code commit --site=$site --env=$multidev --message="Autopilot: Running security updates. $updatestatus" --yes
	echo '=================================='
	echo 'MERGING COMMIT INTO MASTER / DEV:'
	$terminus site merge-to-dev --site=$site --env=$multidev
	echo '=================================='
	echo 'DEPLOYING UPDATES INTO TEST'
	$terminus site deploy --site=$site --env=test --sync-content --cc --updatedb --note="Autopilot: Running security updates and any other changes staged in Dev. Please double check the code tab to ensure only the updates are in this deployment before pushing to live.  $updatestatus"
	echo '=================================='
	echo 'SENDING EMAIL'
	echo -e "Updates available in the Test environment of $site. Go check it out! \n $updatestatus" | mail -s "$site security updates" $3
	echo '=================================='
	echo 'AUTOPILOT COMPLETE!'
	echo '=================================='

else
	echo '=================================='
	echo 'STOPPED: NO SECURITY UPDATES.'
fi
