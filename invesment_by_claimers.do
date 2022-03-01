sort firm year
set more off
local cluster_var = "ind3"
pause on
set more off

foreach year in 2014 2015 {
	preserve
		
		drop if business_revenue_100 <= 1
		gen preyear = 2014 if treated2014 == 1 | treatment == 0
		replace preyear = 2015 if treated2015 == 1


		merge m:1 firm using $output/matched_sample`year'_manufacturing.dta,  keep(3)
		
		gen treated= treated`year' 
		drop treated2014 treated2015
		
		winsor2 lnfixed_assets_net dlnfixed_assets_net , by(year treated) cut(1 99) replace
						
		********************
		* DFL Re-Weighting *
		********************
		
		gl group = "treated"
		gl base_year = 2013
		gl base_group = 1
		gl percentiles = 10
		gl weight = "cem_weight"
		gl variables = "business_revenue_100"
		
		winsor2 $variables, replace cut(1 99) by(treated year)

		do $code_other/dfl.do
		
		rename dfl_weight weight
		if "`match_type'" == "nomatch"	replace weight = 1
		
		gegen claim_amount = rowmax(fixed_assets9 fixed_assets10)
		xtset firm year
		
		gen claimed = claim_amount > l.claim_amount						
		
		bys firm: gegen max = max(claimed if year >= preyear)
		replace claimed2 = max
		
		
		gen post = year > `year' -1
		gen inter = post * claimed2
		
		gen invest = fixed_assets_net > l.fixed_assets_net
		bys firm: gegen invest_post = max(invest if year >= preyear)
		
		***********************
		* Regression Approach *
		***********************
		gen time = year - 2010
		reghdfe dlnfixed_assets_net c.claimed2##ib2013.year if treated == 1 [aw=weight],  absorb(firm) cluster(ind3)
		parmest, saving($output/claimers_dlnfixed_assets_net`year'.dta, replace)

		
		reghdfe lnfixed_assets_net c.claimed2##ib2013.year  if treated == 1 [aw=weight],  absorb(firm) cluster(ind3)
		parmest, saving($output/claimers_lnfixed_assets_net`year'.dta, replace)
		
		reghdfe dlnfixed_assets_net c.claimed2##ib2013.year  if treated == 1 & invest_post [aw=weight],  absorb(firm) cluster(ind3)
		parmest, saving($output/claimersB_dlnfixed_assets_net`year'.dta, replace)

		
		reghdfe lnfixed_assets_net c.claimed2##ib2013.year if treated == 1 & invest_post [aw=weight],  absorb(firm) cluster(ind3)
		parmest, saving($output/claimersB_lnfixed_assets_net`year'.dta, replace)
		
		
	restore
}


set more off
foreach outcome in dlnfixed_assets_net lnfixed_assets_net   {

foreach year in 2014 2015 {

		preserve
			
			if "`outcome'" == "dlnfixed_assets_net" local name = "DLnK"
			if "`outcome'" == "lnfixed_assets_net" local name = "LnK"
			
			use $output/claimers_`outcome'`year'.dta, clear
			gen spec = 1
			append using $output/claimersB_`outcome'`year'.dta
			replace spec = 2 if mi(spec)
			
			split parm, parse(#) 
			keep if !mi(parm2)
			gen year = real(substr(parm1,1,4))
			
			replace year = year + .1 if spec == 2
			
			twoway (scatter estimate year if spec ==1, msize(large)) (rspike min95 max95 year if spec ==1, lcolor(navy)) ///
			(scatter estimate year if spec == 2,  msize(large)) (rspike min95 max95 year if spec == 2, lcolor(red)), ylabel(#10) ///
			yline(0) xtitle(Year) ///
			 legend(pos(6) cols(2) order(1 3) label(1 "Treated Industries") label(3 "Treated Industries +" "Asset Growth > 0 Post Reform")) 
			graph export $output/claimers_`outcome'_`year'.pdf, replace
			
		restore
	
}
}

