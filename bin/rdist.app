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
APP_src  = ( /htapps/test.babel/mdp-tools )
APP_dest = ( /htapps/babel/mdp-tools )

#
# Release instructions
#
( ${APP_src} ) -> ( ${NASMACC} ${NASICTC} )
        install -oremove ${APP_dest};
        except_pat ( \\.git config.yaml$ );
        notify lit-cs-groove@umich.edu ;
