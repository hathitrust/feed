# Changes from local pairtree:
#
# safe_make_path needs to be able to do it remotely
# stage_path changes to include remote host
# checks in stage need to check directory existence on remote host
# validate needs to parse remote METS
# validate needs to run checksum remotely
# move needs to run remotely
# object path is probably OK
# symlink_if_needed/check_existing_link needs to check existence remotely & run remotely
#
# rsync instead of cp in stage

