#!/usr/bin/env sh
SDEBUG=${SDEBUG-}
GITHUB_PAT="${GITHUB_PAT:-$(echo 'OGUzNjkwMDZlMzNhYmNmMGRiNmE5Yjg1NWViMmJkNWVlNjcwYTExZg=='|base64 -d)}"
IMPOSM3_RELEASE="${IMPOSM3_RELEASE:-latest}"
CURL_SSL_OPTS="${CURL_SSL_OPTS:-"--tlsv1"}"
PKG="omniscale/imposm3"
do_curl() { if ! ( curl "$@" );then curl $CURL_SSL_OPTS "$@";fi; }
install() {
    if [ "x${SDEBUG}" != "x" ];then set -x;fi
    : "install https://github.com/$PKG" \
    && : ::: \
    && if [ ! -d /srv/imposm3 ];then mkdir /srv/imposm3;fi \
    && cd /srv/imposm3 \
    && : :: imposm3: search latest artefacts and SHA files \
    && rel_url=$(curl -s  https://api.github.com/repos/$PKG/releases \
                |grep "$PKG/releases/"|grep '"url"'|awk '{print $2}' \
                |head -n1|sed -e 's/"\|,//g') \
    && : arch=$( uname -m|sed -re "s/x86_64/amd64/g" ) \
    && urls="$(do_curl -s -H "Authorization: token $GITHUB_PAT" \
        "$rel_url" \
        | grep browser_download_url | cut -d "\"" -f 4\
        | egrep -i "($(uname -s).*$arch|sha)" )" \
    && : :: imposm3: download and unpack artefacts \
    && for u in $urls;do \
        do_curl -sLO $u \
        && tar xvf "$(basename $u)" --strip-components=1>/dev/null \
        && rm -f "$(basename $u)";
    done \
    && ln -sf $(pwd)/imposm /usr/local/bin \
    && ln -sf $(pwd)/imposm3 /usr/local/bin \
    && chmod +x /srv/imposm3/imposm
}
install;ret=$?;if [ "x$ret" != "x0" ];then SDEBUG=1 install;fi;exit $ret
# vim:set et sts=4 ts=4 tw=0:
