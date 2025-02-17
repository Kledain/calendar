#!/bin/bash

if [ ! -e node_modules ]
then
  mkdir node_modules
fi

case `uname -s` in
  MINGW* | Darwin*)
    USER_UID=1000
    GROUP_UID=1000
    ;;
  *)
    if [ -z ${USER_UID:+x} ]
    then
      USER_UID=`id -u`
      GROUP_GID=`id -g`
    fi
esac

# options
SPRINGBOARD="recette"
for i in "$@"
do
case $i in
    -s=*|--springboard=*)
    SPRINGBOARD="${i#*=}"
    shift
    ;;
    *)
    ;;
esac
done

clean () {
  docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle clean
}

buildNode () {
#jenkins
  echo "[buildNode] Get branch name from jenkins env..."
  BRANCH_NAME=`echo $GIT_BRANCH | sed -e "s|origin/||g"`
  if [ "$BRANCH_NAME" = "" ]; then
    echo "[buildNode] Get branch name from git..."
    BRANCH_NAME=`git branch | sed -n -e "s/^\* \(.*\)/\1/p"`
  fi
  if [ "$BRANCH_NAME" = "" ]; then
    echo "[buildNode] Branch name should not be empty!"
    exit -1
  fi
  if [ "$BRANCH_NAME" = 'master' ]; then
    echo "[buildNode] Use entcore version from package.json ($BRANCH_NAME)"
    case `uname -s` in
      MINGW*)
        docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm install --no-bin-links && npm update entcore && node_modules/gulp/bin/gulp.js build"
         ;;
       *)
         docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm install && npm update entcore && node_modules/gulp/bin/gulp.js build"
     esac
  else
     echo "[buildNode] Use entcore tag $BRANCH_NAME"
     entcore_tags=$(npm dist-tags ls entcore)
     if [[ $entcore_tags == *"$BRANCH_NAME"* ]]; then
       case `uname -s` in
         MINGW*)
           docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm install --no-bin-links && npm rm --no-save entcore && npm install --no-save entcore@$BRANCH_NAME && node_modules/gulp/bin/gulp.js build"
                       ;;
         *)
           docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm install && npm rm --no-save entcore && npm install --no-save entcore@$BRANCH_NAME && node_modules/gulp/bin/gulp.js build"
       esac
     else
       case `uname -s` in
          MINGW*)
            docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm install --no-bin-links && node_modules/gulp/bin/gulp.js build"
               ;;
          *)
            docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm install && node_modules/gulp/bin/gulp.js build"
       esac
     fi
  fi
}

buildGradle () {
  docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle shadowJar install publishToMavenLocal
}

publish () {
  if [ -e "?/.gradle" ] && [ ! -e "?/.gradle/gradle.properties" ]
  then
    echo "odeUsername=$NEXUS_ODE_USERNAME" > "?/.gradle/gradle.properties"
    echo "odePassword=$NEXUS_ODE_PASSWORD" >> "?/.gradle/gradle.properties"
    echo "sonatypeUsername=$NEXUS_SONATYPE_USERNAME" >> "?/.gradle/gradle.properties"
    echo "sonatypePassword=$NEXUS_SONATYPE_PASSWORD" >> "?/.gradle/gradle.properties"
  fi
  docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle publish
}

testNode () {
  rm -rf coverage
  rm -rf */build
  case `uname -s` in
    MINGW*)
      docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm install --no-bin-links && node_modules/gulp/bin/gulp.js drop-cache &&  npm test"
      ;;
    *)
      docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "npm install && node_modules/gulp/bin/gulp.js drop-cache && npm test"
  esac
}

testGradle() {
  docker-compose run --rm -u "$USER_UID:$GROUP_GID" gradle gradle test --no-build-cache --rerun-tasks
}

watch () {
  docker-compose run --rm -u "$USER_UID:$GROUP_GID" node sh -c "node_modules/gulp/bin/gulp.js watch --springboard=/home/node/$SPRINGBOARD"
}

for param in "$@"
do
  case $param in
    clean)
      clean
      ;;
    buildNode)
      buildNode
      ;;
    buildGradle)
      buildGradle
      ;;
    install)
      buildNode && buildGradle
      ;;
    watch)
      watch
      ;;
    publish)
      publish
      ;;
    test)
      testNode ; testGradle
      ;;
    testNode)
      testNode
      ;;
    testGradle)
      testGradle
      ;;
    *)
      echo "Invalid argument : $param"
  esac
  if [ ! $? -eq 0 ]; then
    exit 1
  fi
done
