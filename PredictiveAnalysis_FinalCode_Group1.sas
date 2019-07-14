/* 
PREDICTIVE ANALYSIS USING SAS
COFFEE DATA ANALYSIS 
GROUP : 1
FALL 2018
04 December 2018
*/

libname r "E:\Riti\Prayag";

/* IMPORT GROCERY DATA */
data r.coffee_grocery;
	infile 'H:\Prayag_predictive\HW5\coffee\coffee_groc_1114_1165' missover firstobs=2;
	input IRI_KEY $ WEEK SY $ GE $ VEND $ ITEM $ UNITS DOLLARS F $ D PR;
run;

data r.coffee_grocery; 
	set r.coffee_grocery;
	ITEM = put(input(ITEM,5.),z5.);
	VEND = put(input(VEND,5.),z5.);
	if SY eq 0 then COLUPC = cats(GE, VEND,ITEM);
	else COLUPC = cats(SY,GE, VEND,ITEM);
RUN;

data r.coffee_grocery; 
	set r.coffee_grocery;
	if F = "NONE" then Feature = 0;
	else Feature =1;

	if D = 0 then Display = 0;
	else Display =1;
RUN;

proc print data = r.coffee_grocery (obs=10); RUN;

/* IMPORT PROD DATA */
proc import datafile="H:\Prayag_predictive\HW5\coffee\prod_coffee.xlsx'"
     out=r.prod_data;
 	sheet = "Sheet1";    
run;

proc print data = r.prod_data (obs=10); RUN;

/* Filtering the DECAF Data */
data r.decaf_data;
	set r.prod_data;
	where L2 = "GROUND DECAFFEINATED COFFEE";
RUN;

proc print data = r.decaf_data(obs=10); RUN;

/*Creating UPC for DECAF Data*/
data r.decaf_data;
	set r.decaf_data;
	ITEM = put(input(ITEM,5.),z5.);
	VEND = put(input(VEND,5.),z5.);
	if SY eq 0 then COLUPC = cats(GE, VEND,ITEM);
	else COLUPC = cats(SY,GE, VEND,ITEM);
run;

/*Selecting the BRANDS*/
data r.decaf_data;
	set r.decaf_data;
	if L5 = "FOLGERS" then Brand = "FOLGERS";
	else if L5 = "MAXWELL HOUSE" then Brand = "MAXWELL HOUSE";
	else if L5 = "PRIVATE LABEL" then Brand = "PRIVATE LABEL";
	else Brand = "OTHERS";
RUN;

/* Creating the Size */
data r.decaf_data;
	set r.decaf_data;
	size = vol_eq *16;
	format size 9.2;
RUN;

proc print data = r.decaf_data(obs=10); RUN;

/*Joining Prod_data with the Grocery Data*/
proc sql;
	create table r.decaf_groc_merged as
	select g.IRI_KEY, g.WEEK, g.COLUPC, d.Brand, d.size, g.Feature, g.Display, SUM(g.units) as UnitsSold, sum(dollars) as RevenueEarned  
	from r.coffee_grocery g, r.decaf_data d
	where g.COLUPC = d.COLUPC
	group by g.IRI_KEY, g.WEEK, g.COLUPC, d.Brand, d.size, g.Feature, g.Display;	
quit;

proc print data = r.decaf_groc_merged(obs=10); where Brand = "FOLGERS";run;

/* Calculation of PricePerOz Price*/
data r.decaf_groc_merged;
	set r.decaf_groc_merged;
	PricePerOz = RevenueEarned/(UnitsSold * size);
	PricePerOzMS = PricePerOz * UnitsSold;
RUN;

/* Calculation of Weighted Price*/
proc sql;
	create table r.decaf_groc_merged_R as
	select IRI_key,week, Brand, sum(PricePerOzMS)as TotalPrice from r.decaf_groc_merged 
	group by IRI_key, Brand, week;
quit; 
proc sql;
	create table r.decaf_groc_merged_U as
	select IRI_key,week, Brand, sum(UnitsSold)as TotalUnits from r.decaf_groc_merged 
	group by IRI_Key,Brand, week;
quit;

