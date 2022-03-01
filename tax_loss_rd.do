preserve
	drop if business_revenue_100 <= 1 | mi(business_revenue_100)

	gen lagratio2 = (taxable_income2 -loss_carryove + fixed_assets9)/ total_assets			
	xtset firm year

	gen preyear = 2013 if treated2014 == 1
	replace preyear = 2014 if treated2015==1
	keep if (treated2014 == 1 | treated2015 == 1)
	set more off
	local index = 1
	
	
	foreach var in transport_production furniture_tools buildings_structures transportation electronic_equipment {
		replace `var'9 = 0 if mi(`var'9)
		replace `var'1 = 0 if mi(`var'1)
		
		xtset firm year
		gen cl_`index' = (`var'9 - l.`var'9 > 0 ) if !mi(l.`var'9)
		replace cl_`index' = (`var'9 > 0) if mi(l.`var'9)
		gen change_`index' = (`var'1  - l.`var'1 >0 ) if !mi(l.`var'1)
		replace change_`index' = (`var'1 >0) if mi(l.`var'9)

		local index = `index' + 1
		
	}

	rename bureau bureau2
	gegen bureau= group(bureau2)
	drop if year <= preyear
	
	keep firm year lagratio2 change_* cl_* business_revenue_100 taxable_income2
	reshape long cl_ change_ ,  i(firm year) j(asset_class)

	rename change_ change
	rename cl_ claimed2
	keep if change == 1

	
	
	keep if inrange(lagratio, -.2,.2)

	gen bins = autocode(lagratio, 20,-.2,.2) 
	replace bins = 0 if inrange(bins,-.01,0)

	gcollapse (mean) claimed2 (semean) se = claimed2 , by(bins)
	
	gen min = claimed2 - 1.96*se
	gen max = claimed2 + 1.96*se

	sort bins
	
	twoway (scatter claimed2 bins, mcolor(navy) msymbol(O) msize(medium)) (rspike min max bins, lcolor(navy) lwidth(thick)) , ///
	 xlabel(#15) scale(1.2) ylabel(#8) name(g2, replace) ///
	legend(pos(6) region(fcolor(none)) cols(3)  ///
	label(1 "Average Take-Up Rate") label(2 "95% Confidence Interval")) ///
	 xline(0, lcolor(red) lpattern(solid))  ///
	xtitle("Uncensored Taxable Income Before AD Deduction / Total Assets")  ytitle(Take-Up Rate)
	
	graph export $output/takeup_rate_discontinuity.pdf, replace

restore
