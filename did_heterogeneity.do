sort firm year
set more off
local cluster_var = "ind3"
pause on

**********************************
*Split Sample Heterogeneity Cuts *
**********************************

foreach inv_var in dlnfixed_assets_net lnfixed_assets_net  {
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
				
		* Winsorize Investment Variables 
		winsor2 `inv_var', by(year treated`year') cut(1 99) replace
		
		
		* Generate DiD Heterogeneity Indicators *
		
		* tax losses
		cap drop temp			
		gen temp = tax_loss if year == 2013
		bys firm: gegen tax_loss2013 = max(temp)
		drop temp
		
		* assets
		bys firm: gegen mean = mean(total_assets_zcfds  if inrange(year,2013,2013))
		gegen temp = cut(mean), group(2)
		bys firm: gegen high_assets = max(temp)
		drop temp mean

		* revenue
		bys firm: gegen mean = mean(business_revenue_100 if inrange(year,2013,2013))
		gegen temp = cut(mean), group(2)
		bys firm: gegen high_revenue = max(temp)
		drop temp mean
		
		* distance to bureau
		gegen temp = cut(logdistance) if year == 2013, group(2)
		bys firm: gegen high_distance = max(temp)
		drop temp 
		
		* bureau staffing
		gen staff = -lnbureaur
		gegen temp = cut(staff) if year == 2013, group(2)
		bys firm: gegen high_bureaustaff = max(temp)
		drop temp 
		
		* avg useful asset life of portfolio
		bys firm: gegen mean = mean(avg_useful_life if inrange(year,2013,2013))
		gegen temp = cut(mean), group(2)
		bys firm: gegen high_life= max(temp)
		drop temp mean
		
		* Cash holdings and interest dummies
		cap drop cash_ratio interest_dummy
		gen cash_ratio = cash_z / business_revenue
		
		bys firm: gegen mean = mean(cash_ratio if inrange(year,2013,2013))
		gegen temp = cut(mean), group(2)
		bys firm: gegen high_cash = max(temp)
		drop temp mean

		gen interest_dummy = interest_tax > 0 
		gen temp = interest_dummy if year == 2013
		bys firm: gegen interest_dummy2013 = max(temp)	
		drop temp	

		matrix storage = J(8,5,1)
	
		matrix rownames storage = Tax_Loss HNTE Asset_Life Cash_Holdings Interest_Expense Distance_to_Bureau Bureau_Staffing
		matrix colnames storage = low_coef low_coef_se high_coef high_coef_se test
	
		local index = 1
			
		foreach var in tax_loss2013 high_life high_cash interest_dummy hnte high_assets high_distance high_bureaustaff {
			
			
			qui reghdfe `inv_var' inter  ib`year'.year  ///
			`controls' if `var' ==0 [aw=weight], cluster(`cluster_var') `absorb'
			
			matrix results = e(b)
			matrix storage[`index',1] = results[1,1]
			matrix results = e(V)
			matrix storage[`index',2] = sqrt(results[1,1])


			qui reghdfe `inv_var' inter ib`year'.year  ///
			`controls' if `var' ==1 [aw=weight], cluster(`cluster_var') `absorb'
			
			matrix results = e(b)
			matrix storage[`index',3] = results[1,1]
			matrix results = e(V)
			matrix storage[`index',4] = sqrt(results[1,1])

			gen inter2 = inter*`var'
			
			reghdfe `inv_var' inter inter2 ib`year'.year##i.`var'  ///
			 [aw=weight], cluster(`cluster_var') `absorb'

			test inter2
			if r(p) < .1 local test = 1 
			if r(p) >= .1 local test = 0
			
			local test: di %4.3f r(p)
			matrix storage[`index',5] = `test'
			
			drop inter2
			local index = `index' + 1
			
			
			
		}
		
		clear
		
		svmat storage, names(col)

		gen low_coef_min = low_coef - 1.96*low_coef_se
		gen low_coef_max = low_coef + 1.96*low_coef_se
		
		gen high_coef_min = high_coef - 1.96*high_coef_se
		gen high_coef_max = high_coef + 1.96*high_coef_se
		
		gen split_id = _n // corresponds to the looping variables above
		
		
		save $output/split_sample_`year'.dta, replace
			
restore

					
			}	
	
	}




preserve

	use $output/split_sample_2014.dta, clear
	
	replace split_id = split_id*2 -1
	gen split_id2 = split_id + 1

	replace low_coef_min = low_coef_min*100
	replace low_coef_max = low_coef_max*100
	replace low_coef = low_coef*100
	
	replace high_coef_min = high_coef_min*100
	replace high_coef_max = high_coef_max*100
	replace high_coef = high_coef*100
	
	replace split_id = split_id + 1 if split_id > 8
	replace split_id2 = split_id2 + 1 if split_id2 > 8
	
	gen split_id3 = split_id2 - .5

	gen label = 7.5
		
	twoway ///
	(rcap low_coef_min low_coef_max split_id, horizontal) /// code for 95% CI
	(scatter split_id low_coef, mcolor(red) )  ///
	(rcap high_coef_min high_coef_max split_id2, horizontal) /// code for 95% CI
	(scatter split_id2 high_coef, mcolor(red) ) ///
	 (scatter split_id3 label, msym(none) mlabel(test) mlabpos(3)) ///
	, legend(off) /// legend at 6 o'clock position
	ylabel(1 "Not in Tax Losses" 2 "In Tax Losses"  3 "Below-Median Asset Life" 4 "Above-Median Asset Life" 5 "Below-Median Cash Holdings" ///
	6 "Above-Median Cash Holdings" ///
	7 "Did Not Claim Interest Expenses" 8 "Claimed Interest Expenses" ///
	10 "Not HNTE Firm" 11 "HNTE Firm" ///
	12 "Below-Median Total Assets" 13 "Above-Median Total Assets" ///
	14 "Below-Median Distance to Tax Bureau" 15 "Above-Median Distance to Tax Bureau" 16 "Below-Median Bureau Staffing" 17 "Above-Median Bureau Staffing", angle(0) noticks) ///
	/// note that the labels are 1.5, 4.5, etc so they are between rows 1&2, 4&5, etc.
	/// also note that there is a space in between different rows by leaving out rows 3, 6, 9, and 12 
	xlabel(#5, angle(0)) /// no 1.6 label
	xtitle("DiD Coefficient") /// 
	ytitle("") title("2014 Reform") /// 
	yscale(reverse) /// y axis is flipped 
	xline(0, lpattern(dash) lcolor(gs8)) name(het_2014, replace) fxsize(150) scale(1.4) 
	/// aspect (next line) is how tall or wide the figure is

	use $output/split_sample_2015.dta, clear
	
	gen label = 7.5

	replace split_id = split_id*2 -1
	gen split_id2 = split_id + 1
	
	replace split_id = split_id + 1 if split_id > 8
	replace split_id2 = split_id2 + 1 if split_id2 > 8
	
	gen split_id3 = split_id2 - .5
	
	replace low_coef_min = low_coef_min*100
	replace low_coef_max = low_coef_max*100
	replace low_coef = low_coef*100
	
	replace high_coef_min = high_coef_min*100
	replace high_coef_max = high_coef_max*100
	replace high_coef = high_coef*100
	
	twoway ///
	(rcap low_coef_min low_coef_max split_id, horizontal) /// code for 95% CI
	(scatter split_id low_coef, mcolor(red) ) ///
	(rcap high_coef_min high_coef_max split_id2, horizontal) /// code for 95% CI
	(scatter split_id2 high_coef, mcolor(red)  ) ///
	 (scatter split_id3 label, msym(none) mlabel(test) mlabpos(3)) ///
	, legend(off) /// legend at 6 o'clock position
	yscale(off) ylabel(1(1)17, grid) ///
	/// note that the labels are 1.5, 4.5, etc so they are between rows 1&2, 4&5, etc.
	/// also note that there is a space in between different rows by leaving out rows 3, 6, 9, and 12 
	xlabel(#5, angle(0)) /// no 1.6 label
	xtitle("DiD Coefficient") /// 
	ytitle("") title("2015 Reform") /// 
	yscale(reverse)  /// y axis is flipped
	xline(0, lpattern(dash) lcolor(gs8)) name(het_2015, replace) fxsize(75) scale(1.4) 
	/// aspect (next line) is how tall or wide the figure is
	
	graph combine het_2014 het_2015, xcommon
	
	graph export $output/did_heterogeneity_graph_`inv_var'.pdf, replace
	
restore

}




***********************
* By Revenue Quartiles *
***********************

foreach year in 2014 2015  {

*******************************************************************************
* Loop Over the Control Group Restrictions(Manufacturing-only, Multi-Industry,*
*                  All-Industry,  All-Industry-No-Matching                    *
*******************************************************************************
	
	foreach match_type in manufacturing  {
		foreach var in dlnfixed_assets_net lnfixed_assets_net  {
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
								
						* Winsorize Investment Variables 
						winsor2 `var', by(year treated`year') cut(1 99) replace
						
						

						* Revenue Deciles
						bys firm: gegen mean = mean(business_revenue_100 if inrange(year,2013,2013))
						gegen temp = cut(mean), group(4)
						bys firm: gegen decile = max(temp)
						
						fcollapse (p95) p95 = mean, merge 
						
					
						matrix storage = J(5,4,1)
					
						matrix colnames storage = coef se N endpoint
						
						 reghdfe `var' inter  ib`year'.year  ///
						`controls' if decile ==0 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[1,1] = results[1,1]
						matrix results = e(V)
						matrix storage[1,2] = sqrt(results[1,1])
						gunique firm if e(sample) == 1				
						matrix storage[1,3] = r(J) 
						su mean if decile == 0
						matrix storage[1,4] = r(min)

						 reghdfe `var' inter ib`year'.year  ///
						`controls' if decile ==1 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[2,1] = results[1,1]
						matrix results = e(V)
						matrix storage[2,2] = sqrt(results[1,1])
						gunique firm if e(sample) == 1				
						matrix storage[2,3] = r(J)
						su mean if decile == 1
						matrix storage[2,4] = r(min)

						qui reghdfe `var' inter ib`year'.year  ///
						`controls' if decile ==2 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[3,1] = results[1,1]
						matrix results = e(V)
						matrix storage[3,2] = sqrt(results[1,1])
						gunique firm if e(sample) == 1				
						matrix storage[3,3] = r(J)
						su mean if decile == 2
						matrix storage[3,4] = r(min)
						
						qui reghdfe `var' inter ib`year'.year  ///
						`controls' if decile ==3 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[4,1] = results[1,1]
						matrix results = e(V)
						matrix storage[4,2] = sqrt(results[1,1])
						gunique firm if e(sample) == 1				
						matrix storage[4,3] = r(J)
						su mean if decile == 3
						matrix storage[4,4] = r(min)
						
						qui reghdfe `var' inter ib2014.year  ///
						`controls' if mean >= p95 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[5,1] = results[1,1]
						matrix results = e(V)
						matrix storage[5,2] = sqrt(results[1,1])
						
						gunique firm if e(sample) == 1				
						matrix storage[5,3] = r(J)
						
						su mean if mean >= p95 
						matrix storage[5,4] = r(min)				
								
						clear
						
						svmat storage, names(col)
						
						gen decile = _n
						
						gen min = coef - 1.96*se
						gen max = coef + 1.96*se
						
							
						save $output/revenue_did_het_`year'`var'.dta, replace
							
				restore

				}	
			}	
	
	}
	
	 
