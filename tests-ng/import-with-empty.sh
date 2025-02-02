#!/usr/bin/env bash
# author: deadc0de6 (https://github.com/deadc0de6)
# Copyright (c) 2019, deadc0de6
#
# test import new dotfiles with empty dst/src on existing dotfiles
# returns 1 in case of error
#

# exit on first error
set -e

# all this crap to get current path
rl="readlink -f"
if ! ${rl} "${0}" >/dev/null 2>&1; then
  rl="realpath"

  if ! hash ${rl}; then
    echo "\"${rl}\" not found !" && exit 1
  fi
fi
cur=$(dirname "$(${rl} "${0}")")

#hash dotdrop >/dev/null 2>&1
#[ "$?" != "0" ] && echo "install dotdrop to run tests" && exit 1

#echo "called with ${1}"

# dotdrop path can be pass as argument
ddpath="${cur}/../"
[ "${1}" != "" ] && ddpath="${1}"
[ ! -d ${ddpath} ] && echo "ddpath \"${ddpath}\" is not a directory" && exit 1

export PYTHONPATH="${ddpath}:${PYTHONPATH}"
bin="python3 -m dotdrop.dotdrop"
hash coverage 2>/dev/null && bin="coverage run -a --source=dotdrop -m dotdrop.dotdrop" || true

echo "dotdrop path: ${ddpath}"
echo "pythonpath: ${PYTHONPATH}"

# get the helpers
source ${cur}/helpers

echo -e "$(tput setaf 6)==> RUNNING $(basename $BASH_SOURCE) <==$(tput sgr0)"

################################################################
# this is the test
################################################################

# dotdrop directory
basedir=`mktemp -d --suffix='-dotdrop-tests' || mktemp -d`
echo "[+] dotdrop dir: ${basedir}"
echo "[+] dotpath dir: ${basedir}/dotfiles"
# the temp directory
tmpd=`mktemp -d --suffix='-dotdrop-tests' || mktemp -d`

clear_on_exit "${basedir}"
clear_on_exit "${tmpd}"

# create a dotfile
dftoimport="${tmpd}/a_dotfile"
echo 'some content' > ${dftoimport}

# create the config file
cfg="${basedir}/config.yaml"
cat > ${cfg} << _EOF
config:
  backup: true
  create: true
  dotpath: dotfiles
dotfiles:
  f_x:
    src: /tmp/x
    dst:
  f_y:
    src:
    dst: /tmp/y
  f_z:
    src:
    dst:
  f_l:
    src:
    dst:
    link: link
  f_lc:
    src:
    dst:
    link: link_children
profiles:
  p1:
    dotfiles:
    - f_x
    - f_y
    - f_z
    - f_l
    - f_lc
_EOF

echo "[+] import"
cd ${ddpath} | ${bin} import -f -c ${cfg} -p p1 --verbose ${dftoimport}
[ "$?" != "0" ] && exit 1

echo "[+] install"
cd ${ddpath} | ${bin} install -c ${cfg} -f -p p1 --verbose | grep '^5 dotfile(s) installed.$'
rm -f ${dftoimport}
cd ${ddpath} | ${bin} install -c ${cfg} -f -p p1 --verbose | grep '^6 dotfile(s) installed.$'

nb=`cd ${ddpath} | ${bin} files -c ${cfg} -p p1 --verbose | grep '^[a-zA-Z]' | grep -v '^Dotfile(s)' | wc -l`
[ "${nb}" != "6" ] && echo "error in dotfile list (${nb} VS 6)" && exit 1

#cat ${cfg}

echo "OK"
exit 0
