#!/bin/bash
#!/bin/bash
# vim:set ts=4 sw=4 noexpandtab:
#
# \brief General bitbake build init script called from project specific init script
# \description This script realizes non project specific initializations for the hipos
#              layer. It is sourced by several project specific build environment.
# 
# \pre log (function) is available
# \pre check_file (function) is available
# \pre SCRIPT_SOURCED (variable) true/false


#############################

# Default layers for bitbake.
# Use a project specific adaptions in $(INIT_SCRIPT_NAME} located in the root repository
BB_LAYERS_INCLUDED="\
	meta-hipos \
	meta-fsl-arm \
	meta-fsl-arm-extra \
	meta-fsl-demos \
	meta-java \
	meta-qt5 \
	meta-angstrom \
	meta-openembedded/meta-oe \
	meta-openembedded/meta-systemd \
	meta-openembedded/meta-multimedia \
	meta-openembedded/meta-networking \
	meta-openembedded/meta-python \
	meta-openembedded/meta-efl \
	meta-openembedded/meta-gnome \
	meta-openembedded/meta-xfce \
	openembedded-core/meta \
"

BB_BUILD_DIR_BASE=build
BB_BUILD_CONFIG=" "

update_bblayers_conf()
{
	# generate layer conf from template

	local BB_LAYER_CONF_TEMPLATE="hipos-base/bblayers.conf.template"
	local BB_LAYER_CONF="${BB_BUILD_DIR_BASE}/conf/bblayers.conf"

	log "I: generating ${BB_LAYER_CONF}"

	check_file ${BB_LAYER_CONF_TEMPLATE} &&

	{
		echo -e "# WARNING:\n# This file is automatically generated by ${INIT_SCRIPT_NAME}\n# Changes should be made in ${BB_LAYER_CONF_TEMPLATE}\n#\n#" &&
		cat ${BB_LAYER_CONF_TEMPLATE} &&

		echo  "BBLAYERS = \" \\" &&

		local layer &&
		for layer in $BB_LAYERS_INCLUDED; do
			if [[ "${layer:0:1}" = "/" ]]; then
				echo -e "\t$layer \\"
			else
			   	echo -e "\t$BB_BASE_DIR/$layer \\"
		   	fi
		done &&

		echo "\""
	} >	${BB_LAYER_CONF} ||
	{ log "E: generating ${BB_LAYER_CONF} failed"; return 1; }
}

update_local_conf()
{
	# generate local.conf from template
	# optional: apply local settings made in private.conf
	# (local.conf is tracked via git and thus not truly local)

	local LOCAL_CONF="${BB_BUILD_DIR_BASE}/conf/local.conf"
	local LOCAL_CONF_TEMPLATE="hipos-base/local.conf.template"
	local PRIVATE_CONF="${BB_BUILD_DIR_BASE}/conf/private.conf"

	log "I: generating ${LOCAL_CONF}"

	check_file ${LOCAL_CONF_TEMPLATE} &&
	echo -e "# WARNING:\n# This file is automatically generated by ${INIT_SCRIPT_NAME}\n# Changes should be made in ${LOCAL_CONF_TEMPLATE} and/or ${PRIVATE_CONF} ${BB_BUILD_CONFIG}\n#\n#" > ${LOCAL_CONF}
	if [ -f ${PRIVATE_CONF} ]; then
		check_file hipos-base/do_private_conf.awk &&
		if [ -f "$BB_BUILD_CONFIG" ]; then
			awk -f hipos-base/do_private_conf.awk ${BB_BUILD_CONFIG} ${LOCAL_CONF_TEMPLATE} > ${LOCAL_CONF}.tmp &&
			awk -f hipos-base/do_private_conf.awk ${PRIVATE_CONF} ${LOCAL_CONF}.tmp >> ${LOCAL_CONF} &&
			rm -f ${LOCAL_CONF}.tmp
		else
			awk -f hipos-base/do_private_conf.awk ${PRIVATE_CONF} ${LOCAL_CONF_TEMPLATE} >> ${LOCAL_CONF}
		fi
	else
		if [ -f "$BB_BUILD_CONFIG" ]; then
			check_file hipos-base/do_private_conf.awk &&
			awk -f hipos-base/do_private_conf.awk ${BB_BUILD_CONFIG} ${LOCAL_CONF_TEMPLATE} >> ${LOCAL_CONF}
		else
			log "I: ${PRIVATE_CONF} not found, only ${LOCAL_CONF_TEMPLATE} is used" &&
			cat ${LOCAL_CONF_TEMPLATE} >> ${LOCAL_CONF}
		fi
	fi ||
	{ log "E: generating ${LOCAL_CONF} failed"; return 1; }
}

update_submodules()
{
	log "I: updating submodules (OE layers + bitbake)"

	"${GIT}" submodule init &&
	"${GIT}" submodule sync &&
	"${GIT}" submodule update ||
	{ log "E: updating submodules failed"; return 1; }
}

hipos_base_init()
{
	local BB_LINK="openembedded-core/bitbake"
	local BB_BASE_DIR="`pwd`"
	local SETUP_SCRIPT="setup-$BB_BUILD_DIR_BASE.sh"

	test -h "${BB_LINK}" && rm -f "$BB_LINK" # otherwise init submodule could fail

	update_submodules &&

	mkdir -p ${BB_BUILD_DIR_BASE}/conf &&

	if [ ! -h "${BB_LINK}" ]; then
		ln -s "../bitbake" "${BB_LINK}" ||
		{ log "E: cannot set link to bitbake in $BB_LINK"; return 1; }
	fi &&

	update_bblayers_conf &&
	update_local_conf &&

	echo -e "bitbake() { trap popd SIGINT; pushd ${BB_BASE_DIR}/${BB_BUILD_DIR_BASE}; "'`which bitbake` $*; local ret=$?; popd; return $ret; }\n' ". ${BB_BASE_DIR}/openembedded-core/oe-init-build-env ${BB_BASE_DIR}/${BB_BUILD_DIR_BASE}" > "${SETUP_SCRIPT}" &&
	chmod +x ${SETUP_SCRIPT} &&

	if ${SCRIPT_SOURCED}; then
		. ${SETUP_SCRIPT} || 
		{ log "E: sourcing ${SETUP_SCRIPT} failed"; return 1; }
		echo -e "***"
		echo -e "***"
		echo -e "***    You can now start building:"
		echo -e "***"
		echo -e "***    $ bitbake \e[00;36m<target>\e[00m"
		echo -e "***"
	else
		echo -e "***"
		echo -e "***"
		echo -e "***    You have to run the following prior build:"
		echo -e "***"
		echo -e "***    $ \e[00;36msource ${BB_BASE_DIR}/${SETUP_SCRIPT}\e[00m"
		echo -e "***"
		echo -e "***"

		exit 0
	fi
}

