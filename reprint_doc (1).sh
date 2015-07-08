#!/bin/bash
export NLS_LANG=AMERICAN_AMERICA.UTF8
#set -v

########################################################################################
### Date        Author                Description
###
### 05/29/2015  Chris Spencer        SCR  - TCL PRINT
########################################################################################

function callfunction()
{

FUN_OUTPUT=`sqlplus -s $UPS_DB_USER/$UPS_DB_PSWD@$DBLOC << _EOF 
WHENEVER SQLERROR  Exit 1

set verify off;
set linesize 80;
set pagesize 60;
set feedback off;
set head off;
set serveroutput on;
set echo off;

declare

v_output varchar2(300);

begin

 ups_reprint_tcl('$OUTQ','$PTYPE','$INPUT','$printorgenerate',v_output);

dbms_output.put_line(v_output);

end;

/

exit;
<< _EOF
` 

export FUN_OUTPUT=`echo $FUN_OUTPUT | awk '{gsub(/" "/,""); print}'`

if [ "$FUN_OUTPUT" = "Y" ]; then
export errorMsg=""
else
export errorMsg="$FUN_OUTPUT"
fi

}













#function to paint fields onto the screen

function scrnpaint ()
{
   tput clear
   echo "  UPS PRINT TCL"
   echo "Workstation:"
   echo "$OUTQ"
   echo "Ctn(C)Wav(W)Pkt(K)Tot(T):"
   echo "$tdisplay"  
  #echo "$PKTCTN"
   #echo "$INPUT"
   #echo "rePrt(R)/reGen(G)"
   #echo "$printorgenerate"   
   echo "$errorMsg"
 #echo "$FUN_OUTPUT"

  if [ "$PKMS_USERTYPE" = "FIXED_STATION" ]; then
    
     echo ""
     echo ""
     echo ""
     echo ""
     echo ""
     echo ""
     echo ""
     echo ""
     echo ""
     echo ""
     echo ""
     echo ""
     echo "                            Function Keys "
     echo " E(e)=Exit, P(p)=Previous "
  fi
}

#function to validate work station

function acceptWS()
{

while [ "$FUN_OUTPUT" != "Y" ]
do
  
     
 
   scrnpaint
  
   tput cup 2 0

   read OUTQ
   
   export errorMsg=""

   if [ "$OUTQ" = "E" -o "$OUTQ" = "e" -o "$OUTQ" = "p" -o "$OUTQ" = "P" ]; then
     exit 0
   fi
# Call Function only if value is not null
   if [[ ! -z "$OUTQ" ]]; then
     callfunction
	if [ "$FUN_OUTPUT" != "Y" ]; then
	OUTQ=""
	fi
   fi
   
done
step=2

}


function acceptType()
{
while [ "$type_choice" != "Y" ]
do
   PTYPE=""
   scrnpaint

   tput cup 4 0

   read PTYPE
   
   export errorMsg=""
   
 

  if [ "$PTYPE" = "E" -o "$PTYPE" = "e" -o "$PTYPE" = "p" -o "$PTYPE" = "P" ]; then
   exit 0
   

  fi
# Call Function only if value is not null  
   if [ "$PTYPE" = "C" -o "$PTYPE" = "c" ]; then
    tdisplay="C#: "
    type_choice="Y"
   elif [ "$PTYPE" = "W" -o "$PTYPE" = "w" ]; then
    tdisplay="W#: "
   type_choice="Y"
   elif [ "$PTYPE" = "K" -o "$PTYPE" = "k" ]; then
   tdisplay="K#: "
   type_choice="Y"
   elif [ "$PTYPE" = "T" -o "$PTYPE" = "t" ]; then
   tdisplay="T#: "
   type_choice="Y"
   else 
   type_choice="N"    
   errorMsg="Invalid Choice"   	    
   
fi



done
step=3
}


#function to validate Pkt or Carton Number

function acceptInput()
{

while [ "$FUN_OUTPUT" != "Y" ]
do
   scrnpaint

   tput cup 4 3 

   read INPUT
   
   export errorMsg=""

   if [ "$INPUT" = "E" -o "$INPUT" = "e" -o "INPUT" = "p" -o "INPUT" = "P" ]; then
     exit 0
   fi

  # if [[  -z "$PKTCTN" ]] &&  [[ ! -z "$vPKTCTN" ]]; then
   #   PKTCTN=$vPKTCTN
  # fi
 
# Call Function only if value is not null  
   if [[ ! -z "$INPUT" ]]; then
     callfunction
        
	if [ "$FUN_OUTPUT" != "Y" ]; then
	   INPUT=""
       # else
           # vPKTCTN=$PKTCTN
	fi
   fi 

done
step=4
}

#function to validate Report Type

function printgenerate()
{




while [ "$FUN_OUTPUT" != "Y" ]
do
  #scrnpaint

   tput cup 7 0

   #read printorgenerate
   printorgenerate = "G"   

   export errorMsg=""

   if [ "$printorgenerate" = "E" -o "$printorgenerate" = "e" -o "$printorgenerate" = "p" -o "$printorgenerate" = "P" ]; then
     exit 0
   fi
# Call Function only if value is not null  
   if [[ ! -z "$printorgenerate" ]]; then
       
       callfunction
	if [ "$FUN_OUTPUT" != "Y" ]; then
        
	printorgenerate=""
	fi
   fi 

done


if [ "$FUN_OUTPUT" != "Y" ] || [ -z "$FUN_OUTPUT" ]; then
   export errorMsg="Request Failed"
  #OUTQ=""
   INPUT=""
   tdisplay=""
   PTYPE=""
   printorgenerate=""
   FUN_OUTPUT=""
   step=2
else
   export errorMsg="Request Success"
  #OUTQ=""
   tdisplay=""
   INPUT=""
   PTYPE=""
   type_choice=""
   printorgenerate=""
   FUN_OUTPUT=""
   tput clear
   scrnpaint
   step=2
fi


}

#Main program

tput clear

#Initialise variables

EDATE=`date +%d/%m/%y`

OUTQ=""
INPUT=""
PTYPE=""
FUN_OUTPUT=""
tdisplay=""
type_choice=""
printorgenerate=""
step=1

while [ "$step" != "E" ]
do

case $step
in
1)
acceptWS;
FUN_OUTPUT="N"
;;
2)
acceptType;
FUN_OUTPUT="N"
;;
3)
acceptInput;
FUN_OUTPUT="N"
;;
4)printgenerate;
FUN_OUTPUT="N"
;;
esac

done


#Request post OK

#set +x
#return to calling shell
