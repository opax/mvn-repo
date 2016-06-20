#!/bin/bash

###
# After doing a build of an eXist code base
# for a sepecific tag this script does some
# very simple copying and renaming of JAR files
# from an into a Maven like repository structure.
#
# If you want extension modules you must enable
# these in $EXIST_HOME/extensions/build.properties
# before running this script
#
# Note - It will not generate the POM files for you!
###

set -e

# uncomment the line below for debugging this script!
#set -x

# Configiguration options
EXIST_HOME=/Users/aretter/NetBeansProjects/exist-git
EXIST_TAG=3.0.RC1
MVN_REPO_HOME=/Users/aretter/NetBeansProjects/mvn-repo
ARTIFACT_BASE="exist"
TMP_DIR=/tmp



function mavenise {
	if [ ! -f "$1" ] ; then
		echo 1>&2 FILE DOES NOT EXIST: $1
		return
	fi
	OUT_DIR="${MVN_REPO_HOME}/org/exist-db/${2}/${EXIST_TAG}"
	mkdir -p $OUT_DIR

	CLASSIFIER="${3:+-}$3"
	FILE_BASE="${OUT_DIR}/${2}-${EXIST_TAG}"
	OUT_FILE="${FILE_BASE}${CLASSIFIER}.jar"
	cp -v $1 $OUT_FILE
	openssl sha1 -r "${OUT_FILE}" | sed 's/\([a-f0-9]*\).*/\1/' > "${OUT_FILE}.sha1"

	if [[ -n "$MVN_REPOSITORY_ID" && -n "$MVN_REPOSITORY_URL" ]]; then
		if [[ -f "${FILE_BASE}.pom" ]] ; then
			echo Deploying "$OUT_FILE"
			mvn deploy:deploy-file -DrepositoryId="$MVN_REPOSITORY_ID" -Durl="$MVN_REPOSITORY_URL" -DpomFile="${FILE_BASE}.pom" -Dfile="$OUT_FILE" -Dclassifier="$3"
		else
			echo 1>&2 Missing POM file '"'${FILE_BASE}.pom'"', not deploying
		fi
	fi
}

cd $EXIST_HOME

# Checkout and build the tag for the release version
git checkout "tags/eXist-${EXIST_TAG}"
./build.sh clean
[ -f build/scripts/build-sourcejars.xml ] && ./build.sh -f build/scripts/build-sourcejars.xml clean
./build.sh
[ -f build/scripts/build-sourcejars.xml ] && ./build.sh -f build/scripts/build-sourcejars.xml sourcejars

# Mavenise the root jar files
mavenise exist.jar ${ARTIFACT_BASE}-core
mavenise exist-sources.jar ${ARTIFACT_BASE}-core sources
mavenise start.jar ${ARTIFACT_BASE}-start
mavenise start-sources.jar ${ARTIFACT_BASE}-start sources
mavenise exist-optional.jar ${ARTIFACT_BASE}-optional
mavenise exist-optional-sources.jar ${ARTIFACT_BASE}-optional sources

mavenise xquery-modules-sources.jar ${ARTIFACT_BASE}-xquery-modules sources

# Mavenise each of the extension modules
for f in lib/extensions/exist-*.jar
do
	FILE_NAME=$(basename $f)
	ARTIFACT_NAME="${FILE_NAME%.jar}"
	mavenise $f "${ARTIFACT_NAME}"
done
