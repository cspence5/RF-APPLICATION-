#!/bin/ksh
stty echo
stty icrnl
stty tab0
stty onlcr
stty isig 
stty icanon 
stty iexten 
stty -echoprt

export TERM=vt100


bash $PKMS/custom/scripts/PRINT_Docs.sh 
stty -icrnl
stty -echo
stty -onlcr
stty -isig 
stty -icanon 
stty -iexten 
#stty echoprt

clear
