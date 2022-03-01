set more off

local base_year = $base_year
local treated_year = $treated_year
local control_group = "$control_group"

preserve

	keep if (treated`treated_year' ==1 | control == 1) & !mi(lnfixed_assets_net)
		
	xtset firm year

	gen profit_ratio = total_profit_100ds/business_revenue_100
	gen revgrowth = (business_revenue - l.business_revenue)/l.business_revenue
	
	keep if year == `base_year'
	
*************************
* Impose common support *
*************************

	foreach var in total_assets_z profit_ratio revgrowth age {
	
		bys treated`treated_year' year: gegen max = max(`var')
		gegen minmax = min(max)
		
		bys treated`treated_year' year: gegen min = min(`var')
		gegen maxmin = max(min)
		
		keep if inrange(`var', maxmin, minmax)
		drop min max minmax maxmin
	}
	
***************************	
* Create bins to match on *
***************************

	gegen capital_bins = cut(total_assets_zcf), group(10)
	gegen profit_bins = cut(profit_ratio), group(10)
	gegen rev_bins = cut(revgrowth), group(10)
	
	keep capital_bins profit_bins age firm year treated`treated_year' rev_bins

	reshape wide rev_bins capital_bins profit_bins age, j(year) i(firm)
		
	cem profit_bins`base_year'  (#0) capital_bins`base_year' (#0) rev_bins`base_year' (#0) ///
	age`base_year'  (0 1 2 3 5 10 15 20) , treatment(treated`treated_year') showbreaks
	
	keep if cem_matched == 1
	keep firm cem_weight
	save $output/matched_sample`treated_year'_`control_group'.dta, replace
restore
