
set more off


preserve
	eststo clear
	
	gen implicit_rate = total_income_tax / taxable_income_100ds
	replace implicit_rate = .1 if taxable_income_100ds == 0 & eligible == 1
	replace implicit_rate = .25 if taxable_income_100ds == 0 & eligible == 0
	replace implicit_rate = .15 if hnte == 1

	keep if year == 2013 & inlist(treatment,1,2)
	drop if fixed_assets1 == 0 
	
	gen cash_etr = total_income_tax_100 / total_profit_lrbds 
	
	gen etr_over_str = cash_etr / implicit_rate
	
	gen etr_minus_str = implicit_rate - cash_etr  
	
	gen logtotalassets = ln(total_assets_zcf)
	
	replace logstock = log(tax_loss_stock +(tax_loss_stock^2 +1)^.5)
	replace logrevenue = log(business_revenue +(business_revenue^2 +1)^.5)
	replace logemployees = log(employees +(employees^2 +1)^.5)
			
	gen margin = business_profit_100 /business_revenue
	gen capital_intensity = fixed_assets1 / business_revenue_100 

	gen margin2 = business_profit_100 / total_assets
	
	gen ratio_assets = fixed_assets1 / total_assets_z
	
	label var capital_intensity "Fixed Assets / Revenue"
	label var logrevenue "Log Revenue"
	label var margin "Business Profits / Revenue"
	label var lnfixed_assets1 "Log Fixed Assets"
	label var margin2 "Business Profits / Total Assets"
	label var ratio_assets "Fixed Assets / Total Assets"
	label var city "Indicator for Urban Area"
	label var special_zone "Firm in Industrial Park"
	
	gen log_fixed = ln(fixed_assets1)
	
	
	local controls = "logemployees logrevenue  hnte  tax_loss logstock soe " 
	
	winsor2 ratio_assets etr_minus cash_etr capital_intensity margin log_fixed total_assets_z, cut(5 95) replace
	gegen districtn = group(district)
	replace capital_intensity = ratio_assets
	
	eststo bureau3: reghdfe lnbureau capital_intensity etr_minus margin tax_loss   `controls', ///
	 cluster(ind3) absorb(ind3 prefecture)
	estadd local indfe = "Yes"
	estadd local prefect = "Yes"
	sum etr_minus if e(sample)
	estadd scalar mean = `r(mean)'
	sum capital_intensity if e(sample)
	estadd scalar Cmean = `r(mean)'
	sum margin if e(sample)
	estadd scalar Mmean = `r(mean)'
			
	eststo distance3: reghdfe logdistance capital_intensity etr_minus margin   `controls', ///
	cluster(ind3) absorb(ind3 prefecturen)
	estadd local indfe = "Yes"
	estadd local prefect = "Yes"
	sum etr_minus if e(sample)
	estadd scalar mean = `r(mean)'
	sum capital_intensity if e(sample)
	estadd scalar Cmean = `r(mean)'
	sum margin if e(sample)
	estadd scalar Mmean = `r(mean)'

	label var cash_etr "Cash ETR "		
	
	estout bureau3 distance3 using $output/correlation_with_taxadmin_reduced_small.tex, replace style(tex) type ///
	nolegend noomitted eqlabels(none) collabels(none) nobaselevels ///
	order(etr_minus_str capital_intensity margin ) ///
	label keep(capital_intensity etr_minus_str margin ) numbers ///
	mlabels("Log(Firms / Bureau Staff)" "Log(Distance to Bureau) ")  ///
	varlabels(etr_minus_str "Statutory Rate minus Cash ETR",end("" \addlinespace))   ///
	cells("b(star fmt(%9.3f) label(Coef))" "se(par fmt(%9.3f) label(Std. Error))") ///
	stats(N indfe prefect mean Cmean Mmean,  ///
	fmt(0 1 1 2) labels("N" "Three-Digit Industry FE" "Prefecture FE" "Mean STR - ETR" "Mean (Fixed Assets / Revenue)" "Mean (Business Profits / Revenue)" )) ///
	prehead("\begin{tabular}{lcc}" "\toprule" )  ///
	posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)			
	
restore

