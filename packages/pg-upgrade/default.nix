{
  pkgs,
  oldPackage,
  oldBin,
  newPackage,
  newBin,
}:
pkgs.writeShellScriptBin "pg_upgrade_version" ''
  set -eu

  BASE_DIR=''${1:-}

  # XXX replace `<new version>` with the psqlSchema here
  export NEWDATA="$BASE_DIR/var/lib/postgresql/${newPackage.psqlSchema}"

  # XXX specify the postgresql package you'd like to upgrade to

  export OLDDATA="$BASE_DIR/var/lib/postgresql/${oldPackage.psqlSchema}"

  echo "\$NEWDATA=$NEWDATA"
  echo "\$OLDDATA=$OLDDATA"

  [ ! -d "$OLDDATA" ] && echo "Old data dir for postgres does not exist" && exit 1

  read -p "Are you sure? " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    install -d -m 0700 -o postgres -g postgres "$NEWDATA"
    cd "$NEWDATA"
    sudo -u postgres ${newBin}/initdb -D "$NEWDATA"

    cp $OLDDATA/postgresql.conf $NEWDATA

    sudo -u postgres ${newBin}/pg_upgrade \
      --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
      --old-bindir ${oldBin} --new-bindir ${newBin}
  fi
''
