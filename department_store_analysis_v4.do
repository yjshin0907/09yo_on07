********************************************************************************
* DEPARTMENT STORE LABOR MARKET IMPACT ANALYSIS
* Staggered Difference-in-Differences
* VERSION 4 - WITH EXPLICIT VARIABLE SPECIFICATIONS AND OCC1950 CODES
*
* KEY CHANGES FROM V3:
* - Uses explicit OCC1950 codes (not text matching)
* - Uses specified variables: yearp, stateicp, countyicp, occ1950
* - Merges on stateicp + countyicp combination
* - Includes individual occupation analysis
********************************************************************************

clear all
set more off
set matsize 11000
cap log close

********************************************************************************
* CONFIGURATION
********************************************************************************

global BASE_PATH "/export/projects4/lzhang_burning_glass_project"

* Data file paths
global CENSUS_DATA   "$BASE_PATH/data/IPUMS/Linked_Census_Final.dta"
global DEPT_STORE    "$BASE_PATH/Yoonjae/department_stores/0_department_opening_firstonly.dta"

* Output directory
global OUTPUT_DIR    "$BASE_PATH/Yoonjae/results/exploratory"

* Create output subdirectories
!mkdir -p "$OUTPUT_DIR"
!mkdir -p "$OUTPUT_DIR/tables"
!mkdir -p "$OUTPUT_DIR/figures"
!mkdir -p "$OUTPUT_DIR/figures/individual_occs"
!mkdir -p "$OUTPUT_DIR/codebooks"
!mkdir -p "$OUTPUT_DIR/data"

* Start log file
log using "$OUTPUT_DIR/analysis_log.txt", replace text

di "========================================================================"
di "DEPARTMENT STORE LABOR MARKET IMPACT ANALYSIS"
di "Started: $S_DATE $S_TIME"
di "========================================================================"

********************************************************************************
* DEFINE OCCUPATION CODES (OCC1950)
* Based on user specification and IPUMS documentation
********************************************************************************

* CREATED occupations - jobs likely created/expanded by department stores
* Sales and retail positions
global OCC_CREATED_SALES "490 200 205 320 420 400"
* 490 = Salesmen and sales clerks (n.e.c.)
* 200 = Buyers and department heads, store
* 205 = Floormen and floor managers, store
* 320 = Cashiers
* 420 = Demonstrators
* 400 = Advertising agents and salesmen

* Clerical and support positions
global OCC_CREATED_CLERICAL "514 342 310 350 341 340"
* 514 = Decorators and window dressers
* 342 = Shipping and receiving clerks
* 310 = Bookkeepers
* 350 = Stenographers, typists, and secretaries
* 341 = Office machine operators
* 340 = Messengers and office boys

* Service positions
global OCC_CREATED_SERVICE "632 761 770 753 763 780 754 760 784"
* 632 = Deliverymen and routemen
* 761 = Elevator operators
* 770 = Janitors and sextons
* 753 = Charwomen and cleaners
* 763 = Guards, watchmen, and doorkeepers
* 780 = Porters
* 754 = Cooks, except private household
* 760 = Counter and fountain workers
* 784 = Waiters and waitresses

* All created occupations combined
global OCC_CREATED "490 200 205 320 420 400 514 342 310 350 341 340 632 761 770 753 763 780 754 760 784"

* DISPLACED occupations - jobs likely replaced by department stores
global OCC_DISPLACED "290 430 410 645 633 590 582"
* 290 = Managers, officials, and proprietors (n.e.c.) - proxy for small shopkeepers
* 430 = Hucksters and peddlers
* 410 = Auctioneers
* 645 = Milliners
* 633 = Dressmakers and seamstresses, except factory
* 590 = Tailors and tailoresses
* 582 = Shoemakers and repairers, except factory

di ""
di "OCCUPATION CODES DEFINED:"
di "  Created (all): $OCC_CREATED"
di "  Displaced: $OCC_DISPLACED"

********************************************************************************
* SECTION 1: LOAD AND DESCRIBE DATASETS
********************************************************************************

di ""
di "========================================================================"
di "SECTION 1: LOADING AND DESCRIBING DATASETS"
di "========================================================================"

*------------------------------------------------------------------------------
* 1.1 Load Census Data
*------------------------------------------------------------------------------
di ""
di "1.1 Loading Census Data..."

use "$CENSUS_DATA", clear

global census_n = _N
global census_k = c(k)

di "    Loaded: $census_n observations, $census_k variables"

* Verify key variables exist
foreach v in yearp stateicp countyicp occ1950 {
    cap confirm variable `v'
    if _rc {
        di as error "    ERROR: Variable `v' not found!"
        exit 1
    }
    else {
        di "    Found: `v'"
    }
}

