set more off

preserve

	bys firm: gegen mean = mean(business_revenue_100 if inrange(year,2013,2013))

	xtset firm year
	
	replace tax_loss = (taxable_income2 - loss_carry + fixed_assets9 <=0)

	drop if fixed_assets1 == 0 
	gen logassets = ln(total_assets)
	
	gen preyear = 2013 if treated2014 == 1 
	replace preyear = 2014 if treated2015==1
	replace preyear = 2013 if treatment_status == 0 
	
	gen laginvestment = (lnfixed_assets1 - l.lnfixed_assets1 ) 
	
	local index = 1
	foreach var in transport_production furniture_tools buildings_structures transportation electronic_equipment {
	
		replace `var'9 = 0 if mi(`var'9)
		replace `var'9 = `var'9 +`var'10 if !mi(`var'10) & `var'9 != `var'10
		
		replace `var'1 = 0 if mi(`var'1)
		
		xtset firm year
		gen cl_`index' = (`var'9 - l.`var'9 > 0 ) if !mi(l.`var'9)
		replace cl_`index' = (`var'9 > 0) if mi(l.`var'9)
		gen inv_`index' = `var'1  - l.`var'1	
		gen change_`index' = (`var'1  - l.`var'1 >0 ) if !mi(l.`var'1)
		replace change_`index' = (`var'1 >0) if mi(l.`var'9)
		gen logchange`index' = ln(`var'1 - l.`var'1) if !mi(l.`var'1)
		replace logchange`index' = ln(`var'1) if mi(`var'1)		
		
		gen one_time_`index' = `var'9 > 0 & l.`var'9 == 0 & f.`var'9 ==0
		
		local index = `index' + 1
		
	}

	rename bureau bureau2
	gegen bureau= group(bureau2)
	drop if year < 2013
		
	
	replace logstock = log(tax_loss_stock +(tax_loss_stock^2 +1)^.5)
	replace logrevenue = log(business_revenue +(business_revenue^2 +1)^.5)
	replace logemployees = log(employees +(employees^2 +1)^.5)
	replace logcash = log(cash_z +(cash_z^2 +1)^.5)
	
	
	local selection = "i.year i.asset_class l.logassets  i.hnte  tax_loss l.logstock l.laginvestment l.interest_dummy l.logcash  "
	local base_claim = "i.year i.asset_class l.logassets  i.hnte  tax_loss l.logstock logchange  "
	local cluster = "ind3"
	
	gen implicit_rate = total_income_tax / taxable_income_100ds
	replace implicit_rate = .1 if taxable_income_100ds == 0 & eligible == 1
	replace implicit_rate = .25 if taxable_income_100ds == 0 & eligible == 0
	replace implicit_rate = .15 if hnte == 1
	
	gen cash_etr = total_income_tax_100 / total_profit_lrbds 
	
	gen etr_over_str = cash_etr / implicit_rate
	
	bys firm: gegen etr_minus_str = max(implicit_rate - cash_etr  if year == 2013)
	bys firm: gegen capital_intensity = max(fixed_assets1 / total_assets_z if year == 2013)
	bys firm: gegen margin = max(business_profit_100 /business_revenue if year == 2013)


	*********************************
	* baseline firm characteristics *
	*********************************	
	
	keep etr_minus_str capital_intensity margin city special_zone bureau one_time* business_revenue_100 inv_* taxable_income_100 city employees soe year years_since_entry logstock tax_loss_stock treatment_status treated2014 treated2015 logdistance_placebo treated2014 logdistance lnbureau logchange* ind2 prefecturen firm logemployees logrevenue ///
	logassets hnte tax_loss org interest_dummy lnacc_ratio lnaccountant_firm_ratio lnaccountant_worker_ratio  ///
	laginvestment logcash  `cluster' year preyear cl_* change_*  

	winsor2 margin capital_intensity etr_minus_str logemployees logassets logrevenue logstock laginvestment logcash ///
	 lnbureau logdistance* lnaccountant_firm_ratio lnaccountant_worker_ratio, replace cut(1 99) by(treated2014 year)

	reshape long one_time_ cl_ change_ logchange inv_ ,  i(firm year) j(asset_class)

	rename change_ change
	rename cl_ claimed2

	* Basic Descriptive Patterns *

	local condition = "if year > preyear"
	local excluded_variables = "l.laginvestment l.interest_dummy l.logcash"


	binscatter claimed2 year if year > 2013 & change == 1, mcolor(blue brown black) lcolor(blue brown black) ///
	msymbol(Oh D Dh) by(treatment_status) ytitle(Fraction) xtitle(Year) scale(1.2) ///
	discrete line(connect) xlabel(#3) legend(pos(11) ring(0) cols(1) label(1 "Control Industries") label(2 "2014 Targeted Industries") label(3 "2015 Targeted Industries"))

	graph export $output/claim_trends2_new.pdf, replace
	

	gen claimed3 = (l.claimed2 == 0 & claimed2 ==1 ) if !mi(l.claimed2)
	replace claimed3 = l.claimed2 == 0 & l2.claimed2 == 0 & claimed2 == 1 if !mi(l.claimed2) & !mi(l2.claimed2)
	
	binscatter claimed3 year if year > 2013 & claimed2 == 1 , ///
	 line(connect) discrete legend(pos(8) ring(0) cols(1) label(1 "Production") ///
	 label(2 "Tools, Furniture") label(3 "Buildings") label(4 "Transportation") label(5 "Electronics")) ///
	 by(asset_class) ytitle("% New Claims" ) xlabel(2014(1)2016) scale(1.2) xtitle(Year)
	graph export $output/claim_trends4_newclaims.pdf, replace


	keep if (treated2014 == 1 | treated2015 == 1)
	drop if change ==0 & claimed2==1
	

************************
* Pair-Wise Correlates *
************************
	local control = "i.ind2 i.year"

	gegen panelid = group(firm asset_class)
	xtset panelid year

	gen temp = 1
	
	gen llogassets = l.logassets
	gen llogrevenue = l.logrevenue
	
	gen ltax_loss_stock = l.tax_loss_stock
	gen llogstock = l.logstock
	label variable llogstock "Ln(Tax Loss Stock(t-1))"	
	
	reg claimed2 lnbureauratio i.asset_class i.year i.ind2 if change ==1 & year > preyear, robust
	matrix temp = e(b)
	local slope: di %6.4f temp[1,1]
	matrix temp = e(V)
	local se: di %6.4f sqrt(temp[1,1])
	
	binscatter claimed2 lnbureau if change ==1 & year > preyear, by(temp) nquantiles(30) absorb(asset_class) scale(1.2)  msymbol(O)  ///
	ytitle(Claimed Accelerated Depreciation) xtitle("Ln(# Firms / # Tax Administrators)") control(`control') ///
	legend(pos(11) ring(0) size(medium) label(1 "Slope: `slope' Standard Error: `se'"))	xlabel(#10)
		
	graph export $output/claimed_extra_bureau_employees_conditional.pdf, replace
	
	
	reg claimed2 llogassets i.asset_class i.year i.ind2 if change ==1 & year > preyear , robust
	matrix temp = e(b)
	local slope: di %6.4f temp[1,1]
	matrix temp = e(V)
	local se: di %6.4f sqrt(temp[1,1])
	
	binscatter claimed2 llogassets if change ==1 & year > preyear , by(temp) nquantiles(30) absorb(asset_class) scale(1.2) msymbol(O)  ///
	ytitle(Claimed Accelerated Depreciation) xtitle("Ln(Total Assets(t-1))")  control(`control') ///
	legend(pos(11) ring(0) size(medium) label(1 "Slope: `slope' Standard Error: `se'"))	xlabel(#10)


	graph export $output/claimed_extra_logassets_conditional.pdf, replace
	
	reg claimed2 logchange i.asset_class i.year i.ind2 if change ==1 & year > preyear, robust
	matrix temp = e(b)
	local slope: di %6.4f temp[1,1]
	matrix temp = e(V)
	local se: di %6.4f sqrt(temp[1,1])
	
	binscatter claimed2 logchange if change ==1 & year > preyear, by(temp) nquantiles(30) absorb(asset_class) scale(1.2) ///
	ytitle(Claimed Accelerated Depreciation) xtitle("Ln(K(t,k) - K(t-1,k))") msymbol(O) control(`control') ///
	legend(pos(11) ring(0) size(medium) label(1 "Slope: `slope' Standard Error: `se'"))	xlabel(#10)

	graph export $output/claimed_extra_logchange_conditional.pdf, replace
	
	gegen bureaun = group(bureau)
	
	reg claimed2 logdistance i.asset_class i.year i.ind2 if change ==1 & year > preyear, robust
	matrix temp = e(b)
	local slope: di %6.4f temp[1,1]
	matrix temp = e(V)
	local se: di %6.4f sqrt(temp[1,1])
	
	binscatter claimed2 logdistance if change ==1 & year > preyear, by(temp) nquantiles(30) absorb(asset_class) scale(1.2)  ///
	ytitle(Claimed Accelerated Depreciation) xtitle("Ln(Distance to Tax Bureau)") msymbol(O)  control(`control') ///
	legend(pos(11) ring(0) size(medium) label(1 "Slope: `slope' Standard Error: `se'")) xlabel(#10)

	graph export $output/claimed_extra_distance_to_bureau_conditional.pdf, replace

	reg claimed2 llogstock i.asset_class i.year i.ind2 llogrevenue if ltax_loss_stock > 0 & change==1 & year > preyear, robust
	matrix temp = e(b)
	local slope: di %6.4f temp[1,1]
	matrix temp = e(V)
	local se: di %6.4f sqrt(temp[1,1])
	
	binscatter claimed2 llogstock if ltax_loss_stock > 0 & change==1 & year > preyear, by(temp) scale(1.2) nquantiles(30) absorb(asset_class) msymbol(O)  ///
	ytitle(Claimed Accelerated Depreciation) xtitle("Ln(Tax Loss Stock(t-1))") control(`control' ) ///
	 legend(pos(11) ring(0) size(medium) label(1 "Slope: `slope' Standard Error: `se'")) xlabel(#10)
	 
	graph export $output/claimed_extra_tax_loss_conditional.pdf, replace
	
	
	reg claimed2 `control' i.asset_class
	predict resid, residual
	gegen mean = mean(claimed2)
	replace resid = resid + mean
	

	cibar resid if change == 1 & year > preyear, over1(hnte) barcolor(brown sky) ciopts(lcolor(black) lwidth(thick)) ///
	graphopts(scale(1.2) ytitle(Claimed Accelerated Depreciation) legend(pos(6) ring(1) cols(2) size(medium)) ylabel(0(.01).1))
	graph export $output/hnte_takeup.pdf, replace
			
*********************
*Take-up Regression *
*********************


	heckprob claimed2 `base_claim' i.ind2  i.year i.asset_class `condition'  , ///
	sel(change = `selection' i.ind2 i.year i.asset_class)  vce(cluster `cluster')
	test `excluded_variables'
	local chi = `r(p)'
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(`base_claim') predict(pcond)
	eststo reg1
	estadd scalar chi = `chi' 
	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'
	estadd local prefecture "No"
	
	heckprob claimed2 `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition'  , ///
	sel(change = `selection' i.ind2 i.prefecturen i.year i.asset_class)  vce(cluster `cluster')
	test `excluded_variables'
	local chi = `r(p)'
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(`base_claim') predict(pcond)
	
	eststo reg2
	estadd scalar chi = `chi' 
	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'
	estadd local prefecture "Yes"
	
	
	probit change `selection' i.ind2 i.year i.asset_class i.prefecturen  `condition' ,  vce(cluster `cluster')
	estadd scalar fullN = `e(N)'
	estpost margins if e(sample), dydx(`selection' ) 
	eststo reg3
	tab change claimed2
	
	estadd scalar chi = `chi' 
		
	estadd local industry "Yes"
	estadd local prefecture "Yes"
	su change if e(sample) 
	local takeup = `r(mean)'*100
	estadd scalar takeup = `takeup'
	

	probit claimed2 `base_claim' i.ind2  i.year i.asset_class   if change == 1 & year > preyear & e(sample),  vce(cluster `cluster')
	estadd scalar fullN = `e(N)'	
	estpost margins if e(sample), dydx(`base_claim' ) 
	eststo reg4 
		
	estadd local industry "Yes"
	estadd local prefecture "No"
	su claimed2 if e(sample) 
	local takeup = `r(mean)'*100
	estadd scalar takeup = `takeup'

	probit claimed2 `base_claim' i.ind2 i.year i.asset_class i.prefecturen  if change == 1 & year > preyear & e(sample),  vce(cluster `cluster')
	estadd scalar fullN = `e(N)'	
	estpost margins if e(sample), dydx(`base_claim' ) 
	eststo reg5
		
	estadd local industry "Yes"
	estadd local prefecture "Yes"
	su claimed2 if e(sample) 
	local takeup = `r(mean)'*100
	estadd scalar takeup = `takeup'


	estout reg4 reg5 reg2 using $output/firm_characteristics_takeup_main.tex, replace ///
		keep(*hnte logchange  *tax_loss L.logstock L.logassets  )   /// 
		order(*tax_loss L.logstock  L.logassets  *hnte logchange ) ///
		style(tex) nolegend collabels(none) noomitted  nobaselevels nonumbers mlabels(none) ///
		varlabels(logchange "\$ Ln(K_{t,k} - K_{t-1,k}) \$" ///
		 L.logrevenue "Ln(Revenue \$_{t-1} \$)" L.logassets "Ln(Total Assets \$_{t-1}\$ )"  ///
		L.logstock "Ln(Tax Loss Stock \$_{t-1}\$) " ///
		, end("" \addlinespace))  label type transform(@*100 (@/@)*100) ///
		cells("b(star fmt(%9.2f) label(Coef))" "se(par fmt(%9.2f) label( Std. Err.))")  ///
		stats(industry prefecture fullN takeup, fmt(0 0 0 2 3) ///
		 labels("Two-Digit Industry FE" "Prefecture FE" "N"  "Mean of Outcome Var." "Excluded Variables Joint P-value") ) ///
prehead("\begin{tabular}{lccc} \toprule " "&\multicolumn{3}{c}{Pr(Claim $\mid$ Invest)}  \\" " \cmidrule(lr){2-4}" ///
 "&         (1)  &         (2)  &         (3)    \\ " "\cmidrule(lr){2-3} \cmidrule(lr){4-4} &  \multicolumn{2}{c}{Probit Model} & Selection Model \\  ") ///
		posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)	
	
	estout reg3 reg1 reg2  using $output/firm_characteristics_takeup_appendix.tex, replace ///
		keep(*hnte logchange  *tax_loss L.logstock L.logassets  L.interest_dummy L.laginvestment L.logcash)   /// 
		order(*tax_loss L.logstock  L.logassets  *hnte logchange  L.interest_dummy L.laginvestment  L.logcash) ///
		style(tex) nolegend collabels(none) noomitted  nobaselevels nonumbers mlabels(none) ///
		varlabels( logchange "\$ Ln(K_{t,k} - K_{t-1,k}) \$" ///
		L.laginvestment "\$ Ln(K_{t-1}) - Ln(K_{t-2})\$" L.logrevenue "Ln(Revenue\$_{t-1}\$)" L.logassets "Ln(Total Assets \$_{t-1}\$)" ///
		L.logstock "Ln(Tax Loss Stock \$_{t-1}\$ )" L.logcash "Ln(Cash Holdings\$_{t-1}\$)" L.interest_dummy "Interest Deduction \$_{t-1} > 0\$", end("" \addlinespace))  label type transform(@*100 (@/@)*100) ///
		cells("b(star fmt(%9.2f) label(Coef))" "se(par fmt(%9.2f) label( Std. Err.))")  ///
		stats(industry prefecture fullN takeup chi, fmt(0 0 0 2 3) ///
		 labels("Two-Digit Industry FE" "Prefecture FE" "N"  "Mean of Outcome Var." "Excluded Variables Joint P-value") ) ///
prehead("\begin{tabular}{lccc} \toprule " "&\multicolumn{3}{c}{Selection Model} \\" ///
"&         (1)  &         (2)  &         (3)   \\ " "\cmidrule(lr){2-2}\cmidrule(lr){3-4} &  Pr(Invest)  & \multicolumn{2}{c}{Pr(Claim $\mid$ Invest)}  \\ ") ///
		posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)	


	***************************
	* Add in Bureau Resources *
	***************************
	


	xtset panelid year
	
	probit claimed2 lnbureauratio `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition' & change ==1 , vce(cluster `cluster')
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(lnbureauratio) 
	
	eststo reg2	

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"
	estadd local probit "Yes"
	estadd local tax_bureau "No"	
	
	* distance only*

	probit claimed2 logdistance `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition' & change == 1, vce(cluster `cluster')
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(logdistance) 
	
	eststo reg4	
	
	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"	
	estadd local probit "Yes"
	estadd local tax_bureau "No"	
	
	* combined *
	probit claimed2 logdistance lnbureauratio `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition' & change == 1,  vce(cluster `cluster')
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(logdistance lnbureauratio) 
	
	eststo reg5	
	
	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"
	estadd local probit "Yes"
	estadd local tax_bureau "No"	
	

	*placebo*
	probit claimed2 logdistance_placebo `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition' & change == 1 ,  vce(cluster `cluster')
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(logdistance_placebo)  
	
	eststo reg6
	
	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"	
	estadd local probit "Yes"
	estadd local tax_bureau "No"	
		
	*interactions*

	gen inter_ba= lnbureaura*logemployees
	gen inter_bh = lnbureaura*hnte
		
	gen inter_da = logdistance *logemployees
	gen inter_dh = logdistance * hnte 	
	
	gen inter_taxloss_d = tax_loss*logdistance
	gen inter_taxloss_b = tax_loss*lnbureaur
	
	gen inter_bsoe = lnbureau*soe
	gen inter_dsoe = logdistance*soe
	
	probit claimed2 logdistance lnbureauratio inter_dh inter_bh `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition' & change == 1,vce(cluster `cluster')	
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(lnbureauratio logdistance  inter_dh inter_bh)  
	
	eststo reg7	

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"
	estadd local probit "Yes"
	estadd local tax_bureau "No"	
	
	probit claimed2 logdistance lnbureauratio inter_taxloss_d inter_taxloss_b `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition' & change == 1, vce(cluster `cluster')
	estadd scalar fullN = `e(N)'
	
	estpost margins if e(sample), dydx(lnbureauratio logdistance  inter_taxloss_d inter_taxloss_b)  

	eststo reg8	

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"
	estadd local probit "Yes"
	estadd local tax_bureau "No"	
	
	
	*Add Bureau FE for Disntance *
	probit claimed2 logdistance `base_claim' i.ind2 i.bureaun ///
	i.year i.asset_class `condition' & change == 1 ,  vce(cluster `cluster')
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(logdistance)  
	
	eststo reg11
	
	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"	
	estadd local probit "Yes"
	estadd local tax_bureau "Yes"	
	
	
	*Add in Industrial Zone and Compliance Controls*
	probit claimed2 lnbureauratio logdistance `base_claim' etr_minus_str capital_intensity margin special_zone city i.ind2 i.prefecturen i.year i.asset_class `condition' & change == 1 ,  vce(cluster `cluster')
	estadd scalar fullN = `e(N)'

	estpost margins if e(sample), dydx(lnbureauratio logdistance special_zone city etr_minus_str capital_intensity margin)  
	
	eststo reg12
	
	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"	
	estadd local probit "Yes"
	estadd local tax_bureau "No"	

	* Selection	
	heckprob claimed2 logdistance lnbureauratio `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition', ///
	sel(change = logdistance lnbureauratio  `selection' i.ind2 i.prefecturen i.year i.asset_class) vce(cluster `cluster')
	test `excluded_variables'
	local chi = `r(p)'
	estadd scalar fullN = `e(N)'
	
	estpost margins if e(sample), dydx(lnbureauratio logdistance )  predict(pcond)

	eststo reg9	

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"
	estadd local selection "Yes"
	
	
	* Requested by Referee *
	gen interdb = logdistance*lnbureauratio
	
	probit claimed2 interdb logdistance lnbureauratio `base_claim' i.ind2 i.prefecturen i.year i.asset_class `condition' & change == 1,  vce(cluster `cluster')
	estadd scalar fullN = `e(N)'
	
	estpost margins if e(sample), dydx(interdb lnbureauratio logdistance)  

	eststo reg10	

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"
	


	estout reg2 reg4 reg5 reg6 reg11 reg12 reg7  using $output/bureau_takeup_panel3.tex, replace ///
		keep(lnbureauratio  logdistance logdistance_placebo inter_bh inter_dh special_zone city etr_minus_str capital_intensity margin) /// 
		order(lnbureauratio logdistance logdistance_placebo special_zone city  etr_minus_str capital_intensity margin inter_bh inter_dh ) ///
		style(tex) nolegend collabels(none) noomitted  nobaselevels numbers mlabels(none) mgroups("Claim \$\mid\$ Invest " ,  ///
		pattern(1 0 0 0 0 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(})  span erepeat(\cmidrule(lr){@span}) ) transform(@*100 (@/@)*100)  ///
		varlabels( _cons "Constant" lnbureauratio "Ln(\# Firms / \# Tax Administrators)" ///
		inter_bh "Ln(\# Firms / \# Tax Admin.) \$\times\$ HNTE" ///
		inter_dh "Ln(Distance to Tax Bureau) \$\times\$ HNTE" ///
		special_zone "Firm Headquarters in Industrial Park" ///
		city "Urban Bureau" etr_minus_str "STR minus Cash ETR" ///
		capital_intensity "Fixed Assets / Total Assets" ///
		margin  "Total Profit / Business Revenue" , end("" \addlinespace))  label type  ///
		cells("b(star fmt(%9.2f) label(Coef))" "se(par fmt(%9.2f) label( Std. Err.))")  ///
		stats(firm_char industry prefecture tax_bureau fullN takeup, fmt(0 0 0 0 0 2) ///
		 labels("Firm Characteristics" "Two-Digit Industry FE" "Prefecture FE" "Tax Bureau FE" "N" "Claim Rate" "Probit Model") ) ///
		 prehead("\begin{tabular}{lccccccc}" "\toprule") ///
		posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)

	estout reg10 using $output/bureau_takeup_panel_with_requested_interaction.tex, replace ///
		keep(lnbureauratio  logdistance interdb ) /// 
		order(lnbureauratio logdistance interdb ) ///
		style(tex) nolegend collabels(none) noomitted  nobaselevels numbers mlabels(none) mgroups("Claim \$\mid\$ Invest" ,  ///
		pattern(1 0 0 0 0 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(})  span erepeat(\cmidrule(lr){@span}) ) transform(@*100 (@/@)*100)  ///
		varlabels( _cons "Constant" lnbureauratio "Ln(\# Firms / \# Tax Administrators)" ///
		interdb "Ln(Distance) $\times$ Ln(\# Firms / \# Tax Administrators) " , end("" \addlinespace))  label type  ///
		cells("b(star fmt(%9.2f) label(Coef))" "se(par fmt(%9.2f) label( Std. Err.))")  ///
		stats(firm_char industry prefecture fullN takeup , fmt(0 0 0 0 2 3) ///
		 labels("Firm Characteristics" "Two-Digit Industry FE" "Prefecture FE" "N" "Claim Rate" ) ) ///
		 prehead("\begin{tabular}{lc}" "\toprule") ///
		posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)	
	

	************************
	* Accounting Variables *
	************************
	
		
	probit claimed2 lnaccountant_worker_ratio logdistance lnbureauratio `base_claim' ///
	 i.prefecturen i.ind2 i.year i.asset_class `condition' & change == 1, vce(cluster `cluster')		
	estadd scalar fullN = `e(N)'

	
	estpost margins if e(sample), dydx(lnaccountant_worker_ratio logdistance lnbureauratio) 
	
	eststo reg1

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"
	
	probit claimed2 lnaccountant_firm_ratio logdistance lnbureauratio `base_claim' ///
	i.prefecturen i.ind2 i.year i.asset_class `condition' & change ==1, vce(cluster `cluster')
	estadd scalar fullN = `e(N)'
	
	estpost margins if e(sample), dydx(lnaccountant_firm_ratio logdistance lnbureauratio) 
	
	eststo reg2

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"	
	
	
	
	probit claimed2 lnacc_ratio logdistance lnbureauratio `base_claim' ///
	i.prefecturen i.ind2 i.year i.asset_class `condition' & change == 1 , vce(cluster `cluster')		
	estadd scalar fullN = `e(N)'

	
	estpost margins if e(sample), dydx(lnacc_ratio logdistance lnbureauratio) 
	
	eststo reg3

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"	
	
	
	probit claimed2 lnacc_ratio lnaccountant_firm_ratio lnaccountant_worker_ratio  logdistance lnbureauratio ///
	`base_claim' i.prefecturen i.ind2 i.year i.asset_class `condition' & change == 1 , ///
	 vce(cluster `cluster')
	
	estadd scalar fullN = `e(N)'
	
	estpost margins if e(sample), dydx(lnacc_ratio lnaccountant_firm_ratio lnaccountant_worker_ratio logdistance lnbureauratio)  
	
	eststo reg4

	su claimed2 if e(sample) & change == 1
	local takeup = `r(mean)'*100	
	estadd local industry "Yes"
	estadd scalar takeup = `takeup'	
	estadd local firm_char "Yes"
	estadd local prefecture "Yes"	

	estout reg1 reg2 reg3 reg4 using $output/accountants_takeup.tex, replace ///
		keep(lnacc_ratio lnaccountant_firm_ratio lnaccountant_worker_ratio  logdistance lnbureauratio) /// 
		order(lnaccountant_worker_ratio lnaccountant_firm_ratio lnacc_ratio lnbureauratio  logdistance ) ///
		style(tex) nolegend collabels(none) noomitted  nobaselevels numbers mlabels(none) mgroups("Pr(Claim \$\mid\$ Invest)",  ///
		pattern(1 0 0) prefix(\multicolumn{@span}{c}{) suffix(})  span erepeat(\cmidrule(lr){@span}) ) ///
		varlabels( _cons "Constant" lnaccountant_worker_ratio "Log(\# Accountants / \# Workers)" ///
		  lnaccountant_firm_ratio "Ln(\# Accountants / \# Firms)" ///
		  lnacc_ratio "Ln(\# Accounting Firms / \# Firms)" ///
		    lnbureauratio "Ln(\# Firms / \# Tax Administrators)" ///
		, end("" \addlinespace))  label type  transform(@*100 (@/@)*100) ///
		cells("b(star fmt(%9.2f) label(Coef))" "se(par fmt(%9.2f) label( Std. Err.))")  ///
		stats(firm_char industry prefecture fullN takeup, fmt(0 0 0 0 2 3) ///
		 labels("Firm Characteristics" "Two-Digit Industry FE" "Prefecture FE" "N" "Claim Rate") ) prehead("\begin{tabular}{lcccc}" "\toprule") ///
		posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}")	starlevels(* 0.10 ** 0.05 *** .01)		


restore
