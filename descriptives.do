/* This do file creates:

(1) the full sample descriptives 
(2) histograms of the tax administration variables (appendix)
(3) the boxplot graph of AD amounts, Figure 4 Panel B
(4) the take-up rate (firm-level unconditional on investment) by industry appendix table, Appendix
(5) the take-up rate (unconditional on investment) time trend, Figure 5 panel A
(6) the take-up reate (conditional on investment) time trend fro largest 5% of firms, Appendix.
*/

preserve

	keep if treated2014 == 1 | treated2015 == 1 | indcode == 10
	set more off
	xtset firm year
	
	* Rev Growth *
	gen rev_growth = (business_revenue - l.business_revenue ) / (business_revenue/2 + l.business_revenue/2 )	
	replace rev_growth = 0 if business_revenue == 0 & l.business_revenue==0
	
	replace tax_loss_stock = . if tax_loss_stock == 0
	
	replace treatment_status = 0 if treatment_status == 3
	keep if year ==2013

	* Cash ETR *
*	gen cash_etr= total_income_tax_100 / total_profit_lrbds 
	
	local vars = "total_assets_z fixasset_undep fixed_assets1 avg_useful_life business_revenue rev_growth taxable_income_100 tax_loss tax_loss_stock cash_ratio interest_dummy age employees soe hnte sme distance bureau_employee_ratio"

	matrix storage = J(18,6,1)
	
	matrix rownames storage = Total_Assets Fixed_Assets_Net_of_Depreciation Fixed_Assets_Historical_Cost Average_Useful_Life Business_Revenue Revenue_Growth Taxable_Income  ///
	Percent_In_Tax_Losses Tax_Loss_Stock Cash_Holdings_;_Total_Assets Claimed_Interest Age Employees State_or_Collectively_Owned High_and_New_Tech_Enterprise ///
	Small_or_Micro_Enterprise_(SME) Distance_to_Tax_Bureau_(km) :_Firms_per_Tax_Administrator
	
	matrix colnames storage = Mean N Mean N Mean N 
	local index = 1
	foreach var of local vars {
		winsor2 `var', cut(1 99) replace by(treatment)
	}
	*winsor2 cash_etr, replace cut(5 95) by(treatment)
	
	replace total_assets_z = total_assets_z / 10000
	replace fixasset_undep = fixasset_undep  /10000
	replace fixed_assets1 = fixed_assets1  /10000
	replace business_revenue = business_revenue / 10000
	replace taxable_income_100 = taxable_income_100 / 10000
	replace tax_loss_stock = tax_loss_stock / 10000
	
	foreach var of local vars {
		
		if inlist(`index',1,2,3,5,7,9,18) local round = 0
		else local round = 2
				
		su `var' if treatment_status == 0 
		local mean: di %7.`round'f `r(mean)'
		local sd: di %7.`round'f `r(sd)'
		matrix storage[`index',1] = `mean'
		matrix storage[`index',2] = `r(N)'
		
		su `var' if treatment_status == 1 
		local mean: di %7.`round'f `r(mean)'
		local sd: di %7.`round'f `r(sd)'
		matrix storage[`index',3] = `mean'
		matrix storage[`index',4] = `r(N)'

		su `var' if treatment_status == 2
		local mean: di %7.`round'f `r(mean)'
		local sd: di %7.`round'f `r(sd)'
		matrix storage[`index',5] = `mean'
		matrix storage[`index',6] = `r(N)'
			
		local index = `index' + 1
		
	}	
	
	estout matrix(storage) using $output/descriptives_table_small.tex, replace style(tex) nolegend ///
	prehead( "\begin{tabular}{lcccccc} \toprule & \multicolumn{2}{c}{Non-Targeted} & \multicolumn{2}{c}{2014 Targeted} & \multicolumn{2}{c}{2015 Targeted} \\ & \multicolumn{2}{c}{Industries} & \multicolumn{2}{c}{Industries} & \multicolumn{2}{c}{Industries} \\ \midrule") ///
	posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") mlabel(none) substitute(: "\#" _ " " ; "/") type

restore


preserve

	keep if year == 2013 & (treated2014 == 1 | treated2015 == 1)
	
	histogram distance, color(blue) xtitle("Distance (Km)") ytitle(Firms)  frequency 
	
	graph export $output/distance_density.pdf, replace
	
	histogram lnbureauratio,  color(blue)  frequency  ///
	  xtitle(Log(# of Firms per Tax Administrator)) ytitle(Firms)
	graph export $output/bureau_density.pdf, replace
	
restore

preserve

	gen preyear = 2013 if treated2014 == 1
	replace preyear = 2014 if treated2015 ==1
	
	keep if year > =preyear
	
	gcollapse (first) claimed2 ind2, by(firm)
	
	estpost tabstat claimed2, statistics(mean) columns(statistics) by(ind2) 
	eststo type
	estout type using $output/takeup_by_industry.tex, cells("mean(label(Take-up Rate) fmt(%9.3f))") type ///
	   varlabels(`e(labels)', end(""))  ///
	   style(tex) nonumber replace unstack mlabel(none) collabel(none) eqlabels(none) ///
	    prehead("\begin{tabular}{lc}" "\toprule" "& Claim Rate \\ \midrule") postfoot("\bottomrule \end{tabular}")
	
restore


preserve

	keep if fixed_assets9> 0 | fixed_assets10 > 0
	gen AD = fixed_assets9 
	replace AD = fixed_assets9 + fixed_assets10 if fixed_assets9 != fixed_assets10
	winsor2 AD , replace cut(25 75) by(year treatment)
	replace AD = AD / 1000
	
	graph box AD if year > 2013, over(year) over(treatment) nooutsides asyvars ylabel(#14) ytitle("AD Amount (CNY 1000s)") ///
	 legend(pos(6) cols(3) label(1 "2014") label(2 "2015") label(3 "2016"))  note("") scale(1.15)
	 
	 graph export $output/AD_boxplot.pdf, replace

restore

* further trends by asset type constructed further down *
preserve

	gen claimedacc = fixed_assets9 > 0 | fixed_assets10 > 0
	replace claimedacc = claimedacc
	binscatter claimedacc year if year > 2013,  mcolor(blue brown black) lcolor(blue brown black) ///
	msymbol(Oh D Dh)by(treatment_status) ytitle(Fraction) xtitle(Year) scale(1.2) xlabel(#3) ///
	discrete line(connect) legend(pos(11) ring(0) cols(1)label(1 "Control Industries") label(2 "2014 Targeted Industries") label(3 "2015 Targeted Industries"))
	graph export $output/claim_trends1.pdf, replace
restore


preserve
	bys firm: gegen mean = mean(business_revenue_100 if inrange(year,2013,2013))
	
	fcollapse (p95) p95 = mean, merge 


	replace treatment_status = 3 if treatment_status == 0 & mean >= p95
	replace treatment_status = 4 if treatment_status == 1 & mean >= p95
	replace treatment_status = 5 if treatment_status == 2 & mean >= p95
	
	gen claimedacc = fixed_assets9 > 0 | fixed_assets10 > 0
	
	keep if year > 2013
	
	gcollapse (mean) claimedacc , by(year treatment_status)
	
	
	twoway (connected claimedacc year if treatment_status == 0, lcolor(blue) msize(medlarge) lpattern(solid) mcolor(blue) msymbol(S)) ///
	(connected claimedacc year if treatment_status == 3, lcolor(blue) msize(medlarge)  lpattern(dash) mcolor(blue) msymbol(Oh)) ///
	(connected claimedacc year if treatment_status == 1, lcolor(red) msize(medlarge)  lpattern(solid) mcolor(red) msymbol(S)) ///
	(connected claimedacc year if treatment_status == 4, lcolor(red) msize(medlarge)  lpattern(dash) mcolor(red) msymbol(Oh)) ///
	(connected claimedacc year if treatment_status == 2, lcolor(brown) msize(medlarge)  lpattern(solid) mcolor(brown) msymbol(S)) ///
	(connected claimedacc year if treatment_status == 5, lcolor(brown) msize(medlarge)  lpattern(dash) mcolor(brown) msymbol(Oh)), ///
	 ytitle(Fraction) xtitle(Year) xlabel(#3) ///
	legend(pos(11)  cols(2) label(1 "Control Industries, Bottom 95%") label(2 "Control Industries, Top 5%")  ///
	label(3 "2014 Targeted Industries, Bottom 95%") label(5 "2015 Targeted Industries, Bottom 95%") ///
	label(4 "2014 Targeted Industries, Top 5%") label(6 "2015 Targeted Industries, Top 5%") bmargin(zero))
	graph export $output/claim_trends1_p95.pdf, replace
restore



preserve
	bys firm: gegen mean = mean(business_revenue_100 if inrange(year,2013,2013))

	fcollapse (p95) p95 = mean, merge 

	xtset firm year
	gen invest = fixed_assets_net > l.fixed_assets_net
	
	bys firm: gegen max = max(invest if year > 2013)
	bys firm: gegen min = max(tax_loss if year > 2013)
	
	
	
	keep if max == 1 

	replace treatment_status = 3 if treatment_status == 0 & mean >= p95
	replace treatment_status = 4 if treatment_status == 1 & mean >= p95
	replace treatment_status = 5 if treatment_status == 2 & mean >= p95
	
	gen claimedacc = fixed_assets9 > 0 | fixed_assets10 > 0
	
	keep if year > 2013
	
	gcollapse (mean) claimedacc , by(year treatment_status)
	
	
	twoway (connected claimedacc year if treatment_status == 0, lcolor(blue) msize(medlarge) lpattern(solid) mcolor(blue) msymbol(S)) ///
	(connected claimedacc year if treatment_status == 3, lcolor(blue) msize(medlarge)  lpattern(dash) mcolor(blue) msymbol(Oh)) ///
	(connected claimedacc year if treatment_status == 1, lcolor(red) msize(medlarge)  lpattern(solid) mcolor(red) msymbol(S)) ///
	(connected claimedacc year if treatment_status == 4, lcolor(red) msize(medlarge)  lpattern(dash) mcolor(red) msymbol(Oh)) ///
	(connected claimedacc year if treatment_status == 2, lcolor(brown) msize(medlarge)  lpattern(solid) mcolor(brown) msymbol(S)) ///
	(connected claimedacc year if treatment_status == 5, lcolor(brown) msize(medlarge)  lpattern(dash) mcolor(brown) msymbol(Oh)), ///
	 ytitle(Fraction) xtitle(Year) xlabel(#3) ///
	legend(pos(11)  cols(2) label(1 "Control Industries, Bottom 95%") label(2 "Control Industries, Top 5%")  ///
	label(3 "2014 Targeted Industries, Bottom 95%") label(5 "2015 Targeted Industries, Bottom 95%") ///
	label(4 "2014 Targeted Industries, Top 5%") label(6 "2015 Targeted Industries, Top 5%") bmargin(zero))
	graph export $output/claim_trends1_p95_conditional.pdf, replace
restore



preserve
	bys firm: gegen mean = mean(business_revenue_100 if inrange(year,2013,2013))

	fcollapse (p95) p95 = mean, merge 


	xtset firm year
	gen invest = fixed_assets_net > l.fixed_assets_net
	
	bys firm: gegen max = max(invest if year > 2013)
	keep if max == 1 

	replace treatment_status = 3 if treatment_status == 0 & mean >= p95
	replace treatment_status = 4 if treatment_status == 1 & mean >= p95
	replace treatment_status = 5 if treatment_status == 2 & mean >= p95
	
	gen claimedacc = fixed_assets9 > 0 | fixed_assets10 > 0
	
	keep if year > 2013
	
	bys firm: gegen everclaim = max(claimedacc)
	
	
	gcollapse (mean) invest , by(year treatment_status)
	
	
	twoway (connected invest year if treatment_status == 0, lcolor(blue) msize(medlarge) lpattern(solid) mcolor(blue) msymbol(S)) ///
	(connected invest year if treatment_status == 3, lcolor(blue) msize(medlarge)  lpattern(dash) mcolor(blue) msymbol(Oh)) ///
	(connected invest year if treatment_status == 1, lcolor(red) msize(medlarge)  lpattern(solid) mcolor(red) msymbol(S)) ///
	(connected invest year if treatment_status == 4, lcolor(red) msize(medlarge)  lpattern(dash) mcolor(red) msymbol(Oh)) ///
	(connected invest year if treatment_status == 2, lcolor(brown) msize(medlarge)  lpattern(solid) mcolor(brown) msymbol(S)) ///
	(connected invest year if treatment_status == 5, lcolor(brown) msize(medlarge)  lpattern(dash) mcolor(brown) msymbol(Oh)), ///
	 ytitle(Fraction) xtitle(Year) xlabel(#3) ///
	legend(pos(11)  cols(2) label(1 "Control Industries, Bottom 95%") label(2 "Control Industries, Top 5%")  ///
	label(3 "2014 Targeted Industries, Bottom 95%") label(5 "2015 Targeted Industries, Bottom 95%") ///
	label(4 "2014 Targeted Industries, Top 5%") label(6 "2015 Targeted Industries, Top 5%") bmargin(zero))
	graph export $output/invest_trends1_p95_conditional.pdf, replace
restore

