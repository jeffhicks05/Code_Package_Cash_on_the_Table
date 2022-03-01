sort firm year
set more off
local cluster_var = "ind3"
pause on

****************************************************
* Loop Over the 2014 and 2015 Targetted Industries *
****************************************************

foreach year in 2014 2015  {
	
	foreach match_type in manufacturing  {
	
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
					
		
		*******************************
		* Post and Post*Treated Dummy *
		*******************************
		
		
		local base = `year' -1 
		gen post = (year>`base')	
		gen inter = post*treated`year'
		
		local suffix = substr("`match_type'",1,1)
		local controls = ""
		local absorb = "absorb(firm) "
		xtset firm year
		* Generate Investment Variables *	
		
		foreach var in transport_production1 furniture_tools1 buildings_structures1  transportation1 electronic_equipment1 {
			replace `var' = 0 if mi(`var')
			bys firm: gegen mean_`var' = mean(`var' if year <=`base')
			gen ln`var' = ln(`var')
			gen growth_`var' = d.ln`var'
			gen growth2_`var' = `var' / mean_`var'
			replace growth2_`var' = . if  mi(growth_`var')
		
		}	
			
				
		* Winsorize Investment Variables 
		
	
		matrix storage = J(5,3,1)
	
		local index = 1
			
		foreach var in transport_production1 furniture_tools1 buildings_structures1  transportation1 electronic_equipment1 {
			
			winsor2 ln`var', by(year treated`year') cut(1 99) replace
		
			 qui reghdfe ln`var' inter  ib`year'.year  ///
			`controls' [aw=weight], cluster(ind3) `absorb'
			
			matrix results = e(b)
			matrix storage[`index',1] = results[1,1]
			matrix results = e(V)
			matrix storage[`index',2] = sqrt(results[1,1])
			matrix storage[`index',3] = e(N)

			local index = `index' + 1
		}
		
		clear
		
		svmat storage
		
		gen asset_type = _n
		
		save $output/did_asset_type_`year'.dta, replace
			
restore


			}	
	
	}




preserve

	use $output/did_asset_type_2014.dta, clear
	gen year = 2014
	append using $output/did_asset_type_2015.dta
	replace year = 2015 if mi(year)

	rename storage1 coef
	rename storage2 se
	gen min = coef -1.96*se
	gen max = coef + 1.96*se
	
	replace min = min*100
	replace max = max*100
	replace coef = coef*100

	gen asset_type2 = asset_type + .2

	twoway ///
	(rcap min max asset_type if year == 2014, horizontal lcolor(red)) /// code for 95% CI
	(scatter asset_type coef if year == 2014,  mcolor(red)) ///
	(rcap min max asset_type2 if year == 2015, horizontal lcolor(navy) lpattern(dash) ) /// code for 95% CI
	(scatter asset_type2 coef if year == 2015, mcolor(navy)) ///
	, legend(pos(6) order(2 4) label(2 "2014 Reform DiD") label(4 "2015 Reform DiD") cols(2)) /// legend at 6 o'clock position
	ylabel(1 "Production Equipment" 2 "Furniture and Tools"  3 "Buildings and Structures" 4 "Transportation" 5 "Electronics" , angle(0) noticks) ///
	/// note that the labels are 1.5, 4.5, etc so they are between rows 1&2, 4&5, etc.
	/// also note that there is a space in between different rows by leaving out rows 3, 6, 9, and 12 
	xlabel(#10, angle(0)) /// no 1.6 label
	xtitle("DiD Coefficient") /// 
	ytitle("") /// 
	yscale(reverse) /// y axis is flipped
	xline(0, lpattern(dash) lcolor(gs8)) name(het_2014, replace) fxsize(150)
	/// aspect (next line) is how tall or wide the figure is
	

	graph export $output/did_asset_type_graph_stock.pdf, replace
	
restore





foreach year in 2014 2015  {

	foreach match_type in manufacturing  {
	
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
					
		
		*******************************
		* Post and Post*Treated Dummy *
		*******************************
		
		local base = `year' -1 
		gen post = (year>`base')	
		gen inter = post*treated`year'
		
		local suffix = substr("`match_type'",1,1)
		local controls = ""
		local absorb = "absorb(firm) "
		xtset firm year
		* Generate Investment Variables *	
		
		foreach var in transport_production1 furniture_tools1 buildings_structures1  transportation1 electronic_equipment1 {
			replace `var' = 0 if mi(`var')
			gegen mean_`var' = mean(`var' if year <=`base')
			gen ln`var' = ln(`var')
			gen growth_`var' = d.ln`var'
			gen growth2_`var' = `var' / mean_`var'
			replace growth2_`var' = . if  mi(growth_`var')
		
		}	
	
		matrix storage = J(5,3,1)
	
		local index = 1
		* 2014 DiD 	
		foreach var in transport_production1 furniture_tools1 buildings_structures1  transportation1 electronic_equipment1 {
			
			winsor2  growth_`var', by(year treated`year') cut(1 99) replace

			 qui reghdfe  growth_`var' inter  ib`year'.year  ///
			`controls' [aw=weight], cluster(ind3) `absorb'
			
			matrix results = e(b)
			matrix storage[`index',1] = results[1,1]
			matrix results = e(V)
			matrix storage[`index',2] = sqrt(results[1,1])
			matrix storage[`index',3] = e(N)

			local index = `index' + 1
		}
		
		clear
		
		svmat storage
		
		gen asset_type = _n
		
		save $output/did_asset_type_`year'.dta, replace
			
restore


			}	
	
	}




preserve

	use $output/did_asset_type_2014.dta, clear
	gen year = 2014
	append using $output/did_asset_type_2015.dta
	replace year = 2015 if mi(year)

	rename storage1 coef
	rename storage2 se
	gen min = coef -1.96*se
	gen max = coef + 1.96*se
	
	replace min = min*100
	replace max = max*100
	replace coef = coef*100

	gen asset_type2 = asset_type + .2

	twoway ///
	(rcap min max asset_type if year == 2014, horizontal lcolor(red)) /// code for 95% CI
	(scatter asset_type coef if year == 2014,  mcolor(red)) ///
	(rcap min max asset_type2 if year == 2015, horizontal lcolor(navy) lpattern(dash) ) /// code for 95% CI
	(scatter asset_type2 coef if year == 2015, mcolor(navy)) ///
	, legend(pos(6) order(2 4) label(2 "2014 Reform DiD") label(4 "2015 Reform DiD") cols(2)) /// legend at 6 o'clock position
	ylabel(1 "Production Equipment" 2 "Furniture and Tools"  3 "Buildings and Structures" 4 "Transportation" 5 "Electronics" , angle(0) noticks) ///
	/// note that the labels are 1.5, 4.5, etc so they are between rows 1&2, 4&5, etc.
	/// also note that there is a space in between different rows by leaving out rows 3, 6, 9, and 12 
	xlabel(#10, angle(0)) /// no 1.6 label
	xtitle("DiD Coefficient") /// 
	ytitle("") /// 
	yscale(reverse) /// y axis is flipped
	xline(0, lpattern(dash) lcolor(gs8)) name(het_2014, replace) fxsize(150)
	/// aspect (next line) is how tall or wide the figure is
	

	graph export $output/did_asset_type_graph_growth.pdf, replace
	
restore