proc sql;
	create table r.decaf_groc_merged_price as
	select r.IRI_Key,r.Week, r.Brand, r.TotalPrice/u.TotalUnits as WeightedAvgPrice from r.decaf_groc_merged_R r, r.decaf_groc_merged_U u
	where r.Brand = u.Brand and
			r.week = u.week and 
			r.IRI_Key = u.IRI_Key
	order by r.iri_key, r.week, r.brand; 
quit;

proc print data = r.decaf_groc_merged_price(obs=10); run;

/*Check for duplicates*/
proc sql;
	select iri_key, week, brand, count(*) as count from r.decaf_groc_merged_price
	group by iri_key, week, brand
	having count >1;
quit;

proc print data = r.decaf_groc_merged_price(obs=10); 
	where Brand = "FOLGERS" and Feature =1;
run;

proc print data = r.decaf_groc_merged_price(obs=10); run;

/*Checking duplicates in Decaf Data (No rows selected)*/
proc sql;
	select IRI_KEY, WEEK, Brand, WeightedAvgPrice, count(*) as count from r.decaf_groc_merged_price
	group by IRI_KEY, WEEK, Brand, WeightedAvgPrice
	having count > 1;
quit;

/*Transposing the price into P1 P2 P3 P4*/
proc transpose data = r.decaf_groc_merged_price out = r.decaf_groc_merged_P1P2P3P4;
	by iri_key week;
	var WeightedAvgPrice;
	id Brand;
run;

proc print data= r.decaf_groc_merged_P1P2P3P4(obs=10); run;

proc means data = r.decaf_groc_merged_P1P2P3P4; run;

/*Calculating Weighted Feature & Display*/
proc print data= r.decaf_groc_merged(obs =10); run;

proc sql;
create table r.decaf_groc_merged_DF as
	select IRI_KEY, WEEK, COLUPC, Brand, size, Feature, Display, sum(UnitsSold) as Units  from r.decaf_groc_merged
	group by IRI_KEY, WEEK, COLUPC, Brand, size, Feature; 
quit;

proc sql;
	create table r.decaf_groc_merged_DF_Units as
	select iri_key, week, brand, sum(UnitsSold) as TUnits from r.decaf_groc_merged
	group by week, brand, iri_key; 
quit;

proc sql;
    create table r.decaf_groc_merged_WtDF as
 	select t1.iri_key, t1.week, t1.brand, t1.size , t1.Feature, t1.Display, t1.Units, t2.Tunits, t1.Units/t2.Tunits as MarketShare format 8.2  
	from r.decaf_groc_merged_DF t1, r.decaf_groc_merged_DF_Units t2
	where t1.week = t2.week and
	t1.brand = t2.brand and
	t1.iri_key = t2.iri_key
	order by t1.iri_key, t1.week, t1.brand;
quit;

/*Checking for duplicates*/
proc sql;
	select iri_key, week, brand , count(*) as c from r.decaf_groc_merged_WtDF
	group by iri_key, week, brand
	;
quit;


proc print data = r.decaf_groc_merged_WtDF (obs=10); run;

data r.decaf_groc_merged_DF_Weighted;
	set r.decaf_groc_merged_WtDF;
	FNew = Feature * MarketShare;
	Dnew = Display * MarketShare;
RUN; 

proc print data = r.decaf_groc_merged_DF_Weighted(obs=5); where Feature =1; run;

proc contents data = r.decaf_groc_merged_DF_Weighted; run;

proc sql;
	create table r.decaf_groc_merged_DF_Weighted as
	select IRI_KEY, WEEK, Brand,sum(FNew) as FNew1, sum(Dnew) as DNew1
	from r.decaf_groc_merged_DF_Weighted
	group by IRI_KEY, WEEK, Brand; 
quit;

proc print data = r.decaf_groc_merged_DF_Weighted(obs=5);run;

proc means data = r.decaf_groc_merged_DF_Weighted; run;


/*Transposing the price into F1 F2 F3 F4*/
proc transpose data = r.decaf_groc_merged_DF_Weighted out = r.decaf_groc_merged_F1F2F3F4;
	by iri_key week;
	var FNew1;
	id Brand;
