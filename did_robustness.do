sort firm year
set more off
gl cluster_var = "ind3"
pause on


*******************
* 2014 Industries *
*******************
preserve
	set more off
	drop if treatment ==2
	bys firm: gen N = _N

	gen treated= treated2014 
	drop treated2014 treated2015

	drop if business_revenue_100 <= 1 
	
	bys ind3: gegen temp = mean(logrevenue) if year < 2014 
	bys ind3: gegen avgrev = max(temp)
	drop temp
	
	gen profitmargin = business_profit_100/ business_revenue
	 
	bys ind3: gegen temp = mean(profitmargin) if year < 2014 
	bys ind3: gegen avgmargin = max(temp)
	
	winsor2 dlnfixed_assets_net lnfixed_assets_net, by(year treated) cut(1 99) suffix(_h)
		
	* Full Sample *
	reghdfe dlnfixed_assets_net_h ib2013.year##ib0.treated ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014_spec0.dta, replace)
	
	reghdfe lnfixed_assets_net_h  ib2013.year##ib0.treated ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014stock_spec0.dta, replace)
	
	* Full Sample + Fan Liu Specification*
	
	reghdfe dlnfixed_assets_net_h  ib2013.year##ib0.treated i.year#c.avgrev i.year#c.avgmargin ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014_spec1.dta, replace)
	
	reghdfe lnfixed_assets_net_h  ib2013.year##ib0.treated i.year#c.avgrev i.year#c.avgmargin  ///
	`controls'  , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014stock_spec1.dta, replace)
	
	* Restricted Sample *
	keep if treatment == 1 | indcode == 10
	
	
	winsor2 dlnfixed_assets_net lnfixed_assets_net, by(year treated) cut(1 99) replace
	
	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014_spec2.dta, replace)	
	
	reghdfe lnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014stock_spec2.dta, replace)	
	
	* Restricted Sample + Fan Liu Spec
	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated i.year#c.avgrev i.year#c.avgmargin ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014_spec3.dta, replace)
		
	reghdfe lnfixed_assets_net ib2013.year##ib0.treated i.year#c.avgrev i.year#c.avgmargin ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014stock_spec3.dta, replace)	
		
		
	* Restricted Sample + Balanced Panel *
	
	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' if N == 7, cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014_spec4.dta, replace)	
	
	reghdfe lnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' if N == 7 , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014stock_spec4.dta, replace)	
	
	
	* Restricted Sample with Matching *
	merge m:1 firm using $output/matched_sample2014_manufacturing.dta,  keep(3)
	winsor2 dlnfixed_assets_net lnfixed_assets_net, by(year treated) cut(1 99) replace

	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' [aw = cem_weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014_spec5.dta, replace)

	reghdfe lnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' [aw = cem_weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014stock_spec5.dta, replace)	
	
	* Restricted Sample with Matching and DFL Re-Weighting *

	gl group = "treated`year'"
	gl base_year = 2013
	gl base_group = 1
	gl percentiles = 10
	gl weight = "cem_weight"
	gl variables = "business_revenue_100"
	
	winsor2 $variables, replace cut(1 99) by(treated year)

	do $code_other/dfl.do
			
	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated ///
	`controls'  [aw = dfl_weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014_spec6.dta, replace)
	
	reghdfe lnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' [aw = dfl_weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2014stock_spec6.dta, replace)
	
	
restore


set more off
foreach outcome in  "" "stock" {
	if "`outcome'" == "stock" local min = 2012
	else local min = 2013

