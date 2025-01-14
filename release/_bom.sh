#!/bin/bash

function generate_api_jars {
	mkdir -p "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	mkdir -p api-jar api-sources-jar

	local enforce_version_artifacts=$(lc_get_property "${_PROJECTS_DIR}/liferay-portal-ee/modules/source-formatter.properties" source.check.GradleDependencyArtifactsCheck.enforceVersionArtifacts | sed -e "s/,/\\n/g")

	for artifact in ${enforce_version_artifacts}
	do
		if (! echo "${artifact}" | grep -q "com.fasterxml") &&
		   (! echo "${artifact}" | grep -q "com.liferay.alloy-taglibs:alloy-taglib:") &&
		   (! echo "${artifact}" | grep -q "com.liferay.alloy-taglibs:alloy-taglib:") &&
		   (! echo "${artifact}" | grep -q "com.liferay.portletmvc4spring:com.liferay.portletmvc4spring.test:") &&
		   (! echo "${artifact}" | grep -q "com.liferay:biz.aQute.bnd.annotation:") &&
		   (! echo "${artifact}" | grep -q "io.swagger") &&
		   (! echo "${artifact}" | grep -q "javax") &&
		   (! echo "${artifact}" | grep -q "org.jsoup") &&
		   (! echo "${artifact}" | grep -q "org.osgi")
		then
			continue
		fi

		local group_path=$(echo ${artifact%%:*} | sed -e "s#[.]#/#g")

		if [ "${group_path}" == "com/fasterxml/jackson-dataformat" ]
		then
			group_path="com/fasterxml/jackson/dataformat"
		fi

		local name=$(echo ${artifact} | sed -e "s/.*:\(.*\):.*/\\1/")
		local version=${artifact##*:}

		lc_log INFO "Downloading and unzipping https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}-sources.jar."

		lc_download "https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}-sources.jar"

		unzip -d api-sources-jar -o -q "${name}-${version}-sources.jar"

		rm -f "${name}-${version}-sources.jar"

		lc_log INFO "Downloading and unzipping https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}.jar."

		lc_download "https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}.jar"

		unzip -d api-sources-jar -o -q "${name}-${version}.jar"

		rm -f "${name}-${version}.jar"

		#
		# TODO Finish logic from https://github.com/liferay/liferay-portal-ee/blob/release-2023.q4/modules/releng.gradle#L1275
		#
	done
}

function generate_fake_api_jars {
	mkdir -p "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	local base_version=$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.profile-dxp.properties "release.info.version").u$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.trivial")

	lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/release.dxp.api/${base_version}/release.dxp.api-${base_version}.jar"
	lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/release.dxp.api/${base_version}/release.dxp.api-${base_version}-sources.jar"

	for jar_file in *.jar
	do
		mv "${jar_file}" $(echo "${jar_file}" | sed -e "s/${base_version}/${_DXP_VERSION}/g")
	done
}

function generate_poms {
	if (! echo "${_DXP_VERSION}" | grep -q "q")
	then
		lc_log INFO "BOMs are only generated for quarterly updates."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local base_version=$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.profile-dxp.properties "release.info.version").u$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.trivial")

	mkdir -p "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	for pom in release.dxp.bom release.dxp.bom.compile.only release.dxp.bom.third.party
	do
		lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/${pom}/${base_version}/${pom}-${base_version}.pom"

		sed -e "s#<version>${base_version}</version>#<version>${_DXP_VERSION}</version>#" < "${pom}-${base_version}.pom" | \
		sed -e "s#<connection>scm:git:git@github.com:liferay/liferay-portal.git</connection>#<connection>scm:git:git@github.com:liferay/liferay-dxp.git</connection>#" | \
		sed -e "s#<developerConnection>scm:git:git@github.com:liferay/liferay-portal.git</developerConnection>#<developerConnection>scm:git:git@github.com:liferay/liferay-dxp.git</developerConnection>#" | \
		sed -e "s#<tag>.*</tag>#<tag>${_DXP_VERSION}</tag>#" | \
		sed -e "s#<url>https://github.com/liferay/liferay-portal</url>#<url>https://github.com/liferay/liferay-dxp</url>#" > "${pom}-${_DXP_VERSION}.pom"

		rm -f "${pom}-${base_version}.pom"
	done
}