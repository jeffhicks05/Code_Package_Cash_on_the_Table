set more off
clear all
set scheme plotplainblind, permanently
pause on
set matsize 10000
set sortseed  14325
***************
* Directories *
***************

global wei_input = "/home/weiproject/data"
global jeff_input = "/home/jeff/ChinaTax/Data"
global output = "/home/jeff/ChinaTax/Output/investment"
gl code = "/home/jeff/ChinaTax/All_Code/Labels/"
gl code_other = "/home/jeff/ChinaTax/All_Code/Investment/second_round"

*************************
* Load Data and Clean * *
*************************

use ind4_code ds* district neighborhood otype org hnte bureau id_local firm age employees taxpayer_status ///
indcode ind2 id_local entry_date prefecture year *_100ds *_zcfds  interest_tax_105ds rksk* ///
net_profit_lrbds total_profit_lrbds deferred_tax_liabilities_zcfds profit_undistributed_zcfds rksbf* using  $wei_input/dsgs.dta, clear


do $code_other/clean.do

****************
* Descriptives *
****************

do $code_other/descriptives.do


********************************
* Cost of Capital calculations *
********************************

do $code_other/cost_of_capital.do

***********************
* Tax Loss Take-up RD *
***********************

do $code_other/tax_loss_rd.do

****************************************
* Core Take-up Regressions and Figures *
****************************************

do $code_other/take_up_regressions_and_scatter_plots_new.do

*******************************************************************
* Correlate Tax Administration Measures with Firms Level Measures *
*******************************************************************

do $code_other/admin_correlation_with_otherstuff_new.do

*******************************************************
* Distribution of Claimed and Unclaimed AD Deductions *
*******************************************************

do $code_other/distribution_of_unclaimed_credits.do

***********************************************
* Matching Firms for Difference-in-Difference *
***********************************************

* Manufacturing Control Group *
cap drop control
gl control_group = "manufacturing"
gen control = indcode ==10 & treated2015 !=1 & treated2014 !=1

gl treated_year = "2014"
gl base_year = "2013"
do $code_other/matching.do

gl treated_year = "2015"
gl base_year = "2013"
do $code_other/matching.do

drop control


***************************************
* Descriptive Table of Matched Sample *
***************************************

do $code_other/descriptives_matched.do

****************
* Diff-in-diff *
****************

xtset firm year
eststo clear

do $code_other/user_cost_regressions.do


do $code_other/did.do


* user cost  *
estout Udlnfixed_assets_netm2014 Udlnfixed_assets_netm2015  Ulnfixed_assets_netm2014 Ulnfixed_assets_netm2015 ///
	using $output/table_usercost.tex, replace ///
	keep(logusercost) ///
	order(logusercost) ///
	refcat(inter_loss "Treated $\times$ Post",nolabel) level(90)  ///
	style(tex) nolegend noomitted eqlabels(none) collabels(none) nobaselevels ///
	mlabels("2014" "2015" "2014" "2015")  ///	
	mgroups("\$ Ln(K_t) - Ln(K_{t-1})\$" "\$Ln(K_t) \$" , ///
	prefix(\multicolumn{@span}{c}{) suffix(})  span erepeat(\cmidrule(lr){@span}) pattern(1 0 1 0 )) ///
	varlabels(logusercost "Log User Cost" ///
	, end("" \addlinespace))  label type ///
	cells("b(star fmt(%9.2f) label(Coef))" "ci(par fmt(%9.2f) pattern(1 1 1 1))" ) ///
	stats(N firms_treated firms_control ,  ///
	fmt(0 0 0 0 0 2 2 2 3 2) labels("N" "Treated Firms" "Untreated Firms") ) ///
	prehead("\begin{tabular}{lcccc}" "\multicolumn{5}{c}{Cost of Capital Elasticity Estimates (2SLS)} \\ \midrule"  )  ///
	posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)
	