forvalues spec = 0(1)6  {

	preserve

		use $output/dyn2014`outcome'_spec`spec'.dta, clear
	
		split parm, parse(#)
		drop if mi(parm2)
		gen year = substr(parm1,1,4)
		gen treated = substr(parm2, 1,1)
		split parm2, parse(.)
		keep if treated == "1"
		destring year, replace
		rename estimate estimate`spec'
		rename min95 min95`spec'
		rename max95 max95`spec'
		tempfile spec`spec'
		save "`spec`spec''", replace
		
	restore
	
}

preserve
	
	use "`spec0'", clear
	merge 1:1 year using "`spec1'", nogen	
	merge 1:1 year using "`spec2'", nogen
	merge 1:1 year using "`spec3'", nogen
	merge 1:1 year using "`spec4'", nogen
	merge 1:1 year using "`spec5'", nogen
	merge 1:1 year using "`spec6'", nogen
	
	gen year0 = year -.3
	gen year1 = year - .2
	gen year2 = year -.1
	gen year3 = year 
	gen year4 = year +.1
	gen year5 = year +.2
	gen year6 = year +.3
	
	
	* Fan and Liu Comparison
	
	
	twoway (scatter estimate6 year1, mcolor(black) ) (rcap min956 max956 year1, lwidth(thick) lcolor(purple)) ///
	(scatter estimate1 year, mcolor(black) ) (rspike min951 max951 year, lwidth(thick) lcolor(nazy) ) ///
	(scatter estimate3 year5, mcolor(black) ) (rspike min953 max953 year5, lwidth(thick) lcolor(brown) ), ///
	legend( cols(4) ring(1) pos(6) order(2 4 6) label(2 "Our Baseline Results") ///
	 label(4 "Full Sample+" "Fan Liu Spec") label(6 "Manufacturing Sample+" "Fan Liu Spec")) ///
	xline(2014.5, lcolor(red)) yline(0, lcolor(red)) ylabel(#10, format(%9.2f)) ///
	xtitle(Year) ytitle("DiD Coefficient") xlabel(`min'(1)2016)
	graph export $output/fanliu_comparison2014`outcome'.pdf, replace	
	
	
	* Robustness 
	twoway (scatter estimate2 year2, mcolor(black) ) (rspike min952 max952 year2, lwidth(thick) lcolor(navy) lpattern(dash) ) ///
	(scatter estimate4 year3, mcolor(black) ) (rcap min954 max954 year3, lwidth(thick) lcolor(red) ) ///
	(scatter estimate5 year4, mcolor(black) ) (rcap min955 max955 year4, lwidth(thick) lcolor(green) ) ///
	(scatter estimate6 year5, mcolor(black) ) (rcap min956 max956 year5, lwidth(thick) lcolor(purple)),   ///
	legend( cols(3) ring(1) pos(6) order(2 4 6 8) ///
	 label(2 "Full  Manufacturing Control") ///
	label(4 "Balanced Sample") ///
	label(6 "Matched Sample" ) ///
	label(8 "Matching" "+ DFL Re-Weighting")) ///
	xline(2014.5, lcolor(red)) yline(0, lcolor(red)) ylabel(#10) ///
	xtitle(Year) ytitle("") xlabel(`min'(1)2016) ///
	name(robustness_did2014`outcome', replace) title("2014 Reform")
		
	graph export $output/robustness_did2014`outcome'.pdf, replace	
	

	
	
	
restore

}






*******************
* 2015 Industries *
*******************

preserve
	set more off
	drop if treatment ==1
	bys firm: gen N = _N
	
	gen treated= treated2015
	drop treated2015 treated2014
	
	drop if business_revenue_100 <= 1 
	
	bys ind3: gegen temp = mean(logrevenue) if year < 2014 
	bys ind3: gegen avgrev = max(temp)
	drop temp
	
	gen profitmargin = business_profit_100/ business_revenue
	
	bys ind3: gegen temp = mean(profitmargin) if year < 2014 
	bys ind3: gegen avgmargin = max(temp)
	
	winsor2 dlnfixed_assets_net lnfixed_assets_net, by(year treated) cut(5 95) suffix(_h)
	
	* Full Sample *
	reghdfe dlnfixed_assets_net_h ib2013.year##ib0.treated ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015_spec0.dta, replace)
	
	reghdfe lnfixed_assets_net_h ib2013.year##ib0.treated ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015stock_spec0.dta, replace)
	
	* Full Sample + Fan Liu Specification*
	
	reghdfe dlnfixed_assets_net_h ib2013.year##ib0.treated i.year#c.avgrev i.year#c.avgmargin ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015_spec1.dta, replace)
	
	reghdfe lnfixed_assets_net_h ib2013.year##ib0.treated i.year#c.avgrev i.year#c.avgmargin  ///
	`controls'  , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015stock_spec1.dta, replace)
	
	* Restricted Sample *
	keep if treatment == 1 | indcode == 10
	
	
	winsor2 dlnfixed_assets_net lnfixed_assets_net, by(year treated) cut(1 99) replace
	
	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015_spec2.dta, replace)	
	
	reghdfe lnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015stock_spec2.dta, replace)	
	
	* Restricted Sample + Fan Liu Spec
	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated i.year#c.avgrev i.year#c.avgmargin ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015_spec3.dta, replace)
		
	reghdfe lnfixed_assets_net ib2013.year##ib0.treated i.year#c.avgrev i.year#c.avgmargin ///
	`controls' , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015stock_spec3.dta, replace)	
		
		
	* Restricted Sample + Balanced Panel *
	
	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' if N == 7, cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015_spec4.dta, replace)	
	
	reghdfe lnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' if N == 7 , cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015stock_spec4.dta, replace)	
	
	
	* Restricted Sample with Matching *
	merge m:1 firm using $output/matched_sample2015_manufacturing.dta,  keep(3)
	winsor2 dlnfixed_assets_net lnfixed_assets_net, by(year treated) cut(1 99) replace

	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' [aw = cem_weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015_spec5.dta, replace)

	reghdfe lnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' [aw = cem_weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015stock_spec5.dta, replace)	
	
	* Restricted Sample with Matching and DFL Re-Weighting *

	gl group = "treated`year'"
	gl base_year = 2013
	gl base_group = 1
	gl percentiles = 10
	gl weight = "cem_weight"
	gl variables = "business_revenue_100"
	
	winsor2 $variables, replace cut(1 99) by(treated year)

	do $code_other/dfl.do
			
	reghdfe dlnfixed_assets_net ib2013.year##ib0.treated ///
	`controls'  [aw = dfl_weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015_spec6.dta, replace)
	
	reghdfe lnfixed_assets_net ib2013.year##ib0.treated ///
	`controls' [aw = dfl_weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn2015stock_spec6.dta, replace)
	su dfl_weight
	
	
	
restore



set more off
foreach outcome in  "" "stock" {
	
	if "`outcome'" == "stock" local min = 2012
	else local min = 2013
	
	forvalues spec = 0(1)6  {

		preserve

			use $output/dyn2015`outcome'_spec`spec'.dta, clear
		
			split parm, parse(#)
			drop if mi(parm2)
			gen year = substr(parm1,1,4)
			gen treated = substr(parm2, 1,1)
			split parm2, parse(.)
			keep if treated == "1"
			destring year, replace
			rename estimate estimate`spec'
			rename min95 min95`spec'
			rename max95 max95`spec'
			tempfile spec`spec'
			save "`spec`spec''", replace
			
		restore
		
	}

	preserve
		
		use "`spec0'", clear
		merge 1:1 year using "`spec1'", nogen	
		merge 1:1 year using "`spec2'", nogen
		merge 1:1 year using "`spec3'", nogen
		merge 1:1 year using "`spec4'", nogen
		merge 1:1 year using "`spec5'", nogen
		merge 1:1 year using "`spec6'", nogen
		
		gen year0 = year -.3
		gen year1 = year - .2
		gen year2 = year -.1
		gen year3 = year 
		gen year4 = year +.1
		gen year5 = year +.2
		gen year6 = year +.3
		
		twoway (scatter estimate6 year1, mcolor(black) ) (rcap min956 max956 year1, lwidth(thick) lcolor(purple)) ///
		(scatter estimate1 year, mcolor(black) ) (rspike min951 max951 year, lwidth(thick) lcolor(nazy) ) ///
		(scatter estimate3 year5, mcolor(black) ) (rspike min953 max953 year5, lwidth(thick) lcolor(brown) ), ///
		legend( cols(4) ring(1) pos(6) order(2 4 6) label(2 "Our Baseline Results") ///
		 label(4 "Full Sample+" "Fan Liu Spec") label(6 "Manufacturing Sample+" "Fan Liu Spec")) ///
		xline(2015.5, lcolor(red)) yline(0, lcolor(red)) ylabel(#10, format(%9.2f)) ///
		xtitle(Year) ytitle("Difference-in-difference (2013 base)") xlabel(`min'(1)2016)
		graph export $output/fanliu_comparison2015`outcome'.pdf, replace
		
		
	twoway (scatter estimate2 year2, mcolor(black) ) (rspike min952 max952 year2, lwidth(thick) lcolor(navy) lpattern(dash) ) ///
	(scatter estimate4 year3, mcolor(black) ) (rcap min954 max954 year3, lwidth(thick) lcolor(red) ) ///
	(scatter estimate5 year4, mcolor(black) ) (rcap min955 max955 year4, lwidth(thick) lcolor(green) ) ///
	(scatter estimate6 year5, mcolor(black) ) (rcap min956 max956 year5, lwidth(thick) lcolor(purple)),   ///
	legend( cols(3) ring(1) pos(6) order(2 4 6 8) ///
	 label(2 "Manufacturing Control") ///
	label(4 "Balanced Sample") ///
	label(6 "Matched Sample" ) ///
	label(8 "Matching" "+ DFL Re-Weighting")) ///
		xline(2015.5, lcolor(red)) yline(0, lcolor(red)) ylabel(#10) ///
		xtitle(Year) ytitle("") xlabel(`min'(1)2016) ///
		name(robustness_did2015`outcome', replace) title("2015 Reform")
			
		graph export $output/robustness_did2015`outcome'.pdf, replace	
	restore
}


** Graph Combine 2014 and 2015 Results with Common Legend **


grc1leg robustness_did2014  robustness_did2015 , ycommon
graph export $output/did_robustness.pdf, replace


grc1leg robustness_did2014stock  robustness_did2015stock , ycommon
graph export $output/did_robustness_stock.pdf, replace



************************
* Combined Event Study *
************************


preserve
	set more off
	
	drop if treated2015 == 1
	gen treated = treated2014
	merge m:1 firm using $output/matched_sample2014_manufacturing.dta,  keep(3)

	gen time = year -2013 
	
	drop if business_revenue_100 <= 1
	
	winsor2 lnfixed_assets_net dlnfixed_assets_net, by(year treated) cut(1 99) replace
	
	gl group = "treated"
	gl base_year = 2013
	gl base_group = 1
	gl percentiles = 10
	gl weight = "cem_weight"
	gl variables = "business_revenue_100"
	
	winsor2 $variables, replace cut(1 99) by(treated year)

	do $code_other/dfl.do
	rename dfl_weight weight

	gen event = 2014
	bys firm: gen N = _N
	keep event time N treated indcode dlnfixed_assets_net lnfixed_assets_net years_since_entry ind3 year firm weight

	tempfile temp2014
	save "`temp2014'"
	
restore

preserve
	set more off
	
	drop if treated2014 == 1
	gen treated = treated2015
	merge m:1 firm using $output/matched_sample2015_manufacturing.dta,  keep(3)
	
	gen time = year -2014 
	
	drop if business_revenue_100 <= 1
	
	winsor2 lnfixed_assets_net dlnfixed_assets_net, by(year treated) cut(1 99) replace
	
	gl group = "treated"
	gl base_year = 2013
	gl base_group = 1
	gl percentiles = 10
	gl weight = "cem_weight"
	gl variables = "business_revenue_100"
	
	winsor2 $variables, replace cut(1 99) by(treated year)

	do $code_other/dfl.do
	rename dfl_weight weight

	gen event = 2015
	bys firm: gen N = _N
	
	keep event time N treated dlnfixed_assets_net lnfixed_assets_net year firm weight
	
	tempfile temp2015
	save "`temp2015'"	
restore

preserve	
	
	clear
	
	use "`temp2014'", clear
	append using "`temp2015'"
	
	replace time = time + 5
		
	reghdfe dlnfixed_assets_net c.treated#ib5.time ib5.time ib2014.year c.event##c.treated ///
	[aw=weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn_spec.dta, replace)		
	
		use $output/dyn_spec.dta, clear
	
		keep if strpos(parm,"time#c.treated")
		
		split parm, parse(".time")
		rename parm1 time
		destring time, replace
		set obs `=_N+1'
		replace time = 5 if mi(time)
		replace time = time - 5
		
		replace time = 0 if mi(time)
		replace estimate = 0 if time ==0
		replace min95 = 0 if time == 0
		replace max95 = 0 if time ==0	
		
		keep time estimate min max
		
		rename time year

		replace year = year 
		
		
		twoway (scatter estimate year, mcolor(black)) (rspike min95 max95 year, lwidth(thick) lcolor(brown) ), ///
		legend( cols(4) ring(1) pos(6) order(1 2) label(1 "Point Estimate") label(2 "95% CI")) xline(0) yline(0, lcolor(red)) ylabel(#10) ///
		xtitle(Year) ytitle("Difference-in-difference") xlabel(#5)

		graph export $output/robustness_dynamic_didcombined.pdf, replace
	
restore

preserve	
	
	clear
	
	use "`temp2014'", clear
	append using "`temp2015'"
	
	replace time = time + 5
		
	reghdfe lnfixed_assets_net c.treated#ib5.time ib5.time ib2014.year c.event##c.treated ///
	[aw=weight], cluster($cluster_var) absorb(firm)
	parmest, saving($output/dyn_spec.dta, replace)		
	
		use $output/dyn_spec.dta, clear
	
		keep if strpos(parm,"time#c.treated")
		
		split parm, parse(".time")
		rename parm1 time
		destring time, replace
		set obs `=_N+1'
		replace time = 5 if mi(time)
		replace time = time - 5
		
		replace time = 0 if mi(time)
		replace estimate = 0 if time ==0
		replace min95 = 0 if time == 0
		replace max95 = 0 if time ==0	
		
		keep time estimate min max
		
		rename time year

		replace year = year 
		
		
		twoway (scatter estimate year, mcolor(black)) (rspike min95 max95 year, lwidth(thick) lcolor(brown) ), ///
		legend( cols(4) ring(1) pos(6) order(1 2) label(1 "Point Estimate") label(2 "95% CI")) xline(0) yline(0, lcolor(red)) ylabel(#10) ///
		xtitle(Year) ytitle("Difference-in-difference") xlabel(#5)

		graph export $output/robustness_dynamic_didcombined_stock.pdf, replace
	
	
restore