* Describe key variables
di ""
di "    Key variables:"
di "    yearp (census year):"
tab yearp, missing

di ""
di "    stateicp:"
qui tab stateicp
di "        Unique values: `r(r)'"

di ""
di "    countyicp:"
qui tab countyicp
di "        Unique values: `r(r)'"

di ""
di "    occ1950 (occupation):"
qui sum occ1950
di "        Range: `r(min)' - `r(max)', N = `r(N)'"

* Export full variable list
describe, fullnames
preserve
    describe, replace clear
    export delimited using "$OUTPUT_DIR/tables/census_variables.csv", replace
restore

save "$OUTPUT_DIR/data/census_temp.dta", replace
di ""
di "    >>> Saved: $OUTPUT_DIR/data/census_temp.dta"

*------------------------------------------------------------------------------
* 1.2 Load Department Store Data
*------------------------------------------------------------------------------
di ""
di "========================================================================"
di "1.2 Loading Department Store Opening Data..."

use "$DEPT_STORE", clear

global dept_n = _N
global dept_k = c(k)

di "    Loaded: $dept_n observations, $dept_k variables"

* Verify key variables exist
foreach v in stateicp countyicp {
    cap confirm variable `v'
    if _rc {
        di as error "    ERROR: Variable `v' not found!"
        exit 1
    }
    else {
        di "    Found: `v'"
    }
}

* The data is already at county level with first opening year
* Find the year variable (it's the treatment year)
describe
list in 1/20, clean

* Identify year variable - should be numeric and look like years
ds, has(type numeric)
local numvars `r(varlist)'
di ""
di "    Numeric variables: `numvars'"

* Check each numeric variable for year-like values
foreach v of local numvars {
    if !inlist("`v'", "stateicp", "countyicp") {
        qui sum `v'
        if `r(min)' > 1800 & `r(max)' < 2000 {
            di "    Year variable identified: `v' (range: `r(min)' - `r(max)')"
            global DEPT_YEAR_VAR "`v'"
        }
    }
}

* Verify stateicp + countyicp is unique
duplicates report stateicp countyicp
qui duplicates report stateicp countyicp
if r(unique_value) != _N {
    di as error "    WARNING: stateicp + countyicp is not unique!"
}
else {
    di "    Confirmed: stateicp + countyicp uniquely identifies counties"
    di "    Number of treated counties: `c(N)'"
}

save "$OUTPUT_DIR/data/dept_store_temp.dta", replace
di ""
di "    >>> Saved: $OUTPUT_DIR/data/dept_store_temp.dta"

di ""
di "========================================================================"
di "SECTION 1 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 2: CREATE TREATMENT TIMING DATA
*
* The department store data already has one row per county with the first
* opening year. We just need to rename the year variable and save.
********************************************************************************

di ""
di "========================================================================"
di "SECTION 2: CREATING TREATMENT TIMING DATA"
di "========================================================================"

use "$OUTPUT_DIR/data/dept_store_temp.dta", clear

* Rename year variable to first_dept_store_year
* Use the identified year variable or find it
ds, has(type numeric)
foreach v of varlist `r(varlist)' {
    if !inlist("`v'", "stateicp", "countyicp") {
        qui sum `v'
        if `r(min)' > 1800 & `r(max)' < 2000 {
            rename `v' first_dept_store_year
            di "    Renamed `v' to first_dept_store_year"
            continue, break
        }
    }
}

* Keep only merge keys and treatment year
keep stateicp countyicp first_dept_store_year

di ""
di "    Treatment timing summary:"
di "    Number of treated counties: `c(N)'"
qui sum first_dept_store_year
di "    First opening year range: `r(min)' - `r(max)'"

di ""
di "    Treatment timing distribution:"
tab first_dept_store_year, missing

* Save
export delimited using "$OUTPUT_DIR/tables/treatment_timing.csv", replace
save "$OUTPUT_DIR/data/treatment_timing.dta", replace
di ""
di "    >>> Saved: $OUTPUT_DIR/data/treatment_timing.dta"

* Visualizations
hist first_dept_store_year, frequency ///
    title("Distribution of First Department Store Openings") ///
    xtitle("Year") ytitle("Number of Counties") ///
    color(navy%70)
graph export "$OUTPUT_DIR/figures/treatment_timing_hist.png", replace

preserve
    gen one = 1
    collapse (count) n_counties = one, by(first_dept_store_year)
    gen cumulative = sum(n_counties)

    twoway line cumulative first_dept_store_year, ///
        title("Cumulative Department Store Adoption") ///
        xtitle("Year") ytitle("Cumulative Number of Counties") ///
        lcolor(navy) lwidth(medium)
    graph export "$OUTPUT_DIR/figures/cumulative_adoption.png", replace
