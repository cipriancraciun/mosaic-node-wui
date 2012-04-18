#!/dev/null

if ! test "${#}" -eq 0 ; then
	echo "[ee] invalid arguments; aborting!" >&2
	exit 1
fi

if ! test -e "${_outputs}" ; then
	mkdir -- "${_outputs}"
fi

if test -e "${_outputs}/package" ; then
	chmod -R +w -- "${_outputs}/package"
	rm -R -- "${_outputs}/package"
fi
if test -e "${_outputs}/package.tar.gz" ; then
	chmod +w -- "${_outputs}/package.tar.gz"
	rm -- "${_outputs}/package.tar.gz"
fi
if test -e "${_outputs}/package.mvn" ; then
	chmod -R a+w -- "${_outputs}/package.mvn"
	rm -R -- "${_outputs}/package.mvn"
fi

mkdir -- "${_outputs}/package"
mkdir -- "${_outputs}/package/bin"
mkdir -- "${_outputs}/package/lib"

mkdir -- "${_outputs}/package/lib/node"
find "${_sources}" -type f \( -name "*.js" -o -name "*.dust" -o -name '*.json' -o -name '*.yaml' -o -name '*.py' \) -print \
| while read _source_path ; do
	cp -t "${_outputs}/package/lib/node" -- "${_source_path}"
done

mkdir "${_outputs}/package/lib/static"
find "${_static}" -type f \( -not -name ".*" \) -print \
| while read _static_path ; do
	cp -t "${_outputs}/package/lib/static" -- "${_static_path}"
done

cp -R -T -- "${_workbench}/node_modules" "${_outputs}/package/lib/node_modules"

mkdir -- "${_outputs}/package/lib/scripts"

cat >"${_outputs}/package/lib/scripts/_do.sh" <<'EOS'
#!/bin/bash

set -e -E -u -o pipefail || exit 1

_self_basename="$( basename -- "${0}" )"
_self_realpath="$( readlink -e -- "${0}" )"
cd "$( dirname -- "${_self_realpath}" )"
cd ../..
_package="$( readlink -e -- . )"
cmp -s -- "${_package}/lib/scripts/_do.sh" "${_self_realpath}"
test -e "${_package}/lib/scripts/${_self_basename}.bash"

_PATH="${_package}/bin:${_package}/lib/applications-elf:${PATH}"

_node_bin="$( PATH="${_PATH}" type -P -- node || true )"
if test -z "${_node_bin}" ; then
	echo "[ee] missing \`node\` (Node.JS interpreter) executable in path: \`${_PATH}\`; ignoring!" >&2
	exit 1
fi

_node_sources="${_package}/lib/node"
_node_args=()
_node_env=(
		PATH="${_PATH}"
		NODE_PATH="${_package}/lib/node:${_package}/lib/node_modules"
)

if test "${#}" -eq 0 ; then
	. "${_package}/lib/scripts/${_self_basename}.bash"
else
	. "${_package}/lib/scripts/${_self_basename}.bash" "${@}"
fi

echo "[ee] script \`${_self_main}\` should have exited..." >&2
exit 1
EOS

chmod +x -- "${_outputs}/package/lib/scripts/_do.sh"

for _script_name in "${_package_scripts[@]}" ; do
	test -e "${_scripts}/${_script_name}" || continue
	if test -e "${_scripts}/${_script_name}.bash" ; then
		_script_path="${_scripts}/${_script_name}.bash"
	else
		_script_path="$( dirname -- "$( readlink -e -- "${_scripts}/${_script_name}" )" )/${_script_name}.bash"
	fi
	cp -T -- "${_script_path}" "${_outputs}/package/lib/scripts/${_script_name}.bash"
	ln -s -T ./_do.sh "${_outputs}/package/lib/scripts/${_script_name}"
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
	"version" : "${_package_version}",
	"maintainer" : "mosaic-developers@lists.info.uvt.ro",
	"description" : "mOSAIC Node WebUI",
	"directories" : [ "bin", "lib" ],
	"depends" : [
		"mosaic-nodejs-0.6.15"
	]
}
EOS

chmod -R a+rX-w -- "${_outputs}/package"

tar -czf "${_outputs}/package.tar.gz" -C "${_outputs}/package" .

mkdir -- "${_outputs}/package.mvn"

cat >"${_outputs}/package.mvn/pom.xml" <<EOS
<?xml version="1.0" encoding="UTF-8"?>

<project
			xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
			xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd">
	<modelVersion>4.0.0</modelVersion>
	
	<groupId>eu.mosaic_cloud.packages</groupId>
	<artifactId>${_package_name}</artifactId>
	<version>${_package_version}</version>
	<packaging>pom</packaging>
	
	<build>
		<plugins>
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-assembly-plugin</artifactId>
				<version>\${versions.plugins.assembly}</version>
				<configuration>
					<descriptors>
						<descriptor>./assembly.xml</descriptor>
					</descriptors>
					<formats>
						<format>tar.bz2</format>
					</formats>
					<tarLongFileMode>gnu</tarLongFileMode>
				</configuration>
				<executions>
					<execution>
						<phase>package</phase>
						<goals>
							<goal>single</goal>
						</goals>
					</execution>
				</executions>
			</plugin>
		</plugins>
	</build>
	
	<distributionManagement>
		<repository>
			<id>developers.mosaic-cloud.eu-releases</id>
			<url>http://developers.mosaic-cloud.eu/artifactory/mosaic</url>
		</repository>
		<snapshotRepository>
			<id>developers.mosaic-cloud.eu-snapshots</id>
			<url>http://developers.mosaic-cloud.eu/artifactory/mosaic</url>
			<uniqueVersion>false</uniqueVersion>
		</snapshotRepository>
	</distributionManagement>
	
	<properties>
		<versions.plugins.assembly>2.2.2</versions.plugins.assembly>
		<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
	</properties>
	
</project>
EOS

cat >"${_outputs}/package.mvn/assembly.xml" <<EOS
<?xml version="1.0" encoding="UTF-8"?>

<assembly
			xmlns="http://maven.apache.org/plugins/maven-assembly-plugin/assembly/1.1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
			xsi:schemaLocation="http://maven.apache.org/plugins/maven-assembly-plugin/assembly/1.1.2 http://maven.apache.org/xsd/assembly-1.1.2.xsd">
	
	<id>\${os.name}-\${os.arch}</id>
	
	<fileSets>
		<fileSet>
			<directory>\${project.basedir}/../package</directory>
			<outputDirectory>/</outputDirectory>
			<excludes>
				<exclude>pkg.json</exclude>
			</excludes>
			<useDefaultExcludes>false</useDefaultExcludes>
		</fileSet>
	</fileSets>
	
</assembly>
EOS

env "${_mvn_env[@]}" "${_mvn_bin}" -f "${_mvn_pkg_pom}" "${_mvn_args[@]}" assembly:single

exit 0
