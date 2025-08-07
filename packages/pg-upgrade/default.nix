{
  pkgs,
  oldPostgres,
  newPostgres,
}:
pkgs.writeScriptBin "upgrade-pg" ''
  set -eux
  systemctl stop postgresql

  BASE_DIR=''${1:-}

  # XXX replace `<new version>` with the psqlSchema here
  export NEWDATA="$BASE_DIR/var/lib/postgresql/${newPostgres.psqlSchema}"

  # XXX specify the postgresql package you'd like to upgrade to
  export NEWBIN="${newPostgres}/bin"

  export OLDDATA="$BASE_DIR/var/lib/postgresql/${oldPostgres.psqlSchema}"
  export OLDBIN="${oldPostgres}/bin"

  echo "\$NEWDATA=$NEWDATA"
  echo "\$OLDDATA=$OLDDATA"

  [ ! -d "$OLDDATA" ] && echo "Old data dir for postgres does not exist" && exit 1

  read -p "Are you sure? " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    install -d -m 0700 -o postgres -g postgres "$NEWDATA"
    cd "$NEWDATA"

    sudo -u postgres $NEWBIN/initdb -D "$NEWDATA"
    sudo -u postgres $NEWBIN/pg_upgrade \
      --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
      --old-bindir $OLDBIN --new-bindir $NEWBIN
  fi
''
