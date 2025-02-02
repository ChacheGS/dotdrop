#!/usr/bin/env bash
# author: deadc0de6 (https://github.com/deadc0de6)
# Copyright (c) 2019, deadc0de6
#
# test compare ignore relative
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

# the dotfile to be imported
tmpd=`mktemp -d --suffix='-dotdrop-tests' || mktemp -d`

clear_on_exit "${basedir}"
clear_on_exit "${tmpd}"

# some files
mkdir -p ${tmpd}/{program,config,vscode}
touch ${tmpd}/program/a
touch ${tmpd}/config/a
touch ${tmpd}/vscode/extensions.txt
touch ${tmpd}/vscode/keybindings.json

# create the config file
cfg="${basedir}/config.yaml"
create_conf ${cfg} # sets token

# import
echo "[+] import"
cd ${ddpath} | ${bin} import -f --verbose -c ${cfg} ${tmpd}/program || exit 1
cd ${ddpath} | ${bin} import -f --verbose -c ${cfg} ${tmpd}/config || exit 1
cd ${ddpath} | ${bin} import -f --verbose -c ${cfg} ${tmpd}/vscode || exit 1

# add files on filesystem
echo "[+] add files"
touch ${tmpd}/program/b
touch ${tmpd}/config/b

# expects diff
echo "[+] comparing normal - diffs expected"
set +e
cd ${ddpath} | ${bin} compare -c ${cfg} --verbose
ret="$?"
echo ${ret}
[ "${ret}" = "0" ] && exit 1
set -e

# expects one diff
patt="b"
echo "[+] comparing with ignore (pattern: ${patt}) - no diff expected"
set +e
cd ${ddpath} | ${bin} compare -c ${cfg} --verbose --ignore=${patt}
[ "$?" != "0" ] && exit 1
set -e

# adding ignore in dotfile
cfg2="${basedir}/config2.yaml"
sed '/d_config:/a \ \ \ \ cmpignore:\n\ \ \ \ - "b"' ${cfg} > ${cfg2}
#cat ${cfg2}

# expects one diff
echo "[+] comparing with ignore in dotfile - diff expected"
set +e
cd ${ddpath} | ${bin} compare -c ${cfg2} --verbose
[ "$?" = "0" ] && exit 1
set -e

# adding ignore in dotfile
cfg2="${basedir}/config2.yaml"
sed '/d_config:/a \ \ \ \ cmpignore:\n\ \ \ \ - "b"' ${cfg} > ${cfg2}
sed -i '/d_program:/a \ \ \ \ cmpignore:\n\ \ \ \ - "b"' ${cfg2}
#cat ${cfg2}

# expects no diff
echo "[+] comparing with ignore in dotfile - no diff expected"
set +e
cd ${ddpath} | ${bin} compare -c ${cfg2} --verbose
[ "$?" != "0" ] && exit 1
set -e

# update files
echo touched > ${tmpd}/vscode/extensions.txt
echo touched > ${tmpd}/vscode/keybindings.json

# expect two diffs
echo "[+] comparing - diff expected"
set +e
cd ${ddpath} | ${bin} compare -c ${cfg} --verbose -C ${tmpd}/vscode
[ "$?" = "0" ] && exit 1
set -e

# expects no diff
echo "[+] comparing with ignore in dotfile - no diff expected"
sed '/d_vscode:/a \ \ \ \ cmpignore:\n\ \ \ \ - "extensions.txt"\n\ \ \ \ - "keybindings.json"' ${cfg} > ${cfg2}
set +e
cd ${ddpath} | ${bin} compare -c ${cfg2} --verbose -C ${tmpd}/vscode
[ "$?" != "0" ] && exit 1
set -e

####################
# test for #149
####################
mkdir -p ${tmpd}/.zsh
touch ${tmpd}/.zsh/somefile
mkdir -p ${tmpd}/.zsh/plugins
touch ${tmpd}/.zsh/plugins/someplugin

echo "[+] import .zsh"
cd ${ddpath} | ${bin} import -f -c ${cfg} ${tmpd}/.zsh

# no diff expected
echo "[+] comparing .zsh"
cd ${ddpath} | ${bin} compare -c ${cfg} --verbose -C ${tmpd}/.zsh --ignore=${patt}
[ "$?" != "0" ] && exit 1

# add some files
touch ${tmpd}/.zsh/plugins/ignore-1.zsh
touch ${tmpd}/.zsh/plugins/ignore-2.zsh

# expects diff
echo "[+] comparing .zsh with new files"
set +e
cd ${ddpath} | ${bin} compare -c ${cfg} --verbose -C ${tmpd}/.zsh
ret="$?"
echo ${ret}
[ "${ret}" = "0" ] && exit 1
set -e

# expects no diff
patt="plugins/ignore-*.zsh"
echo "[+] comparing with ignore (pattern: ${patt}) - no diff expected"
set +e
cd ${ddpath} | ${bin} compare -c ${cfg} --verbose -C ${tmpd}/.zsh --ignore=${patt}
[ "$?" != "0" ] && exit 1
set -e

# expects no diff
echo "[+] comparing with ignore in dotfile - no diff expected"
sed '/d_zsh:/a \ \ \ \ cmpignore:\n\ \ \ \ - "plugins/ignore-*.zsh"' ${cfg} > ${cfg2}
set +e
cd ${ddpath} | ${bin} compare -c ${cfg2} --verbose -C ${tmpd}/.zsh
[ "$?" != "0" ] && exit 1
set -e

echo "OK"
exit 0