run;

proc print data =r.decaf_groc_merged_F1F2F3F4(obs=5); run;

proc transpose data = r.decaf_groc_merged_DF_Weighted out = r.decaf_groc_merged_D1D2D3D4;
	by iri_key week;
	var DNew1;
	id Brand;
run;

proc print data =r.decaf_groc_merged_D1D2D3D4(obs=5); run;

/*Combining three datasets with Price Feature and Display flattened*/
proc sql;
	create table r.decaf_groc_DF_merged as
	select f.iri_key, f.week, f.FOLGERS as F1, f.MAXWELL as F2, f.OTHERS as F3, f.PRIVATE as F4 ,
	 d.FOLGERS as D1, d.MAXWELL as D2, d.OTHERS as D3, d.PRIVATE as D4 
	from r.decaf_groc_merged_F1F2F3F4 f, r.decaf_groc_merged_D1D2D3D4 d
	where f.iri_key = d.iri_key and
	f.week = d.week; 
quit;

proc print data= r.decaf_groc_DF_merged(obs=5); run;

proc print data= r.decaf_groc_merged_P1P2P3P4(obs=5); run;

/*Renaming the Prices as P1-P4*/
proc sql;
	create table r.decaf_groc_merged_P1P2P3P4_new as
	select iri_key, week, FOLGERS as P1, MAXWELL as P2, OTHERS as P3, PRIVATE as P4
	from r.decaf_groc_merged_P1P2P3P4
quit;

/*Combine Display and Feature with Price */
proc sql;
	create table r.decaf_groc_PDF_merged as
	select df.iri_key, df.week,p.P1, p.P2, p.P3,p.P4, df.F1, df.F2, df.F3, df.F4 ,
	df.D1, df.D2, df.D3, df.D4 
	from r.decaf_groc_DF_merged df, r.decaf_groc_merged_P1P2P3P4_new p
	where df.iri_key = p.iri_key and
	df.week = p.week; 
quit;

proc print data= r.decaf_groc_PDF_merged(obs=10); run;

/*Combine the Store Data with Panel Id*/

/* IMPORT PANEL GR DATA */
data r.panel_GR;
	infile 'H:\Prayag_predictive\HW5\coffee\coffee_PANEL_GR_1114_1165.dat' truncover firstobs=2 dlm='09'x;
	input PANID WEEK UNITS OUTLET $ DOLLARS IRI_KEY $ COLUPC $ 15.;
run;

proc print data= r.panel_GR (obs=10); RUN;

proc sql;
	create table r.decaf_panel as
	select p.PANID, p.IRI_KEY ,p.WEEK, p.COLUPC, d.Brand, p.Outlet,p.UNITS, p.DOLLARS from r.decaf_data d , r.panel_GR p
	where d.COLUPC = p.COLUPC;
quit;

proc print data= r.decaf_panel (obs=10); RUN;

proc sql;
	create table r.decaf_panel_aggreagted as 
	select PANID, IRI_KEY, WEEK, Brand , sum(Units) as UnitsPurchased, sum(Dollars) as PricePaid 
	from r.decaf_panel
	group by PANID, IRI_KEY, WEEK, Brand ;
quit;

proc print data = r.decaf_panel_aggreagted; run;

proc sql;
    create table r.decaf_final as
    select * from r.decaf_groc_PDF_merged pdf, r.decaf_panel_aggreagted pan
	where pdf.iri_key = pan.iri_key and
	pdf.week = pan.week;
quit;

proc print data= r.decaf_final; RUN;

proc means data = r.decaf_final; run;

/* Import Demographic data*/
proc import datafile = 'H:\Prayag_predictive\HW5\coffee\ads_demo1.csv'
	out=r.demo_data
	dbms = CSV;
run;

/* Dropping then columns with more than 60% empty cells*/
data r.demo_data (drop = Panelist_Type COUNTY HH_AGE HH_EDU HH_OCC MALE_SMOKE FEM_SMOKE Language HISP_FLAG HISP_CAT 
				HH_Head_Race_RACE2 HH_Head_Race_RACE3 Microwave_Owned_by_HH ZIPCODE FIPSCODE market_based_upon_zipcode 
				IRI_Geography_Number EXT_FACT Year); 
	set r.demo_data; 
