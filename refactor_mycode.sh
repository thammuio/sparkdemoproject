#!/bin/bash


prompt () {
  if [ -z "$NO_PROMPT" ]; then
    read -p "Press enter to continue:"
  fi
}

########################################################################
# Setting variables
########################################################################

INITIAL_VERSION=${INITIAL_VERSION:-2.4.8}
TARGET_VERSION=${TARGET_VERSION:-3.3.1}
SCALAFIX_RULES_VERSION=${SCALAFIX_RULES_VERSION:-0.1.9}



########################################################################
# Run scalafix
########################################################################

echo "Building current project"
sbt clean compile test package


# Adding the scalafix dependency to the Spark 3 copy of the project
cp -af build.sbt build.sbt.bak

cat build.sbt.bak | \
  python -c 'import re,sys;print(re.sub(r"name :=\s*\"(.*?)\"", "name :=\"\\1-3\"", sys.stdin.read()))' > build.sbt

cat >> build.sbt <<- EOM
scalafixDependencies in ThisBuild +=
  "com.holdenkarau" %% "spark-scalafix-rules-2.4.8" % "${SCALAFIX_RULES_VERSION}"
semanticdbEnabled in ThisBuild := true
EOM

mkdir -p project

cat >> project/plugins.sbt <<- EOM
addSbtPlugin("ch.epfl.scala" % "sbt-scalafix" % "0.10.4")
EOM


cp .scalafix.conf.sample .scalafix.conf

prompt
echo "Great! Now we'll try and run the scala fix rules in your project! Yay!. This might fail if you have interesting build targets."

sbt scalafix

echo "Huzzah running the warning check..."

cp .scalafix-warn.conf.sample .scalafix.conf

sbt scalafix ||     (echo "Linter warnings were found"; prompt)

rm .scalafix.conf

echo "ScalaFix is done, you should probably review the changes (e.g. git diff)"

prompt

# We don't run compile test because some changes are not back compat (see value/key change).
# sbt clean compile test package
cp -af build.sbt build.sbt.bak.pre3

cat build.sbt.bak.pre3 | \
  python -c "import re,sys;print(sys.stdin.read().replace(\"${INITIAL_VERSION}\", \"${TARGET_VERSION}\"))" > build.sbt

echo "You will also need to update dependency versions now (e.g. Spark to 3.3 and libs)"
echo "Please address those and then press enter."
prompt

sbt clean compile test package
