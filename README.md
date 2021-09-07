hipos-base
==========

This contains management info for use with top level repositories (f.e. DFE/HIPOS).

hipos-init.sh.template   has to be adapted (more layers) and placed into the root build project
bblayers.conf.template   layer config template merged with given layers
local.conf.template      local.conf template merged with private.conf

do_private_conf.awk      merge script for local.conf
init.sh                  generic layer init script to be sourced from hipos-init.sh

