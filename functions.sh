#!/usr/bin/env bash

export PATH=$PATH:/usr/local/Cellar/gettext/0.19.6/bin/
build_util_dir=${BUILD_UTILS_DIR:-../build-utils}
export PRODUCTION_BUILD=
if [[ $CIRCLE_BRANCH == "master" ]]
then
        export PRODUCTION_BUILD=true
        export environment=master
        export use_gitflow=true
        echo
        echo "*********************************"
        echo "**** MASTER PRODUCTION BUILD ****"
        echo "*********************************"
        echo
elif [[ -n ${CI_PULL_REQUEST:=} ]]
then
        export PRODUCTION_BUILD=yes
        export environment=staging
        export use_gitflow=true
        echo "PART OF PR ${CI_PULL_REQUEST}"
else

    if [[ $CIRCLE_BRANCH == release* ]]
    then
        export PRODUCTION_BUILD=
        export environment=staging
        export use_gitflow=true
    elif [[ $CIRCLE_BRANCH == feature* ]]
    then
        export PRODUCTION_BUILD=
        export environment=dev
        export use_gitflow=true
    elif [[ $CIRCLE_BRANCH == bugfix* ]]
    then
        export PRODUCTION_BUILD=
        export environment=dev
        export use_gitflow=true
    elif [[ $CIRCLE_BRANCH == support* ]] || [[ $CIRCLE_BRANCH == hotfix* ]]
    then
        export PRODUCTION_BUILD=
        export environment=staging
        export use_gitflow=true
    else
        export PRODUCTION_BUILD=
        export environment=${CIRCLE_BRANCH:-local}
        export use_gitflow=false
    fi

fi

if [[ -n ${PRODUCTION_BUILD} ]]
then
    echo "This is a production build so it will take longer than usual."
fi

export ARTIFACT_DIR=${CIRCLE_ARTIFACTS:-.}

if [[ -n ${CI:=} ]]
then
    export CODENAME=$($build_util_dir/codenames/name.sh $CIRCLE_SHA1)
    if [[ -n $PRODUCTION_BUILD ]]
    then
        export RELEASE="${MAJOR_VERSION:-}.${CIRCLE_BUILD_NUM}"
    else
        export RELEASE="$(echo $CIRCLE_BRANCH | tr '/' '-')-${CIRCLE_BUILD_NUM}}"
    fi
    export RELEASE_NUMBER="${CIRCLE_BUILD_NUM}"
    export RELEASE_ID="${CIRCLE_SHA1}"
else
    export RELEASE=local
    export RELEASE_ID=local
    export CODENAME=local
    export RELEASE_NUMBER=0
fi


export release=${RELEASE}
export RELEASE_VERSION="${RELEASE}"
export RELEASE_NAME="${CODENAME}"
export AWS_DEFAULT_REGION=eu-west-1




changed() {
    if ${forced:-false}
    then
        true
    else
        if [[ -n $CI && -f ~/build-cache/last_sha ]]
        then
             (( $(git diff $(< ~/build-cache/last_sha) ${CIRCLE_SHA1} . | wc -l) > 0 ))
        else
            (( $(find . -type f -cmin -$age | wc -l) > 0 ))
        fi

    fi
}

undeployed() {
    if ${forced:-false}
    then
        true
    else
        if [[ -n $CI && -f ~/build-cache/last_deploy_sha ]]
        then
             (( $(git diff $(< ~/build-cache/last_deploy_sha) ${CIRCLE_SHA1} . | wc -l) > 0 ))
        else
            true
        fi

    fi
}



copy() {
 rsync -tav $@
}

ifnewer() {
    if [[ $1 -nt $2 ]]
    then
        eval $3
    fi

}

s3_release() {
      export DEPLOY_PREFIX="version/${RELEASE_VERSION}"
     envsubst < ${build_util_dir}/redirect.html > ${DEPLOY_DIR}/redirect-expanded.html
     aws s3 cp  --cache-control "max-age=0, no-cache, no-store, private" --expires ""    ${DEPLOY_DIR}/redirect-expanded.html s3://${DEPLOY_HOST}/index.html
}

s3_deploy() {

    if [[ $environment == master ]]
    then
    export DEPLOY_PREFIX="version/${RELEASE_VERSION}"
        [ -f  s3_website.yml ] || cp -f ${build_util_dir}/s3_website.yml .
        s3_website cfg apply --headless
        s3_website push
#        sleep 10
#        aws s3 cp  --cache-control "max-age=0, no-cache, no-store, private" --expires ""    ${DEPLOY_DIR}/redirect-expanded.html s3://${DEPLOY_HOST}/~/${environment}/index.html
#        aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_DISTRIBUTION} --paths /!/*
    else
        export DEPLOY_PREFIX="~/${CIRCLE_BRANCH:-local}"
        envsubst < ${build_util_dir}/redirect.html > ${DEPLOY_DIR}/redirect-expanded.html
        aws s3 sync --delete --cache-control "max-age=0, no-cache, no-store, private" --expires "" --exclude "typings/**" --exclude "static/**" --exclude "cdn/**"  ${DEPLOY_DIR}/ s3://${DEPLOY_HOST}/${DEPLOY_PREFIX}/
#

    fi
    echo https://${DEPLOY_HOST}/${DEPLOY_PREFIX}/ > ~/.build-utils-last-deploy-url

}


#if [[ -n ${DOCKER_USER} ]] && which docker
#then
#  docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS tutum.co
#fi
#
#if [[ -n ${TUTUM_USERNAME} ]] && which tutum
#then
#    echo "Logging in to Tutum"
#    tutum login -u $TUTUM_USERNAME -p $TUTUM_PASSWORD
#fi



#function routes3() {
#    aws s3 sync --quiet --delete --cache-control "no-cache" s3://$1/${3}/ s3://$1/previous/
#    echo ${4} > /tmp/version
#    echo ${4},${codename:-},${CIRCLE_BUILD_NUM},${CIRCLE_SHA1},${CIRCLE_COMPARE_URL},$(date) > /tmp/build
#    aws s3 cp  /tmp/version s3://$1/${4}/.version
#    aws s3 cp /tmp/build s3://$1/${4}/.build
#    aws s3 cp /tmp/version s3://$1/${3}/.stale
#
#    if [[ $2 == "forward" ]]
#    then
#        live=${4}
#    else
#        live=${3}
#    fi
#    aws s3 sync --quiet --delete --cache-control "no-cache" s3://$1/${live}/ s3://$1/current/
#
#    ws_config=$(
#    cat << EOF
#    {
#        "ErrorDocument": {
#            "Key": "error.html"
#        },
#        "IndexDocument": {
#            "Suffix": "index.html"
#        },
#        "RoutingRules": [
#            {
#                "Condition": {
#                    "KeyPrefixEquals": "live/"
#                },
#                "Redirect": {
#                    "HostName": "$1",
#                "HttpRedirectCode": "302",
#                "Protocol": "https",
#                "ReplaceKeyPrefixWith": "$live/"
#            }
#        }
#    ]
#}
#
#EOF
#)
#
#    aws s3api put-bucket-website --bucket $1 --website-configuration "$ws_config"
#
#}
#
