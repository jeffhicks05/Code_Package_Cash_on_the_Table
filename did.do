sort firm year
set more off
local cluster_var = "ind3"
pause on

****************************************************
* Loop Over the 2014 and 2015 Targetted Industries *
****************************************************

foreach year in  2014 2015  {
		
	foreach match_type in manufacturing  {
	
	preserve
		drop if business_revenue_100 <= 1 
		xtset firm year

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
		bys firm: gen N = _N
		gen time = year - 2010

		local base = `year' -1 
		gen post = (year>`base')	
		gen inter = post*treated`year'
						
		
		* RD super deduction
		xtset firm year		
		replace ded_rd_107 = 0 if mi(ded_rd_107)
		gen claimed_rd = ded_rd_107 > 0
		bys firm: gegen ever_claimed_super_rd = max(claimed_rd)
		
		
		* cost of capital estimates
		
		merge 1:1 year firm using $output/tax_components.dta, nogen keep(1 3)
			
		gen logusercost = ln(tax_component)
		
		gen inter_claimed = claimed2*post
		
		local suffix = substr("`match_type'",1,1)
			
		local absorb = "absorb(firm)"
		
		foreach var in  dlnfixed_assets_net lnfixed_assets_net capex_sales dlnfixed_assets1 {
			
			winsor2 `var' , by(year treated`year') cut(1 99) replace
	
			
			***********************************	
			* Pooled Difference in Difference *	
			***********************************

			eststo `var'`suffix'`year': reghdfe `var' inter ib`base'.year ///
			`controls' [aw=weight], cluster(`cluster_var') `absorb'

			unique firm if e(sample) & treated`year' == 1
			estadd scalar firms_treated = `r(unique)'
			unique firm if e(sample) & treated`year' == 0
			estadd scalar firms_control = `r(unique)'
			sum `var' if inrange(year,2011,2013)  & treated`year'==1 & e(sample) [aw=weight]
			estadd scalar mean_dep = `r(mean)'*100
			unique `cluster_var' if treated`year' == 1
			estadd scalar treated_clusters = `r(unique)'
			unique `cluster_var' if treated`year' == 0 
			estadd scalar untreated_clusters = `r(unique)'
			
			* user cost regression
			
			
			eststo U`var'`suffix'`year': ivreghdfe  `var'  ///
			ib`base'.year `controls' (logusercost = inter) [aw=weight], `absorb' cluster(`cluster_var') first
			
			unique firm if e(sample) & treated`year' == 1
			estadd scalar firms_treated = `r(unique)'
			unique firm if e(sample) & treated`year' == 0
			estadd scalar firms_control = `r(unique)'
			sum `var' if year == `base' & treated`year'==1 & e(sample) [aw=weight]
			estadd scalar mean_dep = `r(mean)'
			unique `cluster_var' if treated`year' == 1
			estadd scalar treated_clusters = `r(unique)'
			unique `cluster_var' if treated`year' == 0 
			estadd scalar untreated_clusters = `r(unique)'
			
			*drop logusercost
			
			* linear time trends by industry 
			
			eststo J`var'`suffix'`year': reghdfe `var' inter c.time#i.ind3 c.time ib`base'.year ///
			`controls' [aw=weight], cluster(`cluster_var') `absorb'

			unique firm if e(sample) & treated`year' == 1
			estadd scalar firms_treated = `r(unique)'
			unique firm if e(sample) & treated`year' == 0
			estadd scalar firms_control = `r(unique)'
			sum `var' if inrange(year,2011,2013)  & treated`year'==1 & e(sample) [aw=weight]
			estadd scalar mean_dep = `r(mean)'*100
			unique `cluster_var' if treated`year' == 1
			estadd scalar treated_clusters = `r(unique)'
			unique `cluster_var' if treated`year' == 0 
			estadd scalar untreated_clusters = `r(unique)'
			estadd local linear "Yes"
			
			
			* excluding firms that clim RD super deductions 
			
			eststo RD`var'`suffix'`year': reghdfe `var' inter ib`base'.year ///
			`controls' if ever_claimed_super_rd == 0  [aw=weight], cluster(`cluster_var') `absorb'

			unique firm if e(sample) & treated`year' == 1
			estadd scalar firms_treated = `r(unique)'
			unique firm if e(sample) & treated`year' == 0
			estadd scalar firms_control = `r(unique)'
			sum `var' if inrange(year,2011,2013)  & treated`year'==1 & e(sample) [aw=weight]
			estadd scalar mean_dep = `r(mean)'*100
			unique `cluster_var' if treated`year' == 1
			estadd scalar treated_clusters = `r(unique)'
			unique `cluster_var' if treated`year' == 0 
			estadd scalar untreated_clusters = `r(unique)'
	
			* excluding SMPE firms 
			
			eststo SM`var'`suffix'`year': reghdfe `var' inter ib`base'.year ///
			`controls' if sme == 0 [aw=weight], cluster(`cluster_var') `absorb'

			unique firm if e(sample) & treated`year' == 1
			estadd scalar firms_treated = `r(unique)'
			unique firm if e(sample) & treated`year' == 0
			estadd scalar firms_control = `r(unique)'
			sum `var' if inrange(year,2011,2013)  & treated`year'==1 & e(sample) [aw=weight]
			estadd scalar mean_dep = `r(mean)'*100
			unique `cluster_var' if treated`year' == 1
			estadd scalar treated_clusters = `r(unique)'
			unique `cluster_var' if treated`year' == 0 
			estadd scalar untreated_clusters = `r(unique)'
		


		}				
	
	restore
		
	
	}	
}
