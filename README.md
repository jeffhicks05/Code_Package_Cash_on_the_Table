# Code Package for Cash on the_Table

This repoository contains the code used in "Cash on the Table? Imperfect Take-up of Tax Incentives and Firm Investment Behavior" (Wei Cui, Jeffrey Hicks, Jing Xing) 2022. 

We use data from one large anonymous province in China. The data itself is proprietary. Questions about the analysis should be directed to cui@allard.ubc.ca, jeffrey.hicks@utoronto.ca, and jing.xing@sjtu.edu.cn.


The code was written using Stata 14.

master_final.do is the master do-file form which all sub-do files are called. 

1. clean.do prepares the raw data files.
2. cost_of_capital.do calculates the effective changes in the cost of capital caused by accelearated depreciation.
3. tax_loss_rd.do plots the rate of take-up of AD around the tazable income = 0 threshold.
4. take_up_regressions_and_scatter_plots_new.do performs the analysis of take-up behavior in Section 5 of the paper (and relevant appendices).
5. admin_correlation_with_otherstuff_new.do correlates tax administration measures with firm characteristics for the appendix.
6. distribution_of_unclaimed_credits.do calculates summary statistics for the degree of non-take-up including aggregate amounts.
7. matching.do performs the CEM matching for constructing our main DiD analysis.
8. descriptives_matched.do calculates descriptive statistics for the match and un-match samples.
9. user_cost_regressions.do performs the user-cost IV estimations in Appendix Section A3. 
10. did.do performs the main DiD regression analyses.
11. investment_trends_graph_main.do and investment_trends_graph_main_p95.do plot the trends in investment measures.
12. did_robustness.do performs robustness checks on the DiD analysis.
13. did_heterogeneity executes the DiD analyses for different sub-groups of the data.
14. did_asset_type.do executes the DiD analysis for different asset types.
15. invesment_by_claimers.do plots trends in asset growth separately for firms that claimed AD and those that did not.
