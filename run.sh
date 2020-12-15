#!/bin/sh

#docker automation script
set -e

echo -e "[Running] Mkdocs internally to serve it on port 8000, with site.tar.gz so when we browse to http://localhost:8000​ we’ll see the website"


if [ "$a" = 'produce' ]; then

  echo $b
  
  if [ ! -d "$b" ]; then
    echo -e 'Wrong argument  cant locate Mkdocs folder'
    echo -e '=================================================================='
    echo -e 'docker run -v $PWD:/var/mkdocs produce '
    echo -e '=================================================================='
    exit 1
  fi

  #Switched  mkdocs folder
  cd "$b"

  #Check mkdocs.yml file exist 
  if [ ! -f "mkdocs.yml" ]; then
    echo -e 'Unable to Locate mkdocs.yml config file '
    exit 1
  fi

  #Build the mkdocs folder 
  mkdocs build --clean

  if [ ! -f "site.tar.gz" ]; then
    #remove it
    rm -rf site.tar.gz
  fi
  
  #site.tar.gz Arhive
  tar czf site.tar.gz *

  # site.tar.gz folder movement

  mv site.tar.gz ../

  echo -e 'Produced site.tar.gz being served'

elif  [ "$a" = 'serve' ]; then

  if [ ! -f "site.tar.gz" ]; then
    echo -e '[site.tar.gz] tar file, not generated. Build it again  '
    echo -e '=================================================================='
    echo -e 'docker run -v $PWD:/var/mkdocs mkdocs produce foler'
    echo -e '=================================================================='
    exit 1
  fi

  # Creating OPT serving folder
  mkdir -p /opt/www

  #remove the folder 
  rm -rf /opt/www/*
  # Extract the tar gz file to a new www Location
  tar xf site.tar.gz -C /opt/www
  #  WWW directory 
  cd /opt/www 
  # Serving file  
  mkdocs serve --dev-addr=0.0.0.0:8000


else
  exec "$@"
fi