run;

proc print data = r.demo_data(obs=10); run;

proc means data = r.demo_data;run; 

/* Combining the demographic data with the Decaf Panel data */
proc sql;
	create table r.CoffeeData as
	select p.* , c.* from r.demo_data p , r.decaf_final c
	where p.Panelist_ID = c.PANID ;
quit;

proc means data = r.CoffeeData; run;

proc print data = r.CoffeeData (obs=10); run;

proc contents data = r.CoffeeData; run;

/* Export of the final coffee dataset*/
proc export 
  data= r.CoffeeData 
  dbms=xlsx 
  outfile="E:\Riti\CoffeeData.xlsx" 
  replace;
run;


libname rr "E:\Riti\ProjectAnalysis";

data rr.deliveryStores;
	infile 'H:\Riti\PredictiveAnalysis\Project\Delivery_Stores' missover firstobs=2;
	input IRI_KEY $ 1-7 OU $ 9-10 EST_ACV 11-19 Market_Name $ 20-44 Open 45-49 Clsd 50-54 MskdName $ 55-63;
run;

proc print data = rr.deliveryStores (obs=5); run;
proc print data = rr.coffee (obs=5); run;

proc contents data = rr.deliveryStores; run;
proc contents data = rr.coffee ; run;

proc sql;
	create table rr.coffee_data as
	select tab1.*,tab2.EST_ACV, tab2.Market_Name, tab2.MskdName, tab2.Open, tab2.Clsd from rr.coffee tab1, rr.deliveryStores tab2
	where tab1.iri_key = tab2.iri_key;
run;

proc print data = rr.coffee_data (obs=5); run;

proc export 
  data= rr.coffee_data 
  dbms=xlsx 
  outfile="E:\Riti\Coffee_Data.xlsx" 
  replace;
run;

/********************************************************/
/*TIME-SERIES ANALYSIS*/
proc print data = rr.week (obs=5); run;

proc contents data = rr.week; run;

data rr.week;
	set rr.week;


proc sql;
	create table rr.newData as
	select distinct week, avg(p1) as Folgers, avg(p2) as MaxwellHouse, avg(p3) as PrivateLabel, avg(p4) as Other 
	from rr.coffee_data
	group by week
	order by week;
run;

proc print data = rr.newData1 (obs=20); run;

proc sql;
	create table rr.newData1 as
	select c.*, w.Calendar_week_starting_on, w.Calendar_week_ending_on from rr.newData c , rr.week w
	where c.week = w.iri_week;
run;

/*Price trend over the entire Year*/
proc sgplot data = rr.newData1;
   series x=Calendar_week_starting_on y=Folgers / markers; 
   series x=Calendar_week_starting_on y=MaxwellHouse / markers; 
   series x=Calendar_week_starting_on y=PrivateLabel / markers; 
   series x=Calendar_week_starting_on y=Other / markers;
   xaxis label = "Date";
   yaxis label = "Average Price";
run;                                                                                                                                    

/**/
proc print data = rr.Coffee_Data (obs=5); where UnitsPurchased > 1; run;

proc sql;
	create table rr.PriceFolgerData as
	select distinct week, brand, sum(PricePaid) as Revenue
	from rr.coffee_data
	where brand = "FOLGERS"
	group by week , brand
	order by week;
run;

proc print data = rr.PriceFolgerData1; run;

proc sql;
	create table rr.PriceFolgerData1 as
	select c.*, w.Calendar_week_starting_on, w.Calendar_week_ending_on from rr.PriceFolgerData c , rr.week w
	where c.week = w.iri_week;
run;

/*Price trend over the entire Year*/
proc sgplot data = rr.newData1;
   series x=Calendar_week_starting_on y=Folgers / markers; */
   /*series x=Calendar_week_starting_on y=MaxwellHouse / markers; 
   /*series x=Calendar_week_starting_on y=PrivateLabel / markers; 
   series x=Calendar_week_starting_on y=Other / markers;*/
   xaxis label = "Date";
   yaxis label = "Average Price";
