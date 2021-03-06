#! /bin/bash

set -eo pipefail

PUBDIR="$SAFEDIR"
KEYDIR="$SAFEDIR"
PATH="$PATH:$SCION_ROOT/bin"

. "$PLAYGROUND/crypto_lib.sh"

cd $SAFEDIR
stop_docker || true
start_docker

for loc in {bern,geneva}
do
    echo "Preparation: $loc"
    if [ "$loc" = "bern" ]; then
        IA="1-ff00:0:110"
    else
        IA="1-ff00:0:120"
    fi

    mkdir -p $SAFEDIR/$loc && cd $SAFEDIR/$loc
    set_dirs
    # Generate configuration files
    navigate_pubdir
    basic_conf && root_conf && ca_conf && as_conf
    prepare_ca
    sed -i \
        -e 's/{{.Country}}/CH/g' \
        -e "s/{{.State}}/$loc/g" \
        -e "s/{{.Location}}/$loc/g" \
        -e "s/{{.Organization}}/$loc/g" \
        -e "s/{{.OrganizationalUnit}}/$loc InfoSec Squad/g" \
        -e "s/{{.ISDAS}}/$IA/g" \
        basic.cnf
    for cnf in *.cnf
    do
        sed -i \
        -e "s/{{.ShortOrg}}/$loc/g" \
        $cnf
    done
    # Generate certificates
    #
    # The default start and end date are set by TestUpdateCrypto.
    # For AS certificates we want smaller periods, because we want to check that
    # the database correctly fetches when given a specific point in time.
    KEYDIR=/workdir/$loc/keys PUBDIR=/workdir/$loc/public docker_exec "navigate_pubdir && gen_root && gen_ca \
                && STARTDATE=20200624120000Z ENDDATE=20200627120000Z gen_as && mv cp-as.crt cp-as1.crt \
                && STARTDATE=20200626120000Z ENDDATE=20200629120000Z gen_as && mv cp-as.crt cp-as2.crt \
                && STARTDATE=20200628120000Z ENDDATE=20200701120000Z gen_as_ca_steps && mv cp-as.crt cp-as3.crt"

    scion-pki certs validate --type cp-root $PUBDIR/cp-root.crt
    scion-pki certs validate --type cp-ca $PUBDIR/cp-ca.crt
    scion-pki certs validate --type cp-as $PUBDIR/cp-as1.crt
    scion-pki certs validate --type cp-as $PUBDIR/cp-as2.crt
    scion-pki certs validate --type cp-as $PUBDIR/cp-as3.crt

    mkdir -p "$TESTDATA/$loc"
    cp $PUBDIR/*.crt "$TESTDATA/$loc"
done

stop_docker
