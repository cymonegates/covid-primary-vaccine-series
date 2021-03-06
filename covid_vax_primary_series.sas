
/******************************************************************************************************************
 Program: Calculating earliest COVID-19 primary series vaccination completion date
 Author:  Cymone Gates, MPH
 Written: 1-31-2022
 Purpose: Primarily, this will be used to determine if a COVID-19 case is a vaccine breakthrough case but can also
          be used to determine how many people are "fully vaccinated" aka have completed a primary series
 Assumptions: Unknown manufacturer vaccines are unspecified U.S.-authorized or approved mRNA COVID-19 vaccines.
              If this cannot be safely assumed for your dataset, you can remove it or update it on line 74.
*******************************************************************************************************************/

/*Primary Series Completion Definition from CDC
2 vaccine doses for persons who received Pfizer-BioNTech, Moderna, or unspecified U.S.-authorized or approved mRNA COVID-19 vaccine, or receipt of 1 dose for persons who received Janssen. Mixed doses can be considered for primary series completion. https://www.cdc.gov/mmwr/volumes/70/wr/mm7050e2.htm*/


*import sample file;
*sample file only has up to 6 vaccines;
*vaccines 1 - 6 are sorted from earliest to latest;

*you can download the sample .xlsx file from the GitHub repository at https://github.com/cymonegates/covid_primary_vaccine_series;

proc import datafile="[insert file path]\TEST_COVID19_VACCINES_WIDE.xlsx"
dbms=xlsx out=have REPLACE;
run; 

*turn on macro options to check background processes;
options mprint mlogic symbolgen;

*per the CDC definition, a person with 2 Pfizer doses has completed their primary series if the doses are at least 17 days apart;
*per the CDC definition, a person with 2 Moderna doses, 2 unspecified U.S.-authorized/approved mRNA COVID-19 vaccines, or a person with mixed doses has completed their primary series if the doses are at least 24 days apart;


%macro primary;

data test (drop=DAYS_BT: SERIES_COMPLETE_DT_J);
set have;

/*in order for this to work correctly, you have to order the DAYS_BT_DOSE fields in ascending order like below in the format*/
format SERIES_COMPLETE_DT_J         SERIES_COMPLETE_DT  DAYS_BT_DOSE_1_2	DAYS_BT_DOSE_1_3	DAYS_BT_DOSE_2_3	DAYS_BT_DOSE_1_4	DAYS_BT_DOSE_2_4
       DAYS_BT_DOSE_3_4             DAYS_BT_DOSE_1_5	DAYS_BT_DOSE_2_5	DAYS_BT_DOSE_3_5	DAYS_BT_DOSE_4_5	DAYS_BT_DOSE_1_6	DAYS_BT_DOSE_2_6	
       DAYS_BT_DOSE_3_6	            DAYS_BT_DOSE_4_6	DAYS_BT_DOSE_5_6             MMDDYY10.
	   ;


/*array for determining the earliest J&J vaccine date since 1 J&J is a complete series*/
array months VAXMAN_1 VAXMAN_2 VAXMAN_3 VAXMAN_4 VAXMAN_5 VAXMAN_6;
array admin VAXDT_1 -- VAXDT_6;
do i=1 to dim(months);
    if months[i]="Janssen" then do;
        SERIES_COMPLETE_DT_J = admin[i];
        leave;
    end;
end;drop i;

/*******************************************************************************************************
 These nested loops will calculate the number of days between each vaccine dose in order to determine
 if they meet the primary series completion requirements
*******************************************************************************************************/

/*loop through vaccines 1 - 5 (don't need to include vax #6 since all possible combinations of vaccine day differences will be covered)*/
%do i = 1 %to 5; 

/*create new macro var for the vaccine that occurs after number i*/
%let nxt = %eval(&i. + 1); 
	
	/*loop through next vaccine*/
	%do b=&nxt %to 6; 
 
		/*if both vaccines are Pfizer, and the number of days between then is ge 17 then output the vaccine admin date from the 2nd vaccine (aka date they finished a 2-dose series)
	      if both vaccines are Moderna, Unknown or mixed, and the number of days between then ge 24 then output the vaccine admin date from the 2nd vaccine (aka date they finished a 2-dose series)*/
		
		if VAXMAN_&i = 'Pfizer' and VAXMAN_&b = 'Pfizer' and intck('day',VAXDT_&i,VAXDT_&b) ge 17
        	then DAYS_BT_DOSE_&i._&b = VAXDT_&b;
		else if VAXMAN_&i in ('Pfizer' 'Moderna' 'Unknown') and VAXMAN_&b in ('Pfizer' 'Moderna' 'Unknown') and intck('day',VAXDT_&i,VAXDT_&b) ge 24
			then DAYS_BT_DOSE_&i._&b = VAXDT_&b;

	%end;
%end;


/*take the earliest series completion date (there could be more than 1) and put it in a new var called SERIES_COMPLETE_DT*/
IF SERIES_COMPLETE_DT_J ^=. THEN SERIES_COMPLETE_DT = MIN(SERIES_COMPLETE_DT_J,COALESCE(of DAYS_BT_DOSE:));
else SERIES_COMPLETE_DT = COALESCE(of DAYS_BT_DOSE:);


run;

%mend ;


/*execute macro*/
%primary