run;                                                                                                                                    

proc print data = rr.newData1 (obs =5); run;

proc print data = rr.coffee_folger (obs=5); run;

proc sql;
	create table rr.coffee_folger as
	select * from rr.coffee_data where brand = "FOLGERS";
quit;

Proc reg data = rr.coffee_folger;
	model PricePaid = P1 F1 D1/ DW;
run;

proc autoreg data = rr.coffee_folger;
	model PricePaid = P1 F1 D1 / DWprob;
run;

proc print data=rr.coffee_folger; run;

data rr.coffee_folger_arima;
	set rr.coffee_folger;
	date = intnx( 'month', '31dec1948'd, n );
   format date monyy.;
run;

proc arima data=rr.coffee_folger_arima;
      identify var=PricePaid;
	  estimate q=(1)(12) noint;
	  forecast id=date interval=month printall out=b;
   run;

proc print data = b (obs=10);
run;

data c;
   set b;
   x        = exp( xlog );
   forecast = exp( forecast + std*std/2 );
   l95      = exp( l95 );
   u95      = exp( u95 );
run;

proc print data = c (obs=10);
run;

proc sgplot data=c;
   where date >= '01jan1958'd;
   band Upper=u95 Lower=l95 x=date 
      / LegendLabel="95% Confidence Limits";
   scatter x=date y=x;
   series x=date y=forecast;
run;

data rr.test1;
      set rr.coffee_folger_arima;
      y4 = lag4(PricePaid);
   run;

   proc reg data=rr.test1 outest=alpha;
      model PricePaid = y4 / noprint;
   run;

   data _null_;
      set alpha;
      x = 100 * ( y4 - 1 );
      p = probdf( x, 100, 4, "RSM" );
      put p= pvalue5.3;
   run;

    data rr.test1;
      set rr.coffee_folger_arima;
      yl  = lag(PricePaid);
      yd  = dif(PricePaid);
      yd1 = lag1(yd); yd2 = lag2(yd);
      yd3 = lag3(yd); yd4 = lag4(yd);
   run;

   proc reg data=rr.test1 outest=alpha covout;
      model yd = yl yd1-yd4 / noprint;
   run;

   data _null_;
      set alpha;
      retain a;
      if _type_ = 'PARMS' then a = yl ;
      if _type_ = 'COV' & _NAME_ = 'Y1' then do;
         x = a / sqrt(yl);
         p = probdf( x, 99, 1, "SSM" );
         put p= pvalue5.3;
         end;
   run;

%dftest( rr.coffee_folger_arima, PricePaid, ar=4 );
%put p=&dftest;

/*********************************************************/
/*RFM ANALYSIS*/

proc print data = rr.coffee_data(obs=10); run;

proc contents data = rr.coffee_data; run;

/*Calculating Recency, frequency and MonetaryValue of each customer */
proc sql;
	create table rr.Panel_RFM as
	select panid, max(week) as Recency , count(week) as Frequency , sum(pricepaid) as MonetaryValue 
	from rr.coffee_data
	group by panid;
quit;

proc print data = rr.Panel_RFM; run;

/*Ranking Recency*/

proc sort data = rr.Panel_RFM out = rr.Panel_RFM_R;
	by descending Recency;
run;

proc print data = rr.Panel_RFM_R; run;

proc rank data = rr.Panel_RFM_R out = rr.Panel_RFM_R_Rank ties = low groups =5;
	var Recency;
	ranks R;
run;

proc print data = rr.Panel_RFM_R_Rank ; run;

/*Ranking Frequency*/
proc rank data = rr.Panel_RFM_R_Rank out = rr.Panel_RFM_RF_Rank ties = low groups = 5;
	var Frequency;
	ranks F;
run;

proc print data = rr.Panel_RFM_RF_Rank ; run;

/*Ranking MonetaryValue*/
proc rank data = rr.Panel_RFM_RF_Rank out = rr.Panel_RFM_RFM_Rank ties = low groups = 5;
	var MonetaryValue;
	ranks M;
run;

