
/*
  remote access: setup
*/

%let wrds = wrds.wharton.upenn.edu 4016;options comamid = TCP remote=WRDS;
signon username=_prompt_;


/* execute code remotely within rsubmit-endrsubmit code block 
   note that after 15 or so minutes of inactivity, you need to sign on again
   also, you can have two rsubmits running at the same time
   and, you can have sessions gone bad, that need to be removed from the wrds website
   (log in to https://wrds-web.wharton.upenn.edu and select the 3rd option 'running queries' 
   of the dropdown menu on your name - top right)
*/
rsubmit;
/* hi */
endrsubmit;

/* get some records from Compustat Funda */

rsubmit;

data myTable (keep = gvkey fyear datadate roa mtb size sale at ni prcc_f csho);
set comp.funda;
/* require fyear to be within 2010-2013 */
if 2010 <=fyear <= 2013;
/* require assets, etc to be non-missing */
if cmiss (of at sale ceq ni) eq 0;
/* construct some variables */
roa = ni / at;
mtb = csho * prcc_f / ceq;
size = log(csho * prcc_f);
/* prevent double records */
if indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C' ;
run;
proc download data=myTable out=myCompTable;run;
endrsubmit;

/* does myCompTable have duplicate gvkey-fyear rows? */

proc sort data=myCompTable nodupkey dupout=mydouble; by gvkey fyear;run;

/* create an indicator =1 if sales increase */

/* 'dirty' 
	will not work for first year of data for each firm
*/
data myDirtyTable (keep = gvkey fyear sale sale_prev increase);
set myCompTable;
retain sale_prev;
if _N_ <= 30;
increase = (sale > sale_prev);
sale_prev = sale;
run;

/* clean -- use 'by' statement, and set to missing for first firmyear */
data myCleanTable (keep = gvkey fyear sale sale_prev increase);
set myCompTable;
by gvkey;
retain sale_prev;
if _N_ <= 30;
increase = (sale > sale_prev); /*<-------------- condition */
if first.gvkey then increase = .;
sale_prev = sale; /* <---------- update previous sales */
run;

/* another way */
data myCleanTable;  
set myCompTable;
by gvkey;
/* ifn/ifc function (ifn - numeric, ifc - character):  
IFC (condition, value if true, value if false, value if missing)
// for example
firmtype = IFC ( sale > 10, "big", "small", "missing");
*/
sale_lag = ifn(gvkey=lag(gvkey) and fyear=lag(fyear)+1, lag(sale), ., .);  
increase = (sale > sale_lag);
run; 


/* missing is represented by a large negative number */
data test;
miss = .;
larger = ( 1000 > miss); /* expect to be true */
run;

/* subsample */
data myCompTable2 (keep = gvkey fyear sale);
set myCompTable;
retain sale;
if _N_ <= 300;
run;

/* let's count the number of fiscal years, and the number of loss years for each firm 
	using the data step with BY statement
	this requires a sort on 'gvkey' (it is already sorted though)
*/

data countYears;
set myCompTable2;
by gvkey;
retain years lossyears ;
/* init for each gvkey (initial value in retain will only be used once) */
if first.gvkey then do;
  years = 0;
  lossyears = 0;
end;
/* increment years */
years = years + 1;
/* expression (<EXPR>) evaluates to 1 if true, 0 otherwise
 	so, (ni < 0) will be 1 if loss */
lossyears = lossyears + (ni < 0);
run;

/* what if we are only interested in the totals? 
	use 'output'
*/
data countYears (keep = gvkey years lossyears);
set myCompTable2;
by gvkey;
retain years  lossyears ;
/* init for each gvkey (initial value in retain will only be used once) */
if first.gvkey then do;
  years = 0;
  lossyears = 0;
end;
/* increment years */
years = years + 1;
/* expression (<EXPR>) evaluates to 1 if true, 0 otherwise
 	so, (ni < 0) will be 1 if loss */
lossyears = lossyears + (ni < 0);
/* only output last observation of each gvkey */
if last.gvkey then output;
run;