restore

di ""
di "========================================================================"
di "SECTION 2 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 3: CREATE OCCUPATION INDICATORS
*
* Using explicit OCC1950 codes (not text matching)
********************************************************************************

di ""
di "========================================================================"
di "SECTION 3: CREATING OCCUPATION INDICATORS (OCC1950 CODES)"
di "========================================================================"

use "$OUTPUT_DIR/data/census_temp.dta", clear

*------------------------------------------------------------------------------
* 3.1 Create aggregate indicators
*------------------------------------------------------------------------------
di ""
di "3.1 Creating Aggregate Occupation Indicators..."

* DISPLACED occupations (aggregate)
gen occ_displaced = 0
label var occ_displaced "1=Occupation likely displaced by dept stores"
replace occ_displaced = 1 if inlist(occ1950, 290, 430, 410, 645, 633, 590, 582)

* CREATED occupations (aggregate)
gen occ_created = 0
label var occ_created "1=Occupation likely created by dept stores"
replace occ_created = 1 if inlist(occ1950, 490, 200, 205, 320, 420, 400)
replace occ_created = 1 if inlist(occ1950, 514, 342, 310, 350, 341, 340)
replace occ_created = 1 if inlist(occ1950, 632, 761, 770, 753, 763, 780, 754, 760, 784)

* Created subcategories
gen occ_created_sales = 0
label var occ_created_sales "1=Sales occupations created by dept stores"
replace occ_created_sales = 1 if inlist(occ1950, 490, 200, 205, 320, 420, 400)

gen occ_created_clerical = 0
label var occ_created_clerical "1=Clerical occupations created by dept stores"
replace occ_created_clerical = 1 if inlist(occ1950, 514, 342, 310, 350, 341, 340)

gen occ_created_service = 0
label var occ_created_service "1=Service occupations created by dept stores"
replace occ_created_service = 1 if inlist(occ1950, 632, 761, 770, 753, 763, 780, 754, 760, 784)

di ""
di "    Aggregate indicators created:"
tab occ_displaced, missing
tab occ_created, missing

*------------------------------------------------------------------------------
* 3.2 Create individual occupation indicators
*------------------------------------------------------------------------------
di ""
di "3.2 Creating Individual Occupation Indicators..."

* CREATED occupations - individual
gen occ_490 = (occ1950 == 490)
label var occ_490 "Salesmen and sales clerks (n.e.c.)"

gen occ_200 = (occ1950 == 200)
label var occ_200 "Buyers and department heads, store"

gen occ_205 = (occ1950 == 205)
label var occ_205 "Floormen and floor managers, store"

gen occ_320 = (occ1950 == 320)
label var occ_320 "Cashiers"

gen occ_420 = (occ1950 == 420)
label var occ_420 "Demonstrators"

gen occ_400 = (occ1950 == 400)
label var occ_400 "Advertising agents and salesmen"

gen occ_514 = (occ1950 == 514)
label var occ_514 "Decorators and window dressers"

gen occ_342 = (occ1950 == 342)
label var occ_342 "Shipping and receiving clerks"

gen occ_632 = (occ1950 == 632)
label var occ_632 "Deliverymen and routemen"

gen occ_310 = (occ1950 == 310)
label var occ_310 "Bookkeepers"

gen occ_350 = (occ1950 == 350)
label var occ_350 "Stenographers, typists, and secretaries"

gen occ_341 = (occ1950 == 341)
label var occ_341 "Office machine operators"

gen occ_340 = (occ1950 == 340)
label var occ_340 "Messengers and office boys"

gen occ_761 = (occ1950 == 761)
label var occ_761 "Elevator operators"

gen occ_770 = (occ1950 == 770)
label var occ_770 "Janitors and sextons"

gen occ_753 = (occ1950 == 753)
label var occ_753 "Charwomen and cleaners"

gen occ_763 = (occ1950 == 763)
label var occ_763 "Guards, watchmen, and doorkeepers"

gen occ_780 = (occ1950 == 780)
label var occ_780 "Porters"

gen occ_754 = (occ1950 == 754)
label var occ_754 "Cooks, except private household"

gen occ_760 = (occ1950 == 760)
label var occ_760 "Counter and fountain workers"

gen occ_784 = (occ1950 == 784)
label var occ_784 "Waiters and waitresses"

* DISPLACED occupations - individual
gen occ_290 = (occ1950 == 290)
label var occ_290 "Managers, officials, proprietors (n.e.c.)"

gen occ_430 = (occ1950 == 430)
label var occ_430 "Hucksters and peddlers"

gen occ_410 = (occ1950 == 410)
label var occ_410 "Auctioneers"

gen occ_645 = (occ1950 == 645)
label var occ_645 "Milliners"