proc print data = rr.Panel_RFM_RFM_Rank ; run;

/*Overall Ranking*/
data rr.Panel_RFM_Overall ;
	set rr.Panel_RFM_RFM_Rank ;
	R+1;
	F+1;
	M+1;
	RFM_Score = cats(of R F M )+ 0 ;
run;

proc print data = rr.Panel_RFM_Overall ; run;

/*Clustering the panels as per the RFM_Score*/
proc cluster data = rr.Panel_RFM_Overall method = com ccc pseudo outtree = rr.RFM_Cluster_Tree;
	var R F M;
	id Panid;
run;

/* Clusters */
proc tree data = rr.RFM_Cluster_Tree out = rr.RFM_Cluster_Tree nclusters = 5;
	id Panid;
	copy R F M;
run;

proc print data = rr.RFM_Cluster_Tree ; run;

proc print data = rr.coffee_data; run;

/* Demographic Data*/
proc print data = rr.demo_data(obs=10); run;

proc sql;
	create table rr.Panel_RFM_Demo as
	select distinct t.panid, d.Combined_Pre_Tax_Income_of_HH, d.Family_Size, (d.Number_of_Dogs + d.Number_of_Cats) AS Pets,
	d.Children_Group_Code, d.Marital_Status, t.Cluster, r.RFM_Score
	from rr.demo_data d, rr.RFM_Cluster_Tree t , rr.Panel_RFM_Overall r
	where d.Panelist_ID = t.panid
	and t.panid = r.panid
	group by t.cluster, t.panid;
quit;

proc print data = rr.Panel_RFM_Demo; run; 

/* Classification of Best Customers */
data rr.Panel_RFM_Demo ;
	set rr.Panel_RFM_Demo;
	if RFM_Score > 443 then CustomerValue = 'Prime' ;
	else CustomerValue = 'Not Prime';
run;

/*Best Customers*/
data rr.Panel_RFM_Demo_BestCust ;
	set rr.Panel_RFM_Demo;
	where CustomerValue = 'Prime';
run;

proc print data = rr.Panel_RFM_Demo_BestCust; run;

proc export 
  data= rr.Panel_RFM_Demo 
  dbms=xlsx 
  outfile="E:\Riti\ProjectAnalysis\Panel_RFM_Demo.xlsx" 
  replace;
run;

proc freq data = rr.Panel_RFM_Demo_BestCust ;
	table Marital_status;
run;

proc sql;
	create table rr.Panel_Cluster_Collection_Prime as
	select p.cluster, sum(c.pricepaid) as Revenue 
	from rr.coffee_data c, rr.panel_rfm_demo p
	where p.panid = c.panid
	and customerValue = 'Prime'
	group by p.cluster;
run;

proc print data = rr.Panel_Cluster_Collection; run;

/**************************************************************/
/* BRAND SELECTION*/
proc import datafile="H:\Predictive\coffee\CoffeeData2.xlsx"
     out= f.coffee_data_new
	 dbms = XLSX 
	replace;
run;

proc print data = f.coffee_data_new (obs=10); run;

/* Dropping duplicate, empty columns */
data f.coffee_data_new (drop = PANID HH_Head_Race__RACE2_ HH_Head_Race__RACE3_);
set f.coffee_data_new;
run;

proc means data = f.coffee_data_new; run;

proc print data = f.coffee_data_new (obs=10); run;

proc contents data = f.coffee_data_new; run;

/* Create brand integer variable with respect to brand value */
data f.coffee_data_new1;
set f.coffee_data_new;
if brand = 'FOLGERS' then br = 1;
if brand = 'MAXWELL' then br = 2;
if brand = 'OTHERS' then br = 3;
if brand = 'PRIVATE' then br = 4;
run;

proc print data = f.coffee_data_new1 (obs=100); run;
proc contents data = f.coffee_data_new1; run;

data f.newdata (keep= tid decision mode price display feature family_size Combined_Pre_Tax_Income_of_HH HH_Race Type_of_Residential_Possession);
set f.coffee_data_new1;
array pvec{4} p1 - p4;
array dvec{4} d1 - d4;
array fvec{4} f1 - f4;
retain tid 0;
tid+1;
do i = 1 to 4;
	mode=i;
	price=pvec{i};
	display=dvec{i};
	feature=fvec{i};
	decision=(br=i);
	output;
