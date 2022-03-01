foreach year in 2014 2015 {
set more off
	preserve
		keep if !mi(lnfixed_assets1)
				
		if `year' == 2014 drop if treated2015 == 1 & treated2014 == 0
		if `year' == 2015 drop if treated2014 == 1 & treated2015 == 0
		
		merge m:1 firm using $output/matched_sample`year'_manufacturing.dta, gen(match) keep(1 3)
		
		* drop non-manufacturing firms in control group
		drop if match ==1 & indcode != 10 & treatment == 0 
		
		gen treated = 1 if treated`year' == 1
		replace treated = 0 if treated`year' ==0
		label define treated 1 "`year' Treated Match Sample" 2 "Multi-Industry Matched Control"
				
		xtset firm year

		gen profit_ratio = total_profit_100ds/business_revenue_100
		gen rev_growth = (business_revenue - l.business_revenue)/l.business_revenue
		gen manufacturing = indcode == 10
		
		if "`year'" == "2014" keep if inlist(year, 2013)
		if "`year'" == "2015" keep if inlist(year, 2013)
		*gen cash_etr= total_income_tax_100 / total_profit_lrbds 
		*winsor2 cash_etr, replace cut(5 95)
							
		local vars = "total_assets_z profit_ratio rev_growth age dlnfixed_assets_net fixasset_und fixed_assets1 business_revenue taxable_income_100 tax_loss_stock tax_loss avg_useful_life soe sme distance bureau_employee_ratio"
		
		matrix storage = J(16,10,1)
		
		matrix rownames storage = Total_Assets Profit_Margin Revenue_Growth Age Asset_Growth_Net_of_Depreication Fixed_Assets_Net_of_Depreciation Fixed_Assets_Historical_Cost Business_Revenue Taxable_Income  ///
		Tax_Loss_Stock Percent_In_Tax_Losses  Average_Useful_Life  State_or_Collectively_Owned Small_or_Micro_Enterprise_(SME)  ///
		 Distance_to_Bureau_(km) Firms,Bureau_Employees 
		
		matrix colnames storage = Mean N Mean N PD Mean N Mean N PD
		local index = 1
	
		replace total_assets_z = total_assets_z / 10000
		replace fixasset_undep = fixasset_undep  /10000
		replace fixed_assets1 = fixed_assets1  /10000
		replace business_revenue = business_revenue / 10000
		replace taxable_income_100 = taxable_income_100 / 10000
		replace tax_loss_stock = tax_loss_stock / 10000
	
				
		foreach var of local vars {
			
			
			if inlist("`var'", "total_assets_z", "fixed_assets_total", "business_revenue", "taxable_income", "tax_loss_stock", "bureau_employee_ratio") {
				local format = "%7.0f"
			}
			else local format = "%07.2f"
			winsor2 `var', cut(1 99) replace 
			***************
			* Not Matched *
			***************
			
			su `var' if treated == 1 
			local mean: di `format' `r(mean)'
			*local sd: di %7.2f `r(sd)'
			matrix storage[`index',1] = `mean'
			matrix storage[`index',2] = `r(N)'
			
			su `var' if treated==0 
			local mean: di `format' `r(mean)'
			*local sd: di %7.2f `r(sd)'
			matrix storage[`index',3] = `mean'
			matrix storage[`index',4] = `r(N)'
			
			reg `var' treated 
			matrix temp = r(table)
			local temp = temp[4,1]
			local p: di `format' `temp'
			matrix storage[`index', 5] = `p'
		
			local index = `index' + 1
			
		}
		
		drop if match!=3
		local index = 1
		
		foreach var of local vars {
			
			
			if inlist("`var'", "total_assets_z", "fixed_assets_total", "business_revenue", "taxable_income", "tax_loss_stock", "bureau_employee_ratio") {
				local format = "%7.0f"
			}
			else local format = "%07.2f"
			winsor2 `var', cut(1 99) replace 
		
			***********
			* Matched *
			***********
			
			su `var' if treated == 1 & match == 3 [aw=cem_weight]
			local mean: di `format' `r(mean)'
			*local sd: di %7.2f `r(sd)'
			matrix storage[`index',6] = `mean'
			matrix storage[`index',7] = `r(N)'
			
			su `var' if treated==0 & match == 3 [aw=cem_weight]
			local mean: di `format' `r(mean)'
			*local sd: di %7.2f `r(sd)'
			matrix storage[`index',8] = `mean'
			matrix storage[`index',9] = `r(N)'
			
			reg `var' treated if match == 3 [aw=cem_weight]
			matrix temp = r(table)
			local temp = temp[4,1]
			local p: di `format' `temp'
			matrix storage[`index', 10] = `p'
			
			
			
			local index = `index' + 1
			
		}	
		
		if `year' == 2014 {
		estout matrix(storage) using $output/descriptives_matching`year'.tex, replace style(tex) nolegend ///
		prehead( "Panel A: 2014 Change & \multicolumn{5}{c}{Not Matched} & \multicolumn{5}{c}{Matched} \\ \midrule" ///
		"& \multicolumn{2}{c}{Targeted} & \multicolumn{2}{c}{Control} & & \multicolumn{2}{c}{Targeted} & \multicolumn{2}{c}{Control} & \\ \midrule") ///
		posthead(\midrule) prefoot(\midrule) postfoot() mlabel(none) substitute(_ " " , "/" PD "\$p\$") type
		}
		if `year' == 2015 {
		estout matrix(storage) using $output/descriptives_matching`year'.tex, replace style(tex) nolegend ///
		prehead( "Panel B: 2015 Change & \multicolumn{5}{c}{Not Matched} & \multicolumn{5}{c}{Matched} \\ \midrule" ///
		"& \multicolumn{2}{c}{Targeted} & \multicolumn{2}{c}{Control} & & \multicolumn{2}{c}{Targeted} & \multicolumn{2}{c}{Control} & \\ \midrule") ///
		posthead(\midrule) prefoot(\midrule) postfoot() mlabel(none) substitute(_ " " , "/" PD "\$p\$")	type	
		}
		
	restore
}