gen occ_633 = (occ1950 == 633)
label var occ_633 "Dressmakers and seamstresses, except factory"

gen occ_590 = (occ1950 == 590)
label var occ_590 "Tailors and tailoresses"

gen occ_582 = (occ1950 == 582)
label var occ_582 "Shoemakers and repairers, except factory"

*------------------------------------------------------------------------------
* 3.3 Summary statistics for occupations
*------------------------------------------------------------------------------
di ""
di "3.3 Occupation Summary Statistics:"

di ""
di "    CREATED OCCUPATIONS:"
di "    ===================="
foreach code in 490 200 205 320 420 400 514 342 632 310 350 341 340 761 770 753 763 780 754 760 784 {
    qui sum occ_`code'
    local lbl : variable label occ_`code'
    di "    `code': `lbl' - N = " %10.0fc `r(sum)' " (" %5.2f `r(mean)'*100 "%)"
}

di ""
di "    DISPLACED OCCUPATIONS:"
di "    ======================"
foreach code in 290 430 410 645 633 590 582 {
    qui sum occ_`code'
    local lbl : variable label occ_`code'
    di "    `code': `lbl' - N = " %10.0fc `r(sum)' " (" %5.2f `r(mean)'*100 "%)"
}

* Export occupation frequencies
preserve
    contract occ1950, freq(count)
    gen pct = count / $census_n * 100

    * Add labels
    gen occ_label = ""
    replace occ_label = "Salesmen and sales clerks" if occ1950 == 490
    replace occ_label = "Buyers and dept heads, store" if occ1950 == 200
    replace occ_label = "Floormen and floor managers" if occ1950 == 205
    replace occ_label = "Cashiers" if occ1950 == 320
    replace occ_label = "Demonstrators" if occ1950 == 420
    replace occ_label = "Advertising agents" if occ1950 == 400
    replace occ_label = "Decorators and window dressers" if occ1950 == 514
    replace occ_label = "Shipping and receiving clerks" if occ1950 == 342
    replace occ_label = "Deliverymen and routemen" if occ1950 == 632
    replace occ_label = "Bookkeepers" if occ1950 == 310
    replace occ_label = "Stenographers, typists, secretaries" if occ1950 == 350
    replace occ_label = "Office machine operators" if occ1950 == 341
    replace occ_label = "Messengers and office boys" if occ1950 == 340
    replace occ_label = "Elevator operators" if occ1950 == 761
    replace occ_label = "Janitors and sextons" if occ1950 == 770
    replace occ_label = "Charwomen and cleaners" if occ1950 == 753
    replace occ_label = "Guards, watchmen, doorkeepers" if occ1950 == 763
    replace occ_label = "Porters" if occ1950 == 780
    replace occ_label = "Cooks, except private household" if occ1950 == 754
    replace occ_label = "Counter and fountain workers" if occ1950 == 760
    replace occ_label = "Waiters and waitresses" if occ1950 == 784
    replace occ_label = "Managers, officials, proprietors" if occ1950 == 290
    replace occ_label = "Hucksters and peddlers" if occ1950 == 430
    replace occ_label = "Auctioneers" if occ1950 == 410
    replace occ_label = "Milliners" if occ1950 == 645
    replace occ_label = "Dressmakers and seamstresses" if occ1950 == 633
    replace occ_label = "Tailors and tailoresses" if occ1950 == 590
    replace occ_label = "Shoemakers and repairers" if occ1950 == 582

    gen is_created = inlist(occ1950, 490, 200, 205, 320, 420, 400, 514, 342, 310, 350, 341, 340)
    replace is_created = 1 if inlist(occ1950, 632, 761, 770, 753, 763, 780, 754, 760, 784)
    gen is_displaced = inlist(occ1950, 290, 430, 410, 645, 633, 590, 582)

    gsort -count
    export delimited using "$OUTPUT_DIR/tables/occupation_codes_full.csv", replace

    * Export just created/displaced occupations
    keep if is_created == 1 | is_displaced == 1
    gsort is_displaced -count
    export delimited using "$OUTPUT_DIR/tables/target_occupations.csv", replace
restore

*------------------------------------------------------------------------------
* 3.4 Occupation distributions over time
*------------------------------------------------------------------------------
di ""
di "3.4 Occupation Distributions Over Time:"