end;
run;

proc print data = f.newdata (obs=10); run;

/* Create brand specific values for each of variable*/
data f.newdata;
set f.newdata;
brand2=0;
brand3=0;
brand4=0;
if mode = 2 then brand2 = 1;
if mode = 3 then brand3 = 1;
if mode = 4 then brand4 = 1;
family_size2 = family_size * brand2;
family_size3 = family_size * brand3;
family_size4 = family_size * brand4;
Combined_Pre_Tax_Income_of_HH2 = Combined_Pre_Tax_Income_of_HH * brand2;
Combined_Pre_Tax_Income_of_HH3 = Combined_Pre_Tax_Income_of_HH * brand3;
Combined_Pre_Tax_Income_of_HH4 = Combined_Pre_Tax_Income_of_HH * brand4;
HH_Race2 = HH_Race*brand2;
HH_Race3 = HH_Race*brand3;
HH_Race4 = HH_Race*brand4;
Type_of_Residential_Possession2 = Type_of_Residential_Possession* brand2;
Type_of_Residential_Possession3 = Type_of_Residential_Possession* brand3;
Type_of_Residential_Possession4 = Type_of_Residential_Possession* brand4;
int_pd2 = price*display*brand2;
int_pd3 = price*display*brand3;
int_pd4 = price*display*brand4;
int_pf2 = price*feature*brand2;
int_pf3 = price*feature*brand3;
int_pf4 = price*feature*brand4;
run;

proc export 
  data=f.newdata
  dbms=xlsx 
  outfile="H:\Predictive\coffee\newdata1.xlsx" 
  replace;
run;
 
/* Without interaction terms */

proc mdc data=f.newdata;
model decision = brand2 brand3 brand4 price display feature family_size2-family_size4 Combined_Pre_Tax_Income_of_HH2-Combined_Pre_Tax_Income_of_HH4 Type_of_Residential_Possession2-Type_of_Residential_Possession4 HH_Race2-HH_Race4/ type=clogit 
	nchoice=4
    optmethod=qn
    covest=hess;
	id tid;
	output out=probdata pred=p;
run;


/* Interaction term price*display */
proc mdc data=f.newdata;
model decision = brand2 brand3 brand4 price display feature family_size2-family_size4 Combined_Pre_Tax_Income_of_HH2-Combined_Pre_Tax_Income_of_HH4 Type_of_Residential_Possession2-Type_of_Residential_Possession4 HH_Race2-HH_Race4 int_pd2-int_pd4/ type=clogit 
	nchoice=4
    optmethod=qn
    covest=hess;
	id tid;
	output out=probdata pred=p;
run;

/* Interaction term price*feature */

proc mdc data=f.newdata;
model decision = brand2 brand3 brand4 price display feature family_size2-family_size4 Combined_Pre_Tax_Income_of_HH2-Combined_Pre_Tax_Income_of_HH4 Type_of_Residential_Possession2-Type_of_Residential_Possession4 HH_Race2-HH_Race4 int_pf2-int_pf4/ type=clogit 
	nchoice=4
    optmethod=qn
    covest=hess;
	id tid;
	output out=probdata pred=p;
run;

/* Create a new table predict with predicted probabilities, tid, decision variables */
proc sql;
create table predict as
select p, tid, decision
from probdata
order by tid, p desc;
run;
quit;


proc print data = predict (obs=10); run;

/* Calculate predicted decision variable values*/
data predict;
set predict;
predict=0;
by tid;
if first.tid then predict=1;
run;

/* Frequency table to verify predicted and observed decision variable values*/
proc freq data=predict;
table predict*decision;
run;

/* Calculate own and cross price elasticity*/
data a2; set probdata; if mode=1;
ownp = (1 - p)*price*-0.1195;
cross = -p*price*-0.1195;
run;


/* Print mean of own and cross price elasticity*/
proc means data = a2;
var ownp cross;
run;
