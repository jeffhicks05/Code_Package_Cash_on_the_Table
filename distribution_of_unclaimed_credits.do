set more off

preserve
	xtset firm year
	drop if taxable_income_100 == 0 | fixed_assets1 == 0 
	
	gen implicit_rate = total_income_tax / taxable_income_100ds
	
	gen preyear = 2013 if treated2014 == 1
	replace preyear = 2014 if treated2015==1
	keep if (treated2014 == 1 | treated2015 == 1)
	
	local index = 1
	foreach var in transport_production furniture_tools buildings_structures transportation electronic_equipment {
		
		replace `var'9 = 0 if mi(`var'9)
		replace `var'1 = 0 if mi(`var'1)
		
		xtset firm year
		
		gen cl_`index' = (`var'9 - l.`var'9 > 0 ) if !mi(l.`var'9)
		replace cl_`index' = (`var'9 > 0) if mi(l.`var'9)
		
		gen level_change`index' = `var'1 - l.`var'1
		local index = `index' + 1
		
	}

	drop if year < 2013
			
	keep level_change* year treated2014 treated2015 implicit_rate treated2014 firm preyear cl_* ind2 total_income_tax

	reshape long cl_ change_ logchange level_change,  i(firm year) j(asset_class)

	rename change_ change
	rename cl_ claimed2
		
	keep if (year >2013 & treated2014 ==1 ) | (year > 2014 & treated2015 == 1)
	
	keep if level_change > 0
	
	gen loginvest = ln(level_change)
	
	twoway (kdensity loginvest if claimed2 == 1, lcolor(blue)) (kdensity loginvest if claimed2 == 0, lcolor(red)), ///
	legend(pos(6) cols(2) label(1 "Claimed AD") label(2 "Did Not Claim AD")) xlabel(#10) ylabel(#10)  xtitle(Log Investment) ///
	ytitle(Estimated Density)
	
	graph export $output/investment_by_claim.pdf, replace
	

	gen npvB =  .566 if asset_class == 3
	replace npvB =  .752 if asset_class == 1
	replace npvB =  .877 if asset_class == 2
	replace npvB =  .906 if asset_class == 4
	replace npvB =  .936 if asset_class == 5
	
	gen npvA =  .708 if asset_class == 3
	replace npvA =  .85 if asset_class == 1
	replace npvA =  .936 if asset_class == 2
	replace npvA =  .936 if asset_class == 4
	replace npvA =  .967 if asset_class == 5
	
	
	gen savings = implicit_rate*(npvA - npvB)*level_change
	replace savings = implicit_rate*(1 - npvB)*level_change if level_change < 5000
	
	winsor2 savings, cut(1 99) replace by(treated2014)
	reg savings claimed i.treated2014 i.asset_class
	gen lnsavings = ln(savings)
		
	bys claimed2: su savings, d
	
	
	gcollapse (sum) savings (firstnm) treated2014, by(firm claimed )
	
	
	gcollapse (mean) mean = savings (semean) se = savings (p50)  median = savings (sum) total = savings, by(claimed treated2014)
	
	replace mean = mean / 1000
	replace median = median / 1000
	replace total = total / 1000
	reshape wide mean median total se, i(treated) j(claimed)
	
	tostring treated2014, replace
	replace treated2014 = "treated2014" if treated2014 == "1"
	replace treated2014 = "treated2015" if treated2014 == "0"
	sort treated2014
	
	mkmat mean0 median0 total0 mean1 median1 total1, matrix(results) rownames(treated2014) 
	
	
	estout matrix(results, fmt(2 2 0 2 2 0)) using $output/tax_savings.tex, replace style(tex) nolegend ///
	prehead( "\begin{tabular}{lcccccc} \toprule" "Treatment Group & \multicolumn{3}{c}{Not Claimed} & \multicolumn{3}{c}{Claimed} \\ \midrule" ///
	" & Mean & Median & Total & Mean & Median & Total \\ \midrule ") collabels(none)  ///
	postfoot(" \bottomrule \end{tabular}") mlabel(none) substitute(treated2014 "2014 Treatment Group" treated2015 "2015 Treatment Group") type

	
restore