* Aggregate by year
preserve
    collapse (sum) n_displaced=occ_displaced n_created=occ_created ///
             (mean) pct_displaced=occ_displaced pct_created=occ_created ///
             (count) total=occ_displaced, by(yearp)
    replace pct_displaced = pct_displaced * 100
    replace pct_created = pct_created * 100

    di ""
    list, clean
    export delimited using "$OUTPUT_DIR/tables/occupations_by_year.csv", replace

    * Visualization
    twoway (line pct_displaced yearp, lcolor(red) lwidth(medium)) ///
           (line pct_created yearp, lcolor(green) lwidth(medium)), ///
        title("Occupation Shares Over Time") ///
        xtitle("Census Year") ytitle("Percent") ///
        legend(order(1 "Displaced" 2 "Created"))
    graph export "$OUTPUT_DIR/figures/occupation_trends.png", replace
restore

* Save census data with occupation indicators
save "$OUTPUT_DIR/data/census_with_occ.dta", replace
di ""
di "    >>> Saved: $OUTPUT_DIR/data/census_with_occ.dta"

di ""
di "========================================================================"
di "SECTION 3 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 4: MERGE DATASETS
*
* Merge on stateicp + countyicp
********************************************************************************

di ""
di "========================================================================"
di "SECTION 4: MERGING DATASETS"
di "========================================================================"

use "$OUTPUT_DIR/data/census_with_occ.dta", clear

di ""
di "4.1 Merging census data with treatment timing..."
di "    Merge keys: stateicp + countyicp"

merge m:1 stateicp countyicp using "$OUTPUT_DIR/data/treatment_timing.dta", ///
    keep(master match) gen(_merge_treatment)

di ""
di "    Merge Results:"
tab _merge_treatment

*------------------------------------------------------------------------------
* 4.2 Create treatment indicators
*------------------------------------------------------------------------------
di ""
di "4.2 Creating Treatment Indicators..."

* Ever treated
gen ever_treated = (first_dept_store_year != .)
label var ever_treated "1=County ever receives department store"

* Currently treated (post-treatment)
gen treated = (first_dept_store_year != .) & (yearp >= first_dept_store_year)
label var treated "1=Post-treatment period"

* Event time (years relative to treatment)
gen event_time = yearp - first_dept_store_year
label var event_time "Years relative to treatment"

di ""
di "    Treatment Variable Summary:"
di "    ============================="
tab ever_treated, missing

di ""
tab treated, missing

di ""
di "    Event time distribution (treated units only):"
tab event_time if ever_treated == 1, missing

*------------------------------------------------------------------------------
* 4.3 Summary by treatment status
*------------------------------------------------------------------------------
di ""
di "4.3 Sample by Treatment Status and Year:"
tab yearp ever_treated, missing

* Save merged data
save "$OUTPUT_DIR/data/merged_analysis_data.dta", replace
export delimited using "$OUTPUT_DIR/data/merged_analysis_data.csv", replace
di ""
di "    >>> Saved: $OUTPUT_DIR/data/merged_analysis_data.dta"

di ""
di "========================================================================"
di "SECTION 4 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 5: SUMMARY STATISTICS
********************************************************************************

di ""
di "========================================================================"
di "SECTION 5: SUMMARY STATISTICS"
di "========================================================================"

use "$OUTPUT_DIR/data/merged_analysis_data.dta", clear

*------------------------------------------------------------------------------
* 5.1 Occupation distribution by treatment status
*------------------------------------------------------------------------------
di ""
di "5.1 Occupation Distribution by Treatment Status:"

di ""
di "    AGGREGATE:"
table ever_treated, stat(sum occ_displaced) stat(mean occ_displaced) stat(count occ_displaced)
table ever_treated, stat(sum occ_created) stat(mean occ_created) stat(count occ_created)

di ""
di "    BY SUBCATEGORY:"
table ever_treated, stat(mean occ_created_sales) stat(mean occ_created_clerical) stat(mean occ_created_service)

*------------------------------------------------------------------------------
* 5.2 Individual occupation frequencies by treatment status
*------------------------------------------------------------------------------
di ""
di "5.2 Individual Occupation Frequencies:"

* Created occupations
di ""
di "    CREATED OCCUPATIONS (mean by treatment status):"
foreach code in 490 200 205 320 420 400 514 342 632 310 350 341 340 761 770 753 763 780 754 760 784 {
    local lbl : variable label occ_`code'
    qui sum occ_`code' if ever_treated == 0
    local mean0 = r(mean) * 100
    qui sum occ_`code' if ever_treated == 1
    local mean1 = r(mean) * 100
    local diff = `mean1' - `mean0'
    di "    `code' (`lbl'): Control = " %5.2f `mean0' "%, Treated = " %5.2f `mean1' "%, Diff = " %5.2f `diff' "%"
}

* Displaced occupations
di ""
di "    DISPLACED OCCUPATIONS (mean by treatment status):"
foreach code in 290 430 410 645 633 590 582 {
    local lbl : variable label occ_`code'
    qui sum occ_`code' if ever_treated == 0
    local mean0 = r(mean) * 100
    qui sum occ_`code' if ever_treated == 1
    local mean1 = r(mean) * 100
    local diff = `mean1' - `mean0'
    di "    `code' (`lbl'): Control = " %5.2f `mean0' "%, Treated = " %5.2f `mean1' "%, Diff = " %5.2f `diff' "%"
}

