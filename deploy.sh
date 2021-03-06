#!/usr/bin/env bash

set -e

if [[ "false" != "$TRAVIS_PULL_REQUEST" ]]; then
	echo "Not deploying pull requests."
	exit
fi

if [[ ! $SVN_REPO ]]; then
	echo "SVN repo is not specified."
	exit
fi

if [[ -z "$TRAVIS_BRANCH" ]]; then
	echo "Build branch is required and must be 'master'"
	exit
fi

if [[ -z "$TRAVIS_TAG" ]]; then
	echo "This isn't a tagged release"
	exit
fi

# Untrailing slash of SVN_REPO path
SVN_REPO=`echo $SVN_REPO | sed -e "s/\/$//"`
# Git repository
GH_REF=https://github.com/${TRAVIS_REPO_SLUG}.git

echo "Starting deploy..."

mkdir releases

cd releases
BASE_DIR=$(pwd)

echo "Checking out trunk from $SVN_REPO ..."
svn co -q $SVN_REPO/trunk

echo "Getting clone from $GH_REF to $SVN_REPO ..."
git clone -q $GH_REF ./git

cd ./git

if [ -e "bin/build.sh" ]; then
	echo "Starting bin/build.sh."
	bash bin/build.sh
fi

cd $BASE_DIR

echo "Syncing git repository to svn"
rsync -a --exclude=".svn" --checksum --delete ./git/ ./trunk/
rm -fr ./git

cd ./trunk


if [ -e ".svnignore" ]; then
    echo "svn propset"
    svn propset -q -R svn:ignore -F .svnignore .
fi

echo "Run svn add"
svn st | grep '^!' | sed -e 's/\![ ]*/svn del -q /g' | sh

echo "Run svn del"
svn st | grep '^?' | sed -e 's/\?[ ]*/svn add -q /g' | sh

# If tag number and credentials are provided, commit to trunk.
if [[ $TRAVIS_TAG && $WP_ORG_USERNAME && $WP_ORG_PASSWORD ]]; then
	if [[ ! -d tags/$TRAVIS_TAG ]]; then

		# SVN commit
		echo "Commit to $SVN_REPO."
		svn commit -m "commit version $TRAVIS_TAG" --username $WP_ORG_USERNAME --password $WP_ORG_PASSWORD --trust-server-cert --non-interactive
		
		# make a copy in /tags/ folder
		echo "Take snapshot of $TRAVIS_TAG"
		svn copy $SVN_REPO/trunk $SVN_REPO/tags/$TRAVIS_TAG -m "Take snapshot of $TRAVIS_TAG" --username $WP_ORG_USERNAME --password $WP_ORG_PASSWORD --trust-server-cert --non-interactive
		echo "Finished copying to: $SVN_REPO/tags/$TRAVIS_TAG"
	else
		echo "tags/$TRAVIS_TAG already exists."
	fi
else
	echo "Nothing to commit and check \`svn st\`."
	svn st
fi