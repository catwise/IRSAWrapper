#! /bin/tcsh -f 

echo "This wrapper will use IRSA's API to take in an MDEX table, run through stf and output a table for both Source and Reject catalog.\n"
#TODO fix random exit error and do documentation on the wmfflag attempts
set wrapperDir = $PWD
set startTime = `date '+%m/%d/%Y %H:%M:%S'`
echo 
echo Wrapper Started at:
echo $startTime
echo
echo Version 1.1 
echo
echo This Wrapper will wrap around and run:
echo 1\) stf \(extracts cols of input MDEX table\)
echo 2\) IRSA api
echo 3\) stils \(http://www.star.bris.ac.uk/~mbt/stilts/sun256/tcatn-usage.html\)

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
	(echo y | /Volumes/CatWISE1/ejmarchese/Dev/IRSAWrapper/IRSA_api.tcsh 3 $table) &	
	
	set maxInParallel = 3
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
	set tempSize = `echo $InputTable  | awk '{print length($0)}'`
        @ tempIndex = ($tempSize - 3 - 4)
	#does not include the .gz
        set edited_mdexTable = `basename $mdexTable | awk -v endIndex=$tempIndex '{print substr($0,0,endIndex)}'`
        set edited_mdexTablePATH = `dirname $mdexTable`
	set RadecID = `echo $edited_mdexTable | awk '{print substr($0,0,8)}'`
	echo Unzipping $mdexTable to ./${edited_mdexTable}.tbl
	gunzip -k  $mdexTable  

        echo "Current input MDEXTable == "$mdexTable
        echo "Edited_Current input MDEXTable == "$edited_mdexTable
        echo "RadecID == "$RadecID
	
	echo Calling stf on ./${edited_mdexTable}.tbl
	(/Users/CatWISE/stf ./${edited_mdexTable}.tbl 1 3 4 > ${edited_mdexTable}_stf.tbl) && echo "stf Done on ${mdexTable}" 
	
	#Call irsa api using file
	set stfTable = ${edited_mdexTable}_stf.tbl
	#curl -F filename=@${stfTable} -F catalog=allwise_p3as_psd -F spatial=Upload -F uradius=2 -F outfmt=1 -F selcols=cc_flags,w1cc_map,w1cc_map_str,w2cc_map,w2cc_map_str,coadd_id "https://irsa.ipac.caltech.edu/cgi-bin/Gator/nph-query" -o ${RadecID}_allwise_test_output.tbl
	set tempCoaddID = \'${RadecID}_ac51\'
	echo tempCoaddID === $tempCoaddID

       # Program Calls
	echo Calling IRSA api on ${stfTable} on AllWISE Source
	curl -F filename=@${stfTable} -F catalog=allwise_p3as_psd -F spatial=Upload -F uradius=2 -F outfmt=1 -F constraints=coadd_id=$tempCoaddID -F selcols=cc_flags,w1cc_map,w1cc_map_str,w2cc_map,w2cc_map_str,coadd_id "https://irsa.ipac.caltech.edu/cgi-bin/Gator/nph-query" -o ${RadecID}_allwise_Source_output.tbl
	echo Calling IRSA api on ${stfTable} on AllWISE Reject
	curl -F filename=@${stfTable} -F catalog=allwise_p3as_psr -F spatial=Upload -F uradius=2 -F outfmt=1 -F constraints=coadd_id=$tempCoaddID -F selcols=cc_flags,w1cc_map,w1cc_map_str,w2cc_map,w2cc_map_str,coadd_id "https://irsa.ipac.caltech.edu/cgi-bin/Gator/nph-query" -o ${RadecID}_allwise_Reject_output.tbl
	echo Concat the Source and Reject tbl
	/Users/marocco/bin/stilts/stilts tcatn nin=2 ifmt1=ipac in1=${RadecID}_allwise_Source_output.tbl ifmt2=ipac in2=${RadecID}_allwise_Reject_output.tbl omode=out out=${RadecID}_stilts_temp.tbl ofmt=ipac
	echo Match output ${RadecID}_stilts_temp.tbl to original ${edited_mdexTable}
	#TODO ERROR figure out why this is not working :( 
	/Users/marocco/bin/stilts/stilts tmatch2 ifmt1=ipac ifmt2=ipac omode=out out=${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl ofmt=ipac matcher=exact values1=source_id values2=source_id_01 join=all1 find=all in1=${mdexTable} in2=${RadecID}_stilts_temp.tbl
	echo DONE on ${mdexTable}_stf.tbl && goto G_Done #gzip_done
	#TODO optional rsync	
	#TODO uplad to github

Done:
echo IRSA_api Mode: ${1} Done
set endTime = `date '+%m/%d/%Y %H:%M:%S'`
echo
echo Wrapper Mode: ${1} Ended at:
echo $endTime
exit

G_Done:
echo IRSA_api on ${RadecID} Mode: ${1} Done
set endTime = `date '+%m/%d/%Y %H:%M:%S'`
echo Deleting ./${edited_mdexTable}.tbl 
rm -f ./${edited_mdexTable}.tbl
echo Deleting ${edited_mdexTable}_stf.tbl 
rm -f ${edited_mdexTable}_stf.tbl
echo Deleting ${RadecID}_stilts_temp.tbl 
rm -f ${RadecID}_stilts_temp.tbl
echo
	echo Gzipping and rm ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl
	gzip ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl && rm -f ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl
	echo Done gzip on ${edited_mdexTablePATH}/${edited_mdexTable}_af.tbl
echo
echo Wrapper Mode: ${1} Ended at:
echo $endTime
exit