di ""
di "========================================================================"
di "SECTION 5 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 6: VISUALIZATIONS - AGGREGATE
********************************************************************************

di ""
di "========================================================================"
di "SECTION 6: AGGREGATE VISUALIZATIONS"
di "========================================================================"

use "$OUTPUT_DIR/data/merged_analysis_data.dta", clear

*------------------------------------------------------------------------------
* 6.1 Pre-trends - Aggregate
*------------------------------------------------------------------------------
di ""
di "6.1 Pre-Trends (Aggregate):"

* Displaced
preserve
    collapse (mean) occ_displaced, by(yearp ever_treated)
    replace occ_displaced = occ_displaced * 100
    reshape wide occ_displaced, i(yearp) j(ever_treated)

    twoway (line occ_displaced0 yearp, lcolor(blue) lwidth(medium)) ///
           (line occ_displaced1 yearp, lcolor(red) lwidth(medium)), ///
        title("Pre-Trends: Displaced Occupations (Aggregate)") ///
        xtitle("Census Year") ytitle("Percent") ///
        legend(order(1 "Never Treated" 2 "Ever Treated"))
    graph export "$OUTPUT_DIR/figures/pretrend_displaced.png", replace
restore

* Created
preserve
    collapse (mean) occ_created, by(yearp ever_treated)
    replace occ_created = occ_created * 100
    reshape wide occ_created, i(yearp) j(ever_treated)

    twoway (line occ_created0 yearp, lcolor(blue) lwidth(medium)) ///
           (line occ_created1 yearp, lcolor(red) lwidth(medium)), ///
        title("Pre-Trends: Created Occupations (Aggregate)") ///
        xtitle("Census Year") ytitle("Percent") ///
        legend(order(1 "Never Treated" 2 "Ever Treated"))
    graph export "$OUTPUT_DIR/figures/pretrend_created.png", replace
restore

*------------------------------------------------------------------------------
* 6.2 Event Study - Aggregate
*------------------------------------------------------------------------------
di ""
di "6.2 Event Study (Aggregate):"

* Displaced
preserve
    keep if ever_treated == 1
    keep if event_time >= -30 & event_time <= 30

    collapse (mean) mean=occ_displaced (sd) sd=occ_displaced (count) n=occ_displaced, by(event_time)
    gen se = sd / sqrt(n)
    gen ci_lo = mean - 1.96*se
    gen ci_hi = mean + 1.96*se

    twoway (rcap ci_lo ci_hi event_time, lcolor(gray)) ///
           (scatter mean event_time, mcolor(navy) msize(small)), ///
        xline(0, lcolor(red) lpattern(dash)) ///
        title("Event Study: Displaced Occupations (Aggregate)") ///
        xtitle("Years Relative to Treatment") ytitle("Share") ///
        legend(off)
    graph export "$OUTPUT_DIR/figures/event_study_displaced.png", replace
restore

* Created
preserve
    keep if ever_treated == 1
    keep if event_time >= -30 & event_time <= 30

    collapse (mean) mean=occ_created (sd) sd=occ_created (count) n=occ_created, by(event_time)
    gen se = sd / sqrt(n)
    gen ci_lo = mean - 1.96*se
    gen ci_hi = mean + 1.96*se

    twoway (rcap ci_lo ci_hi event_time, lcolor(gray)) ///
           (scatter mean event_time, mcolor(green) msize(small)), ///
        xline(0, lcolor(red) lpattern(dash)) ///
        title("Event Study: Created Occupations (Aggregate)") ///
        xtitle("Years Relative to Treatment") ytitle("Share") ///
        legend(off)
    graph export "$OUTPUT_DIR/figures/event_study_created.png", replace
restore

di ""
di "========================================================================"
di "SECTION 6 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 7: VISUALIZATIONS - INDIVIDUAL OCCUPATIONS
********************************************************************************

di ""
di "========================================================================"
di "SECTION 7: INDIVIDUAL OCCUPATION VISUALIZATIONS"
di "========================================================================"

use "$OUTPUT_DIR/data/merged_analysis_data.dta", clear

*------------------------------------------------------------------------------
* 7.1 Pre-trends for each CREATED occupation
*------------------------------------------------------------------------------
di ""
di "7.1 Pre-Trends for Individual CREATED Occupations:"

