#!/dev/null

if test "${#}" -ge 1 ; then
	_npm_args+=( "${@}" )
fi

if ! test -e "${_npm_prefix}" ; then
	mkdir "${_npm_prefix}"
fi

if test "${#_npm_args[@]}" -eq 0 ; then
	exec env "${_npm_env[@]}" "${_npm}"
else
	exec env "${_npm_env[@]}" "${_npm}" "${_npm_args[@]}"
fi
