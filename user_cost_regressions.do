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
			
		rename tax_component usercost
		
		gen logusercost = ln(usercost)
		
		gen inter_claimed = claimed2*post
		
		
		
		local suffix = substr("`match_type'",1,1)
			
		local absorb = "absorb(firm)"
		
		foreach var in  dlnfixed_assets_net  {
			
			winsor2 `var' , by(year treated`year') cut(1 99) replace
	
			
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
			
			
			
			eststo L`var'`suffix'`year': ivreghdfe  `var'  ///
			ib`base'.year `controls' (usercost = inter) [aw=weight], `absorb' cluster(`cluster_var') first
			
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
						
			
			
}

restore
}
}


* user cost  *
estout Udlnfixed_assets_netm2014 Udlnfixed_assets_netm2015  Ldlnfixed_assets_netm2014 Ldlnfixed_assets_netm2015 ///
	using $output/table_usercost.tex, replace ///
	keep(logusercost usercost) ///
	order(logusercost usercost) ///
	refcat(inter_loss "Treated $\times$ Post",nolabel) level(90)  ///
	style(tex) nolegend noomitted eqlabels(none) collabels(none) nobaselevels ///
	mlabels("2014" "2015" "2014" "2015")  ///	
	mgroups("\$ Ln(K_t) - Ln(K_{t-1})\$" , ///
	prefix(\multicolumn{@span}{c}{) suffix(})  span erepeat(\cmidrule(lr){@span}) pattern(1 0 0 0 )) ///
	varlabels(logusercost "\$ Ln(\frac{1-\tau Z}{1-Z}) \$"  ///
	usercost "\$ \frac{1-\tau Z}{1-Z} \$" ///
	, end("" \addlinespace))  label type ///
	cells("b(star fmt(%9.2f) label(Coef))" "ci(par fmt(%9.2f) pattern(1 1 1 1))" ) ///
	stats(N firms_treated firms_control ,  ///
	fmt(0 0 0 0 0 2 2 2 3 2) labels("N" "Treated Firms" "Untreated Firms") ) ///
	prehead("\begin{tabular}{lcccc}" "\multicolumn{5}{c}{Cost of Capital Elasticity Estimates (2SLS)} \\ \midrule"  )  ///
	posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)