foreach code in 490 200 205 320 420 400 514 342 632 310 350 341 340 761 770 753 763 780 754 760 784 {
    local lbl : variable label occ_`code'
    di "    Processing: `code' - `lbl'"

    preserve
        collapse (mean) occ_`code', by(yearp ever_treated)
        replace occ_`code' = occ_`code' * 100
        reshape wide occ_`code', i(yearp) j(ever_treated)

        twoway (line occ_`code'0 yearp, lcolor(blue) lwidth(medium)) ///
               (line occ_`code'1 yearp, lcolor(red) lwidth(medium)), ///
            title("Pre-Trends: `code' - `lbl'") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Never Treated" 2 "Ever Treated"))
        graph export "$OUTPUT_DIR/figures/individual_occs/pretrend_`code'.png", replace
    restore
}

*------------------------------------------------------------------------------
* 7.2 Pre-trends for each DISPLACED occupation
*------------------------------------------------------------------------------
di ""
di "7.2 Pre-Trends for Individual DISPLACED Occupations:"

foreach code in 290 430 410 645 633 590 582 {
    local lbl : variable label occ_`code'
    di "    Processing: `code' - `lbl'"

    preserve
        collapse (mean) occ_`code', by(yearp ever_treated)
        replace occ_`code' = occ_`code' * 100
        reshape wide occ_`code', i(yearp) j(ever_treated)

        twoway (line occ_`code'0 yearp, lcolor(blue) lwidth(medium)) ///
               (line occ_`code'1 yearp, lcolor(red) lwidth(medium)), ///
            title("Pre-Trends: `code' - `lbl'") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Never Treated" 2 "Ever Treated"))
        graph export "$OUTPUT_DIR/figures/individual_occs/pretrend_`code'.png", replace
    restore
}

*------------------------------------------------------------------------------
* 7.3 Event studies for individual occupations (selected)
*------------------------------------------------------------------------------
di ""
di "7.3 Event Studies for Selected Individual Occupations:"

* Key created occupations
foreach code in 490 200 320 350 770 {
    local lbl : variable label occ_`code'
    di "    Processing event study: `code' - `lbl'"

    preserve
        keep if ever_treated == 1
        keep if event_time >= -30 & event_time <= 30

        collapse (mean) mean=occ_`code' (sd) sd=occ_`code' (count) n=occ_`code', by(event_time)
        gen se = sd / sqrt(n)
        gen ci_lo = mean - 1.96*se
        gen ci_hi = mean + 1.96*se

        twoway (rcap ci_lo ci_hi event_time, lcolor(gray)) ///
               (scatter mean event_time, mcolor(green) msize(small)), ///
            xline(0, lcolor(red) lpattern(dash)) ///
            title("Event Study: `code' - `lbl'") ///
            xtitle("Years Relative to Treatment") ytitle("Share") ///
            legend(off)
        graph export "$OUTPUT_DIR/figures/individual_occs/event_`code'.png", replace
    restore
}

* Key displaced occupations
foreach code in 290 430 590 633 {
    local lbl : variable label occ_`code'
    di "    Processing event study: `code' - `lbl'"

    preserve
        keep if ever_treated == 1
        keep if event_time >= -30 & event_time <= 30

        collapse (mean) mean=occ_`code' (sd) sd=occ_`code' (count) n=occ_`code', by(event_time)
        gen se = sd / sqrt(n)
        gen ci_lo = mean - 1.96*se
        gen ci_hi = mean + 1.96*se

        twoway (rcap ci_lo ci_hi event_time, lcolor(gray)) ///
               (scatter mean event_time, mcolor(navy) msize(small)), ///
            xline(0, lcolor(red) lpattern(dash)) ///
            title("Event Study: `code' - `lbl'") ///
            xtitle("Years Relative to Treatment") ytitle("Share") ///
            legend(off)
        graph export "$OUTPUT_DIR/figures/individual_occs/event_`code'.png", replace
    restore
}

di ""
di "========================================================================"
di "SECTION 7 COMPLETE"
di "========================================================================"

********************************************************************************
* SECTION 8: CREATE CODEBOOK
********************************************************************************

di ""
di "========================================================================"
di "SECTION 8: CREATING CODEBOOK"
di "========================================================================"

file open codebook using "$OUTPUT_DIR/codebooks/codebook.txt", write replace

file write codebook "========================================================================" _n
file write codebook "CODEBOOK: Department Store Labor Market Impact Analysis" _n
file write codebook "Generated: $S_DATE $S_TIME" _n
file write codebook "========================================================================" _n _n

file write codebook "1. DATA SOURCES" _n
file write codebook "----------------------------------------" _n
file write codebook "Census Data: $CENSUS_DATA" _n
file write codebook "  Observations: $census_n" _n _n
file write codebook "Department Store Data: $DEPT_STORE" _n
file write codebook "  Observations (counties): $dept_n" _n _n

