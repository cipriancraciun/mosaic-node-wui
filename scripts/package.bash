#!/dev/null

if ! test "${#}" -eq 0 ; then
	echo "[ee] invalid arguments; aborting!" >&2
	exit 1
fi

echo "[ii] packaging ${_package_name}..." >&2

_outputs="$( readlink -f -- ./.outputs )"
if ! test -e "${_outputs}" ; then
	mkdir "${_outputs}"
fi

if test -e "${_outputs}/package" ; then
	rm -R "${_outputs}/package"
fi
if test -e "${_outputs}/package.tar.gz" ; then
	rm "${_outputs}/package.tar.gz"
fi

mkdir "${_outputs}/package"
mkdir "${_outputs}/package/bin"
mkdir "${_outputs}/package/lib"

mkdir "${_outputs}/package/lib/node"
find ./sources -type f \( -name "*.js" -o -name "*.dust" -o -name '*.json' -o -name '*.yaml' -o -name '*.py' \) -print \
| while read _source ; do
	cp -t "${_outputs}/package/lib/node" "${_source}"
done

mkdir "${_outputs}/package/lib/static"
find ./static -type f \( -not -name ".*" \) -print \
| while read _static ; do
	cp -t "${_outputs}/package/lib/static" "${_static}"
done

cp -RT "${_npm_prefix}" "${_outputs}/package/lib/npm"

mkdir "${_outputs}/package/lib/scripts"

cat >"${_outputs}/package/lib/scripts/do.sh" <<'EOS'
#!/bin/bash

set -e -E -u -o pipefail || exit 1

_self_basename="$( basename -- "${0}" )"
_self_realpath="$( readlink -e -- "${0}" )"
cd "$( dirname -- "${_self_realpath}" )"
cd ../..
_package="$( readlink -e -- . )"
cmp -s -- "${_package}/lib/scripts/do.sh" "${_self_realpath}"
test -e "${_package}/lib/scripts/${_self_basename}.bash"

_PATH="${_package}/bin:${_package}/lib/applications-elf:${PATH}"

_node="$( PATH="${_PATH}" type -P -- node || true )"
if test -z "${_node}" ; then
	echo "[ww] missing \`node\` (Node.JS interpreter) executable in path: \`${_PATH}\`; ignoring!" >&2
	_node=node
fi

_node_sources="${_package}/lib/node"
_node_args=()
_node_env=(
	PATH="${_PATH}"
	NODE_PATH="${_package}/lib/node:${_package}/lib/npm/node_modules"
)

if test "${#}" -eq 0 ; then
	. "${_package}/lib/scripts/${_self_basename}.bash"
else
	. "${_package}/lib/scripts/${_self_basename}.bash" "${@}"
fi

echo "[ee] script \`${_self_main}\` should have exited..." >&2
exit 1
EOS

chmod +x -- "${_outputs}/package/lib/scripts/do.sh"

for _script_path in ./scripts/run-node-wui.bash ; do
	_script_name="$( basename -- "${_script_path}" .bash )"
	cp -T "${_script_path}" "${_outputs}/package/lib/scripts/${_script_name}.bash"
	ln -s -T ./do.sh "${_outputs}/package/lib/scripts/${_script_name}"
	cat >"${_outputs}/package/bin/${_package_name}--${_script_name}" <<EOS
#!/bin/bash
if test "\${#}" -eq 0 ; then
	exec "\$( dirname -- "\$( readlink -e -- "\${0}" )" )/../lib/scripts/${_script_name}"
else
	exec "\$( dirname -- "\$( readlink -e -- "\${0}" )" )/../lib/scripts/${_script_name}" "\${@}"
fi
EOS
	chmod +x -- "${_outputs}/package/bin/${_package_name}--${_script_name}"
done

cat >"${_outputs}/package/pkg.json" <<EOS
{
	"package" : "${_package_name}",
	"version" : "${_package_version}.$( date '+%Y%m%d.%H%M%S' )",
	"maintainer" : "mosaic-developers@lists.info.uvt.ro",
	"description" : "mOSAIC Node WebUI",
	"directories" : [ "bin", "lib" ],
	"depends" : [
		"mosaic-nodejs"
	]
}
EOS

tar -czf "${_outputs}/package.tar.gz" -C "${_outputs}/package" .

exit 0
