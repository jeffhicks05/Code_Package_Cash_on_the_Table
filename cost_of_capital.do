preserve
	
	keep if year == 2013
	keep if treated2014 == 1 | treated2015 ==1 
	keep if business_revenue > 0 & fixed_assets1 > 0 & !mi(fixed_assets1)
	
	gen implicit_rate = total_income_tax / taxable_income_100ds
	replace implicit_rate = .1 if taxable_income_100ds == 0 & eligible == 1
	replace implicit_rate = .25 if taxable_income_100ds == 0 & eligible == 0
	replace implicit_rate = .15 if hnte == 1
	
	bys firm: gen temp1 = implicit if year == 2013
	bys firm: gegen tau = max(temp1)

	gen npv20 =  .566

	gen npv10 =  .75

	gen npv5 =  .877

	gen npv4 =  .906 

	gen npv3 =  .936
	
	gen Z_old =  s_transport_production1 *npv10 + s_furniture_tools1 * npv5 + ///
	s_buildings_structures1 * npv20 + s_transportation1 * npv4 + s_electronic_equipment1 * npv3

	gen A_old =  tau*(s_transport_production1 *npv10 + s_furniture_tools1 * npv5 + ///
	s_buildings_structures1 * npv20 + s_transportation1 * npv4 + s_electronic_equipment1 * npv3)
	
	gen tax_component_old = (1-A_old) / (1 - tau)
	
	drop npv*

	gen npv20 =  .708

	gen npv10 =  .85

	gen npv5 =  .936

	gen npv4 =  .936

	gen npv3 =  .967
	
	gen Z_new=  s_transport_production1 *npv10 + s_furniture_tools1 * npv5 + ///
	s_buildings_structures1 * npv20 + s_transportation1 * npv4 + s_electronic_equipment1 * npv3

	gen A_new =  tau*(s_transport_production1 *npv10 + s_furniture_tools1 * npv5 + ///
	s_buildings_structures1 * npv20 + s_transportation1 * npv4 + s_electronic_equipment1 * npv3)
	
	gen tax_component_new = (1-A_new) / (1 - tau)
	
	
	gen change_base = Z_new - Z_old
	gen change_tax = A_new - A_old
	gen change_user_cost  = tax_component_new - tax_component_old

	gcollapse (mean) change_tax change_base change_user_cost A* Z* tax_component*
	
restore

* Create micro-level file to use for regression.

preserve
	keep if treated2014 == 1 | treated2015 == 1 | indcode == 10
	
	gen preyear = 2013 if treated2014 == 1
	replace preyear = 2014 if treated2015 == 1
	
	gen tau = total_income_tax / taxable_income_100ds
	replace tau = .1 if taxable_income_100ds == 0 & eligible == 1
	replace tau = .25 if taxable_income_100ds == 0 & eligible == 0
	replace tau = .15 if hnte == 1
	drop if tau < .0999 /* half a percent */
	
	gen npv20 =  .566
	gen npv10 =  .75
	gen npv5 =  .877
	gen npv4 =  .906 
	gen npv3 =  .936
	
	gen Z_old =  s_transport_production1 *npv10 + s_furniture_tools1 * npv5 + ///
	s_buildings_structures1 * npv20 + s_transportation1 * npv4 + s_electronic_equipment1 * npv3

	gen A_old =  tau*(s_transport_production1 *npv10 + s_furniture_tools1 * npv5 + ///
	s_buildings_structures1 * npv20 + s_transportation1 * npv4 + s_electronic_equipment1 * npv3)
	
	gen tax_component = (1-A_old) / (1 - tau) if year <= preyear | (treated2014 == 0 & treated2015 == 0)
	
	drop npv*

	gen npv20 =  .708
	gen npv10 =  .85
	gen npv5 =  .936
	gen npv4 =  .936
	gen npv3 =  .967
	
	gen Z_new=  s_transport_production1 *npv10 + s_furniture_tools1 * npv5 + ///
	s_buildings_structures1 * npv20 + s_transportation1 * npv4 + s_electronic_equipment1 * npv3

	gen A_new =  tau*(s_transport_production1 *npv10 + s_furniture_tools1 * npv5 + ///
	s_buildings_structures1 * npv20 + s_transportation1 * npv4 + s_electronic_equipment1 * npv3)
	
	replace tax_component = (1-A_new) / (1 - tau) if year > preyear & (treated2014 == 1 | treated2015 ==1)
	
	drop if tax_comp > 1.2 /*one firm data issue */
	
	binscatter tax_compo year, by(treatment) discrete ///
	legend(pos(6) cols(1) label(1 "Non-Targeted Industries") label(2 "2014 Targeted Industries") label(3 "2015 Targeted Industries") ) ///
	 line(connect) xlabel(#10) ylabel(#10) xtitle(Year) ytitle(User Cost of Capital) scale(1.2)
	graph export $output/usercost.pdf, replace
	
	keep tax_component year firm
	
	save $output/tax_components.dta, replace
	
restore
