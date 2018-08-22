#! /bin/tcsh -f 

echo "This wrapper will use IRSA's API to take in an MDEX table, run through stf and output a table for both Source and Reject catalog.\n"
#TODO fix random exit error and do documentation on the wmfflag attempts
set wrapperDir = $PWD
set startTime = `date '+%m/%d/%Y %H:%M:%S'`
echo 
echo Wrapper Started at:
echo $startTime
echo
echo Version 1.2 
echo
echo This Wrapper will wrap around and run:
echo 1\) stf \(extracts cols of input MDEX table\)
echo 2\) IRSA api
echo 3\) stils \(http://www.star.bris.ac.uk/~mbt/stilts/sun256/tcatn-usage.html\)

#check hyphenated argument
@ i = 0
set rsyncSet = "false"
while ($i < $# + 1)
     #user input nameslist -nl argument
      if("$argv[$i]" == "-rsync") then
        echo Argument "-rsync" detected. Will rsync Tyto, Otus, and Athene.
        set rsyncSet = "true"
      endif
      @ i +=  1
end

#check mode and input arguments 
if ($# < 2) then #($# != 2 && $# != 3) then
        #Error handling
        #Too many or too little arguments       
        echo ""
        echo "ERROR: not enough arguments:"
        echo Mode 2 call:
        echo IRSA_api.tcsh 2 inputList.txt ParentDir/
        echo Mode 3 call:
        echo IRSA_api.tcsh 3 ParentDir/ TileName
        echo
        echo Exiting...
        exit
#Mode2 List Mode
else if ($1 == 2) then
	set InputsList = $2
        echo Inputs list ==  $InputsList
        echo
        #if directories dont exist, throw error
        if(! -f $InputsList) then
                echo ERROR: Input List file $InputsList doest not exist.
                echo
                echo Exiting...
                exit
        endif

	echo Going to Mode2
	echo
	goto Mode2
#Mode3 Single Tile Mode
else if ($1 == 3) then
        set InputTable = $2
        echo Input Table == $InputTable
        #if directories dont exist, throw error
        if(! -f $InputTable) then
		echo
                echo ERROR: $InputTable doest not exist.
                echo
                echo Exiting...
                exit
        endif

	echo Going to Mode3
	echo
        goto Mode3
else
        #Error handling
        #option 2/3 not second parameter. program exits.
	echo
        echo ERROR mode 2, or 3 not selected
        echo Mode 2 call:
        echo IRSA_api.tcsh 2 inputList.txt ParentDir/
        echo Mode 3 call:
        echo IRSA_api.tcsh 3 ParentDir/ TileName
        echo
        echo Exiting...
	exit
endif

#==============================================================================================================================

Mode2:
    
    foreach table (`cat $InputsList`)    
        echo ===================================== start IRSA_api wrapper loop iteration ======================================
     
        set mdexTable = `echo $table`

        echo "Current input MDEXTable == "$mdexTable
        echo Calling IRSA_api.tcsh Mode3 on $table 
	if($rsyncSet == "true") then
		(echo y | /Volumes/CatWISE1/ejmarchese/Dev/IRSAWrapper/IRSA_api.tcsh 3 $table -rsync) &
	else
		(echo y | /Volumes/CatWISE1/ejmarchese/Dev/IRSAWrapper/IRSA_api.tcsh 3 $table) &
	endif
	
	set maxInParallel = 12
        if(`ps -ef | grep IRSA_api | wc -l` > $maxInParallel + 1) then
                echo  More than $maxInParallel IRSA_api processes, waiting...
                while(`ps -ef | grep IRSA_api | wc -l` > $maxInParallel + 1)
                        sleep 1
                        #echo IM WATING
                        #do nothing
                end
                echo  Done waiting
        endif
		echo
                echo IRSA_api for \<INPUT_RA_DEC_HERE\> done
            
            echo ====================================== end IRSA_api wrapper loop iteration =======================================
    end

    #===============================================================================================================================================================

    #wait for background processes to finish
    wait
    echo IRSA_api wrapper finished
    echo
    goto Done

Mode3:	
	#full path to mdexTable file (gz)
        set mdexTable = $InputTable 
	set tempSize = `basename $mdexTable  | awk '{print length($0)}'`
        @ tempIndex = ($tempSize - 3 - 4)
	#does not include the .gz
        set edited_mdexTable = `basename $mdexTable | awk -v endIndex=$tempIndex '{print substr($0,0,endIndex)}'`
        set edit_mdexTablePATH = `dirname $mdexTable`
	set edited_mdexTablePATH = `cd $edit_mdexTablePATH && pwd`
	set RadecID = `echo $edited_mdexTable | awk '{print substr($0,0,8)}'`

        echo "Current input MDEXTable == "$mdexTable
        echo "Edited_Current input MDEXTable == "${edited_mdexTablePATH}//${edited_mdexTable}.tbl
        echo "RadecID == "$RadecID
	
	echo Unzipping $mdexTable to ${edited_mdexTablePATH}/${edited_mdexTable}.tbl
       #TODO gunzip not unzipping to thr right folder
	gunzip -f -c -k $mdexTable > ${edited_mdexTablePATH}/${edited_mdexTable}.tbl 
 
	#set stfTable = ${edited_mdexTablePATH}/${edited_mdexTable}_stf.tbl
	set stfTable = ${edited_mdexTablePATH}/${edited_mdexTable}_stf.tbl
	echo Calling stf on ${edited_mdexTablePATH}/${edited_mdexTable}.tbl
	echo stfTable == ${stfTable}
	((/Users/CatWISE/stf ${edited_mdexTablePATH}/${edited_mdexTable}.tbl 1 3 4 >  ${stfTable}) && echo "stf Done. Output: ${stfTable}") || echo "stf failed???" 
	
	set tempCoaddID = \'${RadecID}_ac51\'
	echo tempCoaddID == $tempCoaddID


       # Program Calls
	echo Calling IRSA api on ${stfTable} on AllWISE Source
	curl -F filename=@${stfTable} -F catalog=allwise_p3as_psd -F spatial=Upload -F uradius=2 -F outfmt=1 -F constraints=coadd_id=$tempCoaddID -F selcols=cc_flags,w1cc_map,w1cc_map_str,w2cc_map,w2cc_map_str,coadd_id "https://irsa.ipac.caltech.edu/cgi-bin/Gator/nph-query" -o ${edited_mdexTablePATH}/${RadecID}_allwise_Source_output.tbl
	echo Calling IRSA api on ${stfTable} on AllWISE Reject
	curl -F filename=@${stfTable} -F catalog=allwise_p3as_psr -F spatial=Upload -F uradius=2 -F outfmt=1 -F constraints=coadd_id=$tempCoaddID -F selcols=cc_flags,w1cc_map,w1cc_map_str,w2cc_map,w2cc_map_str,coadd_id "https://irsa.ipac.caltech.edu/cgi-bin/Gator/nph-query" -o ${edited_mdexTablePATH}/${RadecID}_allwise_Reject_output.tbl
	echo Concat the ${RadecID}_allwise_Source_output.tbl and ${RadecID}_allwise_Reject_output.tbl using stilts.
	/Users/marocco/bin/stilts/stilts tcatn nin=2 ifmt1=ipac in1=${edited_mdexTablePATH}/${RadecID}_allwise_Source_output.tbl ifmt2=ipac in2=${edited_mdexTablePATH}/${RadecID}_allwise_Reject_output.tbl omode=out out=${edited_mdexTablePATH}/${RadecID}_stilts_temp.tbl ofmt=ipac
	echo Match output ${RadecID}_stilts_temp.tbl to original ${edited_mdexTable} using stilts.
	/Users/marocco/bin/stilts/stilts tmatch2 ifmt1=ipac ifmt2=ipac omode=out out=${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl ofmt=ipac matcher=exact values1=source_id values2=source_id_01 join=all1 find=all in1=${mdexTable} in2=${edited_mdexTablePATH}/${RadecID}_stilts_temp.tbl
	echo DONE. Output: ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl 
	goto Mode3_Done #gzip_done

Done:
echo IRSA_api Mode: ${1} Done
set endTime = `date '+%m/%d/%Y %H:%M:%S'`
echo
echo Wrapper Mode: ${1} Ended at:
echo $endTime
exit

#Done section for gzipping rsyncing
Mode3_Done:
echo IRSA_api on ${RadecID} Mode: ${1} Done
set endTime = `date '+%m/%d/%Y %H:%M:%S'`
echo Deleting ${edited_mdexTablePATH}/${edited_mdexTable}.tbl 
rm -f ${edited_mdexTablePATH}/${edited_mdexTable}.tbl
echo NOTDeleting ${edited_mdexTablePATH}/${edited_mdexTable}_stf.tbl 
rm -f ${edited_mdexTablePATH}/${edited_mdexTable}_stf.tbl
echo Deleting ${edited_mdexTablePATH}/${RadecID}_stilts_temp.tbl 
rm -f ${edited_mdexTablePATH}/${RadecID}_stilts_temp.tbl
#echo removing ${edited_mdexTablePATH}/${RadecID}_allwise_Source_output.tbl
#rm -f ${edited_mdexTablePATH}/${RadecID}_allwise_Source_output.tbl
#echo removing ${edited_mdexTablePATH}/${RadecID}_allwise_Reject_output.tbl
#rm -f ${edited_mdexTablePATH}/${RadecID}_allwise_Reject_output.tbl
echo
	echo Gzipping and rm ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl
	gzip -f ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl
	rm -f ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl
	echo Done gzip on ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl
	#rsync step
	if($rsyncSet == "true") then
       	#rsync
	set CatWISEDir = ${edited_mdexTablePATH}
        echo running rsync on tile $RadecID
        set currIP = `dig +short myip.opendns.com @resolver1.opendns.com`
        echo current IP = $currIP
        if($currIP == "137.78.30.21") then #Tyto
                set otus_CatWISEDir = `echo $CatWISEDir | sed 's/CatWISE1/otus1/g'`
                set athene_CatWISEDir = `echo $CatWISEDir | sed 's/CatWISE1/athene1/g'`
                set otus_CatWISEDir = `echo $otus_CatWISEDir | sed 's/tyto/otus/g'`
                set athene_CatWISEDir = `echo $athene_CatWISEDir | sed 's/tyto/athene/g'`
                set otus_CatWISEDir = `echo $otus_CatWISEDir | sed 's/CatWISE3/otus3/g'`
                set athene_CatWISEDir = `echo $athene_CatWISEDir | sed 's/CatWISE3/athene3/g'`
                echo You are on Tyto!

               #Transfer Tyto CatWISE/ dir to Otus
                echo rsync Tyto\'s $CatWISEDir to Otus $otus_CatWISEDir
                ssh ${user}@137.78.80.75 "mkdir -p $otus_CatWISEDir"
                rsync -avu $CatWISEDir ${user}@137.78.80.75:$otus_CatWISEDir

               #Transfer Tyto CatWISE/ dir to Athene
                echo rsync Tyto\'s $CatWISEDir to Athene $athene_CatWISEDir
                ssh ${user}@137.78.80.72 "mkdir -p $athene_CatWISEDir"
                rsync -avu  $CatWISEDir ${user}@137.78.80.72:$athene_CatWISEDir
        else if($currIP == "137.78.80.75") then  #Otus
                set tyto_CatWISEDir = `echo $CatWISEDir | sed 's/otus3/CatWISE3/g'`
                set tyto_CatWISEDir = `echo $tyto_CatWISEDir | sed 's/otus/tyto/g'`
                set athene_CatWISEDir = `echo $CatWISEDir | sed 's/otus/athene/g'`
                echo You are on Otus!

               #Transfer Otus CatWISE/ dir to Tyto
                echo rsync Otus\'s $CatWISEDir to Tyto $tyto_CatWISEDir
                ssh ${user}@137.78.30.21 "mkdir -p $tyto_CatWISEDir"
                rsync -avu $CatWISEDir ${user}@137.78.30.21:$tyto_CatWISEDir

               #Transfer Otus CatWISE/ to Athene
                echo rsync Otus\'s $CatWISEDir to Athene $athene_CatWISEDir
                ssh ${user}@137.78.80.72 "mkdir -p $athene_CatWISEDir"
                rsync -avu  $CatWISEDir ${user}@137.78.80.72:$athene_CatWISEDir
        else if($currIP == "137.78.80.72") then #Athene
                set tyto_CatWISEDir = `echo $CatWISEDir | sed 's/athene3/CatWISE3/g'`
                set tyto_CatWISEDir = `echo $tyto_CatWISEDir | sed 's/athene/tyto/g'`
                set otus_CatWISEDir = `echo $CatWISEDir | sed 's/athene/otus/g'`
                echo You are on Athene!
               
	       #Transfer to Tyto
                echo rsync Athene\'s $CatWISEDir/ to Tyto $tyto_CatWISEDir
		ssh ${user}@137.78.30.21 "mkdir -p $tyto_CatWISEDir"
                rsync -avu $CatWISEDir ${user}@137.78.30.21:$tyto_CatWISEDir

               #Transfer to Otus
                echo rsync Athene\'s $CatWISEDir/ to Otus $otus_CatWISEDir
                ssh ${user}@137.78.80.75 "mkdir -p $otus_CatWISEDir"
                rsync -avu $CatWISEDir ${user}@137.78.80.75:$otus_CatWISEDir
        endif
        endif


echo
echo Wrapper Mode: ${1} Ended at:
echo $endTime
exit