*main table *
estout dlnfixed_assets_netm2014 dlnfixed_assets_netm2015 lnfixed_assets_netm2014 lnfixed_assets_netm2015  ///
	using $output/main_table_small.tex, replace ///
	keep(inter ) ///
	order(inter )  ///
	refcat(inter_loss "Treated $\times$ Post",nolabel) level(90) ///
	transform(@*100 (@/@)*100)  ///
	style(tex) nolegend noomitted eqlabels(none) collabels(none) nobaselevels ///
	mlabels("2014" "2015" "2014" "2015"  "2014" "2015" ) numbers  ///
	mgroups(" \$ Ln(K_{i,t}) - Ln(K_{i,t-1})\$ " " \$ Ln(K_{i,t})\$\$ " , ///
	prefix(\multicolumn{@span}{c}{) suffix(})  span erepeat(\cmidrule(lr){@span}) pattern(1 0 1 0)) ///
	varlabels(inter "Treat $\times$ Post" ///
	, end("" \addlinespace))  label type ///
	cells("b(star fmt(%9.2f) label(Coef))" "se(par fmt(%9.2f) label(Std. Error))" "ci(par fmt(%9.2f) pattern(1 1 1 1))" ) ///
	stats(N firms_treated firms_control mean_dep ,  ///
	fmt(0 0 0 2 2 2 3 2) labels("N" "Treated Firms" "Untreated Firms"  "Dep. Var Mean") ) ///
	prehead("\begin{tabular}{lcccc}" "\toprule " ) ///
	posthead(\midrule) prefoot(\midrule) postfoot("\midrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)		


*appendix table*
estout capex_salesm2014 capex_salesm2015  dlnfixed_assets1m2014 dlnfixed_assets1m2015 Jdlnfixed_assets_netm2014 Jdlnfixed_assets_netm2015  RDdlnfixed_assets_netm2014 RDdlnfixed_assets_netm2015  ///
SMdlnfixed_assets_netm2014 SMdlnfixed_assets_netm2015  ///
	using $output/table2.tex, replace ///
	keep(inter ) ///
	order(inter ) transform(@*100 (@/@)*100)  ///
	style(tex) nolegend noomitted eqlabels(none) collabels(none) nobaselevels ///
	mlabels("2014" "2015"  "2014" "2015" "2014" "2015" "2014" "2015"  "2014" "2015") numbers  ///
	mgroups("\$\frac{K_{t,net} - K_{t-1,net}}{Sales_{2010-2013}}\$" " Historical Cost" "Time \ $\times\$ Ind " "Excl. RD Claimers" "Excl. SMPE" , ///
	prefix(\multicolumn{@span}{c}{) suffix(})  span erepeat(\cmidrule(lr){@span}) pattern(1 0 1 0 1 0 1 0 1 0 1 0)) ///
	varlabels(inter "Treat $\times$ Post" , end("" \addlinespace))  label type ///
	cells("b(star fmt(%9.2f) label(Coef))" "se(par fmt(%9.2f) label(Std. Error))") ///
	stats( N firms_treated firms_control treated_clusters untreated_clusters mean_dep,  ///
	fmt(0 0 0 0 0 2 2 2 3 2) labels( "N" "Treated Firms" "Untreated Firms" "Treated Clusters" "Untreated Clusters"  "Dep. Var. Mean"  ) ) ///
	prehead("\begin{tabular}{lcccccccccccccc}" "\toprule" )  ///
	posthead(\midrule) prefoot(\midrule) postfoot("\bottomrule" "\end{tabular}") starlevels(* 0.10 ** 0.05 *** .01)			


****************************
* Investment Trends Graphs *
****************************

include $code_other/investment_trends_graph_main.do

include $code_other/investment_trends_graph_main_p95.do

****************************************************************
* Dynamic DiD Figures with Different Specifications and Sample *
****************************************************************

do $code_other/did_robustness.do

******************************
* Split Sample Heterogeneity *
******************************

do $code_other/did_heterogeneity.do

*********************
* DiD By Asset Type *
*********************

do $code_other/did_asset_type.do

*******************************
* Investment By Claim Status  *
*******************************

do $code_other/invesment_by_claimers.do