preserve

		
		use $output/revenue_did_het_2014dlnfixed_assets_net.dta, clear
		gen year = 2014
		append using $output/revenue_did_het_2015dlnfixed_assets_net.dta
		replace year = 2015 if mi(year)
		
		gen decile2 = decile+.2
		replace min = min*100
		replace max = max*100
		replace coef = coef*100

		replace endpoint = endpoint / 1000000
		
		
		twoway ///
		(rcap min max decile if year == 2014 ) /// code for 95% CI
		(scatter coef decile if year == 2014 , mcolor(red)) ///
		(rcap min max decile2 if year == 2015 ) /// code for 95% CI
		(scatter coef decile2 if year == 2015,  mcolor(blue)) ///
		, legend(pos(6) order(2 4) label(2 "2014 Reform DiD") label(4 "2015 Reform DiD") cols(2)) /// legend at 6 o'clock position
		ylabel(#20, grid) ///
		xlabel(#5, angle(0)) /// no 1.6 label
		xtitle("Revenue Quartile (1 = Lowest, 4 = Highest, 5 = Top 5%)") /// 
		ytitle("Treatment Effect") /// 
		yline(0, lcolor(red)) scale(1.2)
		
		graph export $output/revenue_tercile_did1.pdf, replace

		keep endpoint decile year N
		gen var = "revenue"
		save $output/revenue_endpoints.dta, replace


restore	
	

preserve

		
		use $output/revenue_did_het_2014lnfixed_assets_net.dta, clear
		gen year = 2014
		append using $output/revenue_did_het_2015lnfixed_assets_net.dta
		replace year = 2015 if mi(year)
		
		gen decile2 = decile+.2
		
		replace min = min*100
		replace max = max*100
		replace coef = coef*100
		
		twoway ///
		(rcap min max decile if year == 2014 ) /// code for 95% CI
		(scatter coef decile if year == 2014 , mcolor(red)) ///
		(rcap min max decile2 if year == 2015 ) /// code for 95% CI
		(scatter coef decile2 if year == 2015,  mcolor(blue)) ///
		, legend(pos(6) order(2 4) label(2 "2014 Reform DiD") label(4 "2015 Reform DiD") cols(2)) /// legend at 6 o'clock position
		ylabel(#20, grid) ///
		xlabel(#5, angle(0)) /// no 1.6 label
		xtitle("Revenue Quartile (1 = Lowest, 4 = Highest, 5 = Top 5%)") /// 
		ytitle("Treatment Effect") /// 
		yline(0, lcolor(red)) scale(1.2)
		
		graph export $output/revenue_tercile_did2.pdf, replace

restore	


***********************
* By Asset Quartiles *
***********************

foreach year in 2014 2015  {

*******************************************************************************
* Loop Over the Control Group Restrictions(Manufacturing-only, Multi-Industry,*
*                  All-Industry,  All-Industry-No-Matching                    *
*******************************************************************************
	
	foreach match_type in manufacturing  {
		foreach var in dlnfixed_assets_net lnfixed_assets_net  {
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
								
						* Winsorize Investment Variables 
						winsor2 `var', by(year treated`year') cut(1 99) replace
						* Asset Deciles
						bys firm: gegen mean = mean(total_assets_zcfds if inrange(year,2013,2013))
						gegen temp = cut(mean), group(4)
						
						bys firm: gegen decile = max(temp)
						fcollapse (p95) p95 = mean, merge 
					
						matrix storage = J(5,4,1)
					
						matrix colnames storage = coef se N endpoint
						
						qui reghdfe `var' inter  ib`year'.year  ///
						`controls' if decile ==0 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[1,1] = results[1,1]
						matrix results = e(V)
						matrix storage[1,2] = sqrt(results[1,1])
						gunique firm if e(sample) == 1				
						matrix storage[1,3] = r(J) 
						su mean if decile == 0
						matrix storage[1,4] = r(min)



						qui reghdfe `var' inter ib`year'.year  ///
						`controls' if decile ==1 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[2,1] = results[1,1]
						matrix results = e(V)
						matrix storage[2,2] = sqrt(results[1,1])
						gunique firm if e(sample) == 1				
						matrix storage[2,3] = r(J) 
						su mean if decile == 1
						matrix storage[2,4] = r(min)


						qui reghdfe `var' inter ib`year'.year  ///
						`controls' if decile ==2 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[3,1] = results[1,1]
						matrix results = e(V)
						matrix storage[3,2] = sqrt(results[1,1])
						gunique firm if e(sample) == 1				
						matrix storage[3,3] = r(J) 
						su mean if decile == 2
						matrix storage[3,4] = r(min)

						qui reghdfe `var' inter ib`year'.year  ///
						`controls' if decile ==3 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[4,1] = results[1,1]
						matrix results = e(V)
						matrix storage[4,2] = sqrt(results[1,1])
						
						gunique firm if e(sample) == 1				
						matrix storage[4,3] = r(J)
						su mean if decile == 3
						matrix storage[4,4] = r(min)
							
						qui reghdfe `var' inter ib`year'.year  ///
						`controls' if mean >= p95 [aw=weight], cluster(`cluster_var') `absorb'
						
						matrix results = e(b)
						matrix storage[5,1] = results[1,1]
						matrix results = e(V)
						matrix storage[5,2] = sqrt(results[1,1])
						gunique firm if e(sample) == 1				
						matrix storage[5,3] = r(J) 						
						su mean if mean >= p95 
						matrix storage[5,4] = r(min)				
			
								
						
											
						clear
						
						svmat storage, names(col)
						
						gen decile = _n
						
						gen min = coef - 1.96*se
						gen max = coef + 1.96*se
						
							
						save $output/asset_did_het_`year'`var'.dta, replace
							
				restore

				}	
			}	
	
	}
	
	 
preserve

		
		use $output/asset_did_het_2014dlnfixed_assets_net.dta, clear
		gen year = 2014
		append using $output/asset_did_het_2015dlnfixed_assets_net.dta
		replace year = 2015 if mi(year)
		
		gen decile2 = decile+.2
		replace min = min*100
		replace max = max*100
		replace coef = coef*100
		
		replace endpoint = endpoint / 1000000

		
		twoway ///
		(rcap min max decile if year == 2014 ) /// code for 95% CI
		(scatter coef decile if year == 2014 , mcolor(red)) ///
		(rcap min max decile2 if year == 2015 ) /// code for 95% CI
		(scatter coef decile2 if year == 2015,  mcolor(blue)) ///
		, legend(pos(6) order(2 4) label(2 "2014 Reform DiD") label(4 "2015 Reform DiD") cols(2)) /// legend at 6 o'clock position
		ylabel(#20, grid) ///
		xlabel(#5, angle(0)) /// no 1.6 label
		xtitle("Asset Quartile (1 = Lowest, 4 = Highest, 5 = Top 5%)") /// 
		ytitle("Treatment Effect") /// 
		yline(0, lcolor(red)) scale(1.2)
		
		graph export $output/asset_tercile_did1.pdf, replace
	
		keep endpoint decile year N
		gen var = "asset"
		save $output/asset_endpoints.dta, replace

restore	
	

preserve

		
		use $output/asset_did_het_2014lnfixed_assets_net.dta, clear
		gen year = 2014
		append using $output/asset_did_het_2015lnfixed_assets_net.dta
		replace year = 2015 if mi(year)
		
		gen decile2 = decile+.2
		
		replace min = min*100
		replace max = max*100
		replace coef = coef*100
		
		twoway ///
		(rcap min max decile if year == 2014 ) /// code for 95% CI
		(scatter coef decile if year == 2014 , mcolor(red)) ///
		(rcap min max decile2 if year == 2015 ) /// code for 95% CI
		(scatter coef decile2 if year == 2015,  mcolor(blue)) ///
		, legend(pos(6) order(2 4) label(2 "2014 Reform DiD") label(4 "2015 Reform DiD") cols(2)) /// legend at 6 o'clock position
		ylabel(#20, grid) ///
		xlabel(#5, angle(0)) /// no 1.6 label
		xtitle("Asset Quartile (1 = Lowest, 4 = Highest, 5 = Top 5%)") /// 
		ytitle("Treatment Effect") /// 
		yline(0, lcolor(red)) scale(1.2)
		
		graph export $output/asset_tercile_did2.pdf, replace

restore	
	

*****************************************
* Table of Asset and Revenue End Points *
*****************************************



preserve
	
	use $output/asset_endpoints.dta, clear
	append using $output/revenue_endpoints.dta,

	reshape wide endpoint N, i(decile year) j(var) string
	reshape wide endpoint* N*, i(decile) j(year) 
	
	order endpointasset2014 endpointasset2015 endpointrevenue2014 endpointrevenue2015 Nasset2014 Nasset2015 Nrevenue2014 Nrevenue2015
	
	mkmat endpoint* N*, matrix(endpoints) rownames(decile)
	
	estout matrix(endpoints, fmt(2 2 2 2 0 0 0 0)) using $output/quartile_endpoints.tex, ///
	replace postfoot(" \bottomrule \end{tabular}") ///
	prehead("\begin{tabular}{lcccccccc} & \multicolumn{4}{c}{Left Endpoints of Quartiles} \multicolumn{4}{c}{Number of Firms}  \\ \toprule" ///
	" Quartile & \multicolumn{2}{c}{Total Assets} & \multicolumn{2}{c}{Revenue} & \multicolumn{2}{c}{Total Assets} & \multicolumn{2}{c}{Revenue}  \\ \midrule" ///
	"& 2014 & 2015 & 2014 & 2015 & 2014 & 2015 & 2014 & 2015  \\ \midrule") type collabels(none) style(tex) mlabels(none)

restore





preserve
	
	use $output/revenue_endpoints.dta, clear

	reshape wide endpoint N, i(decile year) j(var) string
	reshape wide endpoint* N*, i(decile) j(year) 
	
	order endpointrevenue2014 endpointrevenue2015 Nrevenue2014 Nrevenue2015
	
	mkmat endpoint* N*, matrix(endpoints) rownames(decile)
	
	estout matrix(endpoints, fmt(2 2 0 0)) using $output/quartile_endpoints_revenue.tex, ///
	replace postfoot(" \bottomrule \end{tabular}") ///
	prehead("\begin{tabular}{lcccc} \toprule Quartile & \multicolumn{2}{c}{Left Endpoints} & \multicolumn{2}{c}{Number of Firms}  \\ \midrule" ///
	"& 2014 & 2015 & 2014 & 2015  \\ \midrule") type collabels(none) style(tex) mlabels(none)

restore




preserve
	
	use $output/asset_endpoints.dta, clear

	reshape wide endpoint N, i(decile year) j(var) string
	reshape wide endpoint* N*, i(decile) j(year) 
	
	order endpointasset2014 endpointasset2015 Nasset2014 Nasset2015
	
	mkmat endpoint* N*, matrix(endpoints) rownames(decile)
	
	estout matrix(endpoints, fmt(2 2 0 0)) using $output/quartile_endpoints_asset.tex, ///
	replace postfoot(" \bottomrule \end{tabular}") ///
	prehead("\begin{tabular}{lcccc} \toprule Quartile & \multicolumn{2}{c}{Left Endpoints} & \multicolumn{2}{c}{Number of Firms}  \\ \midrule" ///
	"& 2014 & 2015 & 2014 & 2015  \\ \midrule") type collabels(none) style(tex) mlabels(none)

restore
