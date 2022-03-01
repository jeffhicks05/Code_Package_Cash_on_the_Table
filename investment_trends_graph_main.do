sort firm year
set more off
local cluster_var = "ind3"
pause on

****************************************************
* Loop Over the 2014 and 2015 Targetted Industries *
****************************************************

foreach year in 2015 2014   {

*******************************************************************************
* Loop Over the Control Group Restrictions(Manufacturing-only, Multi-Industry,*
*                  All-Industry,  All-Industry-No-Matching                    *
*******************************************************************************
	
	foreach match_type in manufacturing  {
	
	foreach var in  lnfixed_assets_net  dlnfixed_assets_net   {

	preserve
		drop if business_revenue_100 <= 1
		
		********************************************
		* Keep Matched Sample and Merge in Weights *
		********************************************
		
		if "`match_type'" != "nomatch" merge m:1 firm using $output/matched_sample`year'_`match_type'.dta,  keep(3)
		else {
		keep if treated`year' == 1 | indcode == 10
		gen cem_weight = 1 
		}
		
		if `year' == 2014 drop if treatment == 2
		if `year' == 2015 drop if treatment == 1
		
		********************
		* DFL Re-Weighting *
		********************
		
		gl group = "treated`year'"
		gl base_year = 2013
		gl base_group = 1
		gl percentiles = 10
		gl weight = "cem_weight"
		gl variables = "business_revenue_100"
		
		winsor2 $variables, replace cut(1 99) by(treated`year' year)

		do $code_other/dfl.do
		
		rename dfl_weight weight
		if "`match_type'" == "nomatch"	replace weight = 1
		
		
			
		*******************
		* Other Variables *
		*******************
		gen treated= treated`year'

		local base = `year' -1 
		gen post = (year>`base')	
		gen inter = post*treated
		
		local suffix = substr("`match_type'",1,1)
			
		winsor2 `var' , by(year treated`year') cut(1 99) replace

		*****************
		* Visual Trends *
		*****************
		
		forvalues y = 2010(1)2016 {
			
			gen year`y' = year == `y'
			gen inter`y' = year`y'*treated
		
		}

		reghdfe `var' inter2010 inter2011 inter2012 inter2014 inter2015 inter2016 ///
		year2010 year2011 year2012 year2014 year2015 year2016 [aw=weight], ///
		residuals(residual) absorb(firm) cluster(ind3)	
			
				
		matrix storage = J(14,4,1)
		local index = 1
		foreach y in 2010 2011 2012 2013 2014 2015 2016 {
		
			if `y' == 2013 lincom  _cons 
			else lincom  _cons + year`y'
			
			matrix storage[`index',1] = r(estimate)
			matrix storage[`index',2] = r(estimate) - 1.96*r(se)
			matrix storage[`index',3] = r(estimate) + 1.96*r(se)
			matrix storage[`index',4] = 0
			
			local index = `index' + 1
		}
		foreach y in 2010 2011 2012 2013 2014 2015 2016 {
			
			if `y' == 2013 lincom  _cons 
			else lincom  _cons + year`y' + inter`y'
			
			matrix storage[`index',1] = r(estimate)
			matrix storage[`index',2] = r(estimate) - 1.96*r(se)
			matrix storage[`index',3] = r(estimate) + 1.96*r(se)
			matrix storage[`index',4] = 1
			local index = `index' + 1
			
		}		
		
		
		clear
		svmat storage, names(col)
		
		rename c1 b
		rename c2 min95
		rename c3 max95
		rename c4 treated
		bys treated: gen year = 2009 +_n
		
		if "`var'" == "dlnfixed_assets_net" drop if year <= 2012
		if "`var'" == "lnfixed_assets_net" drop if year <= 2011
		if "`var'" == "dlnfixed_assets1" drop if year == 2010

		
		replace year = year -.05 if treated == 0
		replace year = year + .05 if treated == 1
		
		
		if "`var'" == "dlnfixed_assets_net" local label = "ylabel(#10, format(%9.2f))"
		if "`var'" == "lnfixed_assets_net" local label = "ylabel(#10, format(%9.2f))"
		else local label = "ylabel(#10, format(%9.2f))"
		local min = 2010
		if inlist("`var'", "dlnfixed_assets_net", "lnfixed_assets_net","growth_net", "growth2_net", "capex_sales") local min = 2012
		local line = `year' - .5
		
		twoway (connected b year if treated == 0, lwidth(medthick) lpattern(solid) lcolor(navy)) ///
		(rcap min95 max95 year if treated == 0, lwidth(medthick) lpattern(solid) lcolor(navy)) ///
		(connected b year if treated == 1, lwidth(medthick) lpattern(dash) lcolor(brown)) ///
		(rcap min95 max95 year if treated == 1, lwidth(medthick) lpattern(dash) lcolor(brown)), ///
		xline(`year', lpattern(solid) lwidth(medium) lcolor(red)) xlabel(`min'(1)2016) `label' ///
		scale(1.2) legend(pos(6) order(2 4) cols(2) label(2 "Non-Targeted Firms") label(4 "Targeted Firms")) xtitle(Year) ytitle(Mean)
		
		graph export $output/`var'_matched`year'`suffix'.pdf, replace			
		
	restore	
	 
	}				
	}			
}			
