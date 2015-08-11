#!/bin/sh -ex

if [ -n "$GIT_EMAIL" ]
then
  email=$GIT_EMAIL
  name=$GIT_NAME
else
  email=$DOCKER_EMAIL
  name=$DOCKER_USER
fi

set -u

git config --global user.email "${GIT_EMAIL}"
git config --global user.name "${GIT_NAME}"
git reset HEAD --hard
git clean -fd

function badge() {
echo "[![$3](https://img.shields.io/badge/Status-$1-$2.svg?style=flat)](http://github.com/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME)"

}

export STATE_EXPERIMENTAL=$(badge Experimental red "Experimental")
export STATE_ACTIVE=$(badge Active_Development orange "Active Development")
export STATE_UNTESTED=$(badge Some_Testing yellow "Some Testing")
export STATE_ALPHA=$(badge Alpha yellowgreen "Alpha")
export STATE_BETA=$(badge Beta green "Beta")
export STATE_PROD=$(badge Production_Ready blue "Production Ready")

export BLURB="**If you use this project please consider giving us a star on [GitHub](http://github.com/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME) . Also if you can spare 30 secs of your time please let us know your priorities here https://sillelien.wufoo.com/forms/zv51vc704q9ary/  - thanks, that really helps!**"

export FOOTER="(c) 2015 Sillelien all rights reserved. Please see LICENSE for license details of this project. Please visit http://sillelien.com for help and commercial support."

export HEADER=""

envsubst '${RELEASE}:${BLURB}:${FOOTER}:${HEADER}:${STATE_EXPERIMENTAL}:${STATE_ACTIVE}:${STATE_UNTESTED}:${STATE_ALPHA}:${STATE_BETA}:${STATE_PROD}' < README.md > /tmp/README.expanded
git checkout master
git pull 
git merge staging -m "Auto merge"
echo ${RELEASE} > .release
mv /tmp/README.expanded README.md
git commit -a -m "Promotion from staging of ${RELEASE}" || :
git push
git tag ${RELEASE} || :
git push --tags
git push origin master
