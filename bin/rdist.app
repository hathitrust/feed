#
# RDIST Application Distribution File
#
# PURPOSE: deploy application from test.babel.hathitrust.org to production
#
# Destination Servers
#
NASMACC = ( nas-macc.umdl.umich.edu )
NASICTC = ( nas-ictc.umdl.umich.edu )

#
# File Directories to be released (source) and (destination)
#
APP_src  = ( /htapps/test.babel/feed )
APP_dest = ( /htapps/babel/feed )

#
# Release instructions
#
( ${APP_src} ) -> ( ${NASMACC} ${NASICTC} )
### no remove flag
#       dry run
#        install -overify ${APP_dest};
        install ${APP_dest};
        except_pat ( \\.git config.yaml );
### with remove flag
#       dry run
#        install -overify -oremove ${APP_dest};
#        install -oremove ${APP_dest};
#        except_pat ( \\.git /etc /var gpg );
        notify lit-cs-ingest@umich.edu ;

