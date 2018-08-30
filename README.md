# IRSAWrapper

## Summary
Wrapper to cross match an input MDEX table with the AllWISE source catalog and the AllWISE reject catalog.
  
## Technical Summary
TODO  
  
## How to Run Modes
* Mode 2: List of Tables Mode
	* Run all MDEX tables in input list.
	* __./IRSA_api.tcsh 2 \<ListOfMDEXtables\>__
* Mode 3: Single-Table Mode
	* Run MDEX table given in command line input.
	* __./IRSA_api.tcsh 3 \<MDEXtable\>__ 

## IRSA WRAPPER Dependencies
* From Tyto:
	* /usr/local/gfortran/lib/\*
	* /Users/CatWISE/stf
	* /Users/marocco/bin/stilts/stilts
	* /Users/marocco/bin/