file write codebook "2. KEY VARIABLES" _n
file write codebook "----------------------------------------" _n
file write codebook "yearp: Census year (decennial)" _n
file write codebook "stateicp: State ICP code" _n
file write codebook "countyicp: County ICP code" _n
file write codebook "occ1950: Occupation code (1950 basis)" _n _n

file write codebook "3. TREATMENT VARIABLES" _n
file write codebook "----------------------------------------" _n
file write codebook "first_dept_store_year: Year county first received department store" _n
file write codebook "ever_treated: 1=County ever receives department store" _n
file write codebook "treated: 1=Post-treatment period (yearp >= first_dept_store_year)" _n
file write codebook "event_time: Years relative to treatment (yearp - first_dept_store_year)" _n _n

file write codebook "4. OCCUPATION CLASSIFICATION (OCC1950 CODES)" _n
file write codebook "----------------------------------------" _n _n

file write codebook "CREATED OCCUPATIONS (occ_created=1):" _n
file write codebook "  Sales:" _n
file write codebook "    490 - Salesmen and sales clerks (n.e.c.)" _n
file write codebook "    200 - Buyers and department heads, store" _n
file write codebook "    205 - Floormen and floor managers, store" _n
file write codebook "    320 - Cashiers" _n
file write codebook "    420 - Demonstrators" _n
file write codebook "    400 - Advertising agents and salesmen" _n
file write codebook "  Clerical:" _n
file write codebook "    514 - Decorators and window dressers" _n
file write codebook "    342 - Shipping and receiving clerks" _n
file write codebook "    310 - Bookkeepers" _n
file write codebook "    350 - Stenographers, typists, and secretaries" _n
file write codebook "    341 - Office machine operators" _n
file write codebook "    340 - Messengers and office boys" _n
file write codebook "  Service:" _n
file write codebook "    632 - Deliverymen and routemen" _n
file write codebook "    761 - Elevator operators" _n
file write codebook "    770 - Janitors and sextons" _n
file write codebook "    753 - Charwomen and cleaners" _n
file write codebook "    763 - Guards, watchmen, and doorkeepers" _n
file write codebook "    780 - Porters" _n
file write codebook "    754 - Cooks, except private household" _n
file write codebook "    760 - Counter and fountain workers" _n
file write codebook "    784 - Waiters and waitresses" _n _n

file write codebook "DISPLACED OCCUPATIONS (occ_displaced=1):" _n
file write codebook "    290 - Managers, officials, and proprietors (n.e.c.)" _n
file write codebook "    430 - Hucksters and peddlers" _n
file write codebook "    410 - Auctioneers" _n
file write codebook "    645 - Milliners" _n
file write codebook "    633 - Dressmakers and seamstresses, except factory" _n
file write codebook "    590 - Tailors and tailoresses" _n
file write codebook "    582 - Shoemakers and repairers, except factory" _n _n

file write codebook "5. INDIVIDUAL OCCUPATION INDICATORS" _n
file write codebook "----------------------------------------" _n
file write codebook "occ_XXX: 1 if occ1950==XXX, 0 otherwise" _n
file write codebook "  (e.g., occ_490 = 1 if salesmen/sales clerks)" _n

file close codebook

di "    Codebook saved to: $OUTPUT_DIR/codebooks/codebook.txt"

di ""
di "========================================================================"
di "SECTION 8 COMPLETE"
di "========================================================================"

********************************************************************************
* FINAL SUMMARY
********************************************************************************

di ""
di "========================================================================"
di "ANALYSIS COMPLETE"
di "========================================================================"
di ""
di "End time: $S_DATE $S_TIME"
di ""
di "INTERMEDIATE FILES:"
di "  $OUTPUT_DIR/data/census_temp.dta"
di "  $OUTPUT_DIR/data/dept_store_temp.dta"
di "  $OUTPUT_DIR/data/treatment_timing.dta"
di "  $OUTPUT_DIR/data/census_with_occ.dta"
di "  $OUTPUT_DIR/data/merged_analysis_data.dta (FINAL)"
di ""
di "TABLES:"
di "  $OUTPUT_DIR/tables/treatment_timing.csv"
di "  $OUTPUT_DIR/tables/occupation_codes_full.csv"
di "  $OUTPUT_DIR/tables/target_occupations.csv"
di "  $OUTPUT_DIR/tables/occupations_by_year.csv"
di ""
di "FIGURES:"
di "  Aggregate: pretrend_displaced.png, pretrend_created.png"
di "            event_study_displaced.png, event_study_created.png"
di "  Individual: figures/individual_occs/pretrend_XXX.png"
di "              figures/individual_occs/event_XXX.png"
di ""

log close

********************************************************************************
* END OF SCRIPT
********************************************************************************
