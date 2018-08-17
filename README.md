# IRSAWrapper
Wrapper to cross match an input MDEX table with the allwaise source catalog and the allwise reject catalog

Modes
Mode 2 (List of Tables Mode)
./IRSA_api.tcsh 2 <ListOfMDEXtables>
Mode 3 (Sinlge Table Mode)
./IRSA_api.tcsh 3 <MDEXtable>
  
## How to Run Modes
* Mode 2: List of Tables Mode
	* Run all MDEX tables in input list.
	* ./IRSA_api.tcsh 2 \<ListOfMDEXtables\>
* Mode 3: Single-Table Mode
	* Run MDEX table given in command line input.
	* ./IRSA_api.tcsh 3 \<MDEXtable\> 
