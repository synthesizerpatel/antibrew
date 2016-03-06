#!/bin/bash -e
#
# PROGRAM: antibrew.sh
# AUTHOR-: nar@remix.net
# DATE---: 2016-03-05
# DESC---: Download and compile and install built tools without
#          using brew. Because brew is super bad.
# 
########################################################################

PACKAGES="\
	https://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.xz \
	https://ftp.gnu.org/gnu/automake/automake-1.15.tar.xz \
	https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.xz \
	https://ftp.gnu.org/gnu/m4/m4-1.4.16.tar.xz \
	https://ftp.gnu.org/gnu/autoconf-archive/autoconf-archive-2015.09.25.tar.xz \
	https://ftp.gnu.org/gnu/libiconv/libiconv-1.14.tar.gz \
	http://git.savannah.gnu.org/cgit/readline.git/snapshot/readline-master.tar.gz \
	https://ftp.gnu.org/gnu/readline/readline-6.3.tar.gz \
	http://gnu.mirror.constant.com/sed/sed-4.2.tar.gz \
	https://www.sqlite.org/2016/sqlite-autoconf-3110100.tar.gz \
	ftp://ftp.gnu.org/gnu/gdbm/gdbm-1.11.tar.gz"


safe_filename() {
	echo "$1" | /usr/bin/sed -E -e "s/[^a-zA-Z]/_/g"
}

alias pushd='pushd >/dev/null 2>&1'
alias popd='popd >/dev/null 2>&1'

mark_built() {
	if [ -e ".built" ]; then
		echo "built"
		return 0
	else
		echo "building.."
		return 1
	fi
}

do_build() {
	D=$(tar jvxf "$1" 2>&1 | /usr/bin/sed -E -e 's/^x //g' -e 's/\/.*//g' | sort | uniq)
	echo ">> $D"
	if [ -e "${D}/setup.py" ]; then
		python_build "${D}" 
	elif [ -e "${D}/configure.ac" ]; then
		autotools_build "${D}"
		return
	fi
}

python_build() {
	pushd "${1}"
	if ! mark_built; then
		echo "building python.."
		python setup.py build >build.log
		python setup.py install >>build.log
		RET=$?
	fi
	popd 
	return ${RET}
}

autotools_build() {
	pushd "${1}"
	if ! mark_built; then
		if [ "${1/-*/}" = "libtool" ]; then
			./configure \
				--disable-dependency-tracking \
				--program-prefix=g 
		else 
			echo "compiling autotools project.."
			if [[ "${1}" != auto* ]]; then
				../autogen.sh 
			fi
			./configure 
		fi
		make 
		sudo make install && touch . 
		RET=$?	
	fi
	popd
	return ${RET}
}

function stdred() (
	PACKAGE="${2/-*/}"
    set -o pipefail;
    ("$@" 2>&1>&3 | sed $'s,.*,\e[31m&\e[m,' >&2) 3>&1 | sed $'s,.*,\e[93m&\e[m,' \
		| sed "s/^\(.*\)/${PACKAGE}: \\1/"
)

for x in ${PACKAGES}; do
	SAFE=$(safe_filename $(echo "${x}" | /usr/bin/sed -e 's/.*\///g'))
	echo "* Processing $(basename ${x})"
	if [ ! -e ".${SAFE}.done" ]; then
		if curl -# --progress -OL "${x}"; then 
			touch ".${SAFE}.done"
		fi
	fi
	stdred do_build "$(basename ${x})"
	echo
done
