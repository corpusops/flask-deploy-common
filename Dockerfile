ARG BASE=corpusops/ubuntu-bare:bionic
FROM $BASE
ENV PYTHONUNBUFFERED 1
ENV DEBIAN_FRONTEND=noninteractive
ARG TZ=Europe/Paris
ARG BUILD_DEV=
ARG LANG=fr_FR.UTF-8
ENV LANG=$LANG
ENV LC_ALL=$LANG
ARG PY_VER=3.6
# See https://github.com/nodejs/docker-node/issues/380
ARG GPG_KEYS=B42F6819007F00F88E364FD4036A9C25BF357DD4
ARG GPG_KEYS_SERVERS="hkp://p80.pool.sks-keyservers.net:80 hkp://ipv4.pool.sks-keyservers.net hkp://pgp.mit.edu:80"

WORKDIR /code
ADD apt.txt /code/

# setup project timezone, dependencies, user & workdir, gosu
RUN bash -c 'set -ex \
    && : "set correct timezone" \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && : "install packages" \
    && apt-get update -qq \
    && apt-get install -qq -y $(grep -vE "^\s*#" /code/apt.txt  | tr "\n" " ") \
    && apt-get clean all && apt-get autoclean \
    && : "project user & workdir" \
    && useradd -ms /bin/bash flask --uid 1000'

ARG WITH_IMPOSM=
ENV WITH_IMPOSM=$WITH_IMPOSM
ADD --chown=flask:flask sys/add_*sh /code/sys/
RUN bash -exc ': \
    && if [[ -n "$WITH_IMPOSM" ]];then ./sys/add_imposm.sh;fi \
    '

ARG PIP_SRC=/code/lib
ENV PIP_SRC=$PIP_SRC
ADD --chown=flask:flask Pipfile* /code/
ADD --chown=flask:flask \
    setup.* *.ini *.rst *.md *.txt LICENSE \
    /code/
ADD --chown=flask:flask lib ${PIP_SRC}/
ADD --chown=flask:flask src /code/src/
RUN bash -exc ': \
    && find /code -not -user flask \
    | while read f;do chown flask:flask "$f";done \
    && gosu flask:flask bash -euxc "python${PY_VER} -m venv venv \
    && venv/bin/pip install -U --no-cache-dir setuptools wheel pipenv \
    && if [ -e ./requirements.txt ];then \
        venv/bin/pip install -U --no-cache-dir -r ./requirements.txt; \
    fi \
    && if [[ -n \"$BUILD_DEV\" ]];then \
        if [ -e ./requirements-dev.txt ];then \
            venv/bin/pip install -U --no-cache-dir \
                -r ./requirements.txt \
                -r ./requirements-dev.txt;\
        fi \
    fi \
    && if [ -e Pipfile ];then \
        : \
        && pipenv_args=\"\" \
        && . venv/bin/activate &>/dev/null \
        && if [[ -n \"$BUILD_DEV\" ]];then \
            pipenv_args=\"--dev\"; \
        fi \
        && pipenv install \${pipenv_args}; \
    fi \
    && pip install -e . \
    "'

ADD --chown=flask:flask tests /code/tests/
ADD sys                            /code/sys
ADD local/flask-deploy-common/     /code/local/flask-deploy-common/
RUN bash -exc ': \
    && cd /code && mkdir init data \
    && find /code -not -user flask \
    | while read f;do chown flask:flask "$f";done \
    && cp -frnv /code/local/flask-deploy-common/sys/* sys \
    && cp -frnv sys/* init \
    && ln -sf $(pwd)/init/init.sh /init.sh'

CMD "/init.sh"
