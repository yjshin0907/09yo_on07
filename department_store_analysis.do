********************************************************************************
* DEPARTMENT STORE LABOR MARKET IMPACT ANALYSIS
* Staggered Difference-in-Differences
*
* This script analyzes the impact of department store openings on local labor
* markets using linked census data and department store opening records.
********************************************************************************

clear all
set more off
set matsize 11000
cap log close

********************************************************************************
* CONFIGURATION - ADJUST THESE PATHS FOR YOUR SYSTEM
********************************************************************************

* Base path - adjust this to your mounted drive location
* On Mac, SMB mounts are typically at /Volumes/
* Check your Finder or run 'df -h' in Terminal to find the mount point

global BASE_PATH "/Volumes/projects4/lzhang_burning_glass_project"

* Alternative paths (uncomment if needed):
* global BASE_PATH "/Volumes/lzhang_burning_glass_project"

* Data file paths
global CENSUS_DATA   "$BASE_PATH/data/IPUMS/Linked_Census_Final.dta"
global DEPT_STORE    "$BASE_PATH/Yoonjae/department_stores/0_department_opening_firstonly.dta"

* Output directory
global OUTPUT_DIR    "$BASE_PATH/Yoonjae/results/exploratory"

* Create output subdirectories
cap mkdir "$OUTPUT_DIR"
cap mkdir "$OUTPUT_DIR/tables"
cap mkdir "$OUTPUT_DIR/figures"
cap mkdir "$OUTPUT_DIR/codebooks"
cap mkdir "$OUTPUT_DIR/data"

* Start log file
log using "$OUTPUT_DIR/analysis_log.txt", replace text

di "========================================================================"
di "DEPARTMENT STORE LABOR MARKET IMPACT ANALYSIS"
di "Started: $S_DATE $S_TIME"
di "========================================================================"
di ""
di "Configuration:"
di "  Base path: $BASE_PATH"
di "  Census data: $CENSUS_DATA"
di "  Dept store data: $DEPT_STORE"
di "  Output directory: $OUTPUT_DIR"
di ""

********************************************************************************
* SECTION 1: LOAD AND DESCRIBE DATASETS
********************************************************************************

di "========================================================================"
di "SECTION 1: LOADING AND DESCRIBING DATASETS"
di "========================================================================"

*------------------------------------------------------------------------------
* 1.1 Load and describe Census Data
*------------------------------------------------------------------------------
di ""
di "1.1 Loading Census Data..."
di "    Path: $CENSUS_DATA"

use "$CENSUS_DATA", clear

di ""
di "    SUCCESS: Loaded `c(N)' observations, `c(k)' variables"

* Save sample size
local census_n = _N
local census_k = c(k)

* Describe all variables
di ""
di "1.1.1 Census Data Variable List:"
describe, fullnames

* Save variable list to file
describe, fullnames
log off
describe using "$CENSUS_DATA", fullnames
log on

* Export variable descriptions
preserve
    describe, replace clear
    export delimited using "$OUTPUT_DIR/tables/census_variables.csv", replace
restore

* Check for year variables and their coverage
di ""
di "1.1.2 Time Period Coverage:"
ds *year*
local year_vars `r(varlist)'
di "    Year variables found: `year_vars'"

foreach yv of local year_vars {
    cap confirm numeric variable `yv'
    if !_rc {
        qui sum `yv'
        di "    `yv': `r(min)' - `r(max)'"
        tab `yv', missing
    }
}

* Check occupation variables
di ""
di "1.1.3 Occupation Coding System:"
ds *occ*
local occ_vars `r(varlist)'
di "    Occupation variables found: `occ_vars'"

foreach ov of local occ_vars {
    di ""
    di "    Variable: `ov'"
    cap confirm numeric variable `ov'
    if !_rc {
        qui sum `ov'
        di "        Range: `r(min)' - `r(max)'"
        di "        N non-missing: `r(N)'"

        * Check if has value labels
        local lbl : value label `ov'
        if "`lbl'" != "" {
            di "        Has value labels: Yes (`lbl')"
            di "        First 30 labels:"
            label list `lbl'
        }
        else {
            di "        Has value labels: No"
        }
    }
}

* Save census data temporarily
tempfile census_data
save `census_data', replace

*------------------------------------------------------------------------------
* 1.2 Load and describe Department Store Data
*------------------------------------------------------------------------------
di ""
di "========================================================================"
di "1.2 Loading Department Store Opening Data..."
di "    Path: $DEPT_STORE"

use "$DEPT_STORE", clear

di ""
di "    SUCCESS: Loaded `c(N)' observations, `c(k)' variables"

local dept_n = _N
local dept_k = c(k)

* Describe all variables
di ""
di "1.2.1 Department Store Data Variable List:"
describe, fullnames

* Export variable descriptions
preserve
    describe, replace clear
    export delimited using "$OUTPUT_DIR/tables/dept_store_variables.csv", replace
restore

* Sample preview
di ""
di "1.2.2 Sample Data Preview (first 20 observations):"
list in 1/20, clean

* Check year/time variables
di ""
di "1.2.3 Department Store Opening Timeline:"
ds *year* *open*
local year_vars_dept `r(varlist)'
di "    Year-related columns: `year_vars_dept'"

foreach yv of local year_vars_dept {
    cap confirm numeric variable `yv'
    if !_rc {
        qui sum `yv'
        di ""
        di "    `yv':"
        di "        Range: `r(min)' - `r(max)'"
        tab `yv', missing
    }
}

* Save department store data temporarily
tempfile dept_store_data
save `dept_store_data', replace

********************************************************************************
* SECTION 2: IDENTIFY COUNTY AND YEAR VARIABLES
********************************************************************************

di ""
di "========================================================================"
di "SECTION 2: IDENTIFYING KEY VARIABLES (COUNTY, YEAR)"
di "========================================================================"

*------------------------------------------------------------------------------
* 2.1 Census Data Key Variables
*------------------------------------------------------------------------------
di ""
di "2.1 Census Data Key Variables:"

use `census_data', clear

* Look for geographic identifiers
di ""
di "    Searching for geographic variables..."
ds *county* *fips* *state* *icp*
local census_geo_vars `r(varlist)'
di "    Geographic variables found: `census_geo_vars'"

foreach gv of local census_geo_vars {
    di ""
    di "    `gv':"
    qui tab `gv'
    di "        Unique values: `r(r)'"
    cap confirm numeric variable `gv'
    if !_rc {
        qui sum `gv'
        di "        Range: `r(min)' - `r(max)'"
    }
}

* Year variables
di ""
di "    Year variables:"
ds *year* *yr*
local census_year_vars `r(varlist)'
di "    `census_year_vars'"

*------------------------------------------------------------------------------
* 2.2 Department Store Data Key Variables
*------------------------------------------------------------------------------
di ""
di "2.2 Department Store Data Key Variables:"

use `dept_store_data', clear

di ""
di "    Searching for geographic variables..."
ds *county* *fips* *state* *icp*
local dept_geo_vars `r(varlist)'
di "    Geographic variables found: `dept_geo_vars'"

foreach gv of local dept_geo_vars {
    di ""
    di "    `gv':"
    qui tab `gv'
    di "        Unique values: `r(r)'"
}

ds *year* *open*
local dept_year_vars `r(varlist)'
di ""
di "    Year variables: `dept_year_vars'"

********************************************************************************
* SECTION 3: CREATE TREATMENT VARIABLE
********************************************************************************

di ""
di "========================================================================"
di "SECTION 3: CREATING TREATMENT VARIABLE"
di "========================================================================"

use `dept_store_data', clear

* Identify the key variables - ADJUST THESE BASED ON YOUR DATA
* Common variable names to look for:
di ""
di "3.1 Inspecting department store data structure:"
describe
list in 1/10

* Try to identify the year column (user should verify)
* Looking for: year, open_year, opening_year, etc.
local year_col ""
foreach v in year open_year opening_year year_opened first_year {
    cap confirm variable `v'
    if !_rc {
        local year_col "`v'"
        di "    Found year column: `year_col'"
        continue, break
    }
}

* If not found, use first numeric variable that looks like a year
if "`year_col'" == "" {
    di "    Year column not auto-detected. Please check variables manually."
    di "    Using first plausible year variable..."
    ds, has(type numeric)
    foreach v of varlist `r(varlist)' {
        qui sum `v'
        if `r(min)' > 1800 & `r(max)' < 2000 {
            local year_col "`v'"
            di "    Using: `year_col'"
            continue, break
        }
    }
}

* Try to identify geographic column
local geo_col ""
foreach v in fips countyicp county_fips statefip_countyicp icpsr fips_county {
    cap confirm variable `v'
    if !_rc {
        local geo_col "`v'"
        di "    Found geographic column: `geo_col'"
        continue, break
    }
}

* If variables found, create treatment timing
if "`year_col'" != "" & "`geo_col'" != "" {
    di ""
    di "3.2 Creating Treatment Timing Variable:"
    di "    Year column: `year_col'"
    di "    Geographic column: `geo_col'"

    * Get first opening year per geographic unit
    bysort `geo_col': egen first_dept_store_year = min(`year_col')

    * Keep one observation per geographic unit
    bysort `geo_col': keep if _n == 1
    keep `geo_col' first_dept_store_year

    di ""
    di "    Number of treated units: `c(N)'"
    qui sum first_dept_store_year
    di "    Treatment year range: `r(min)' - `r(max)'"

    * Distribution of treatment timing
    di ""
    di "    Treatment timing distribution:"
    tab first_dept_store_year, missing

    * Save treatment timing
    export delimited using "$OUTPUT_DIR/tables/treatment_timing.csv", replace
    save "$OUTPUT_DIR/data/treatment_timing.dta", replace

    * Create visualization
    hist first_dept_store_year, frequency ///
        title("Distribution of First Department Store Openings") ///
        xtitle("Year") ytitle("Number of Counties") ///
        color(navy%70)
    graph export "$OUTPUT_DIR/figures/treatment_timing_hist.png", replace

    * Cumulative adoption
    preserve
        collapse (count) n_counties = first_dept_store_year, by(first_dept_store_year)
        gen cumulative = sum(n_counties)

        twoway line cumulative first_dept_store_year, ///
            title("Cumulative Department Store Adoption") ///
            xtitle("Year") ytitle("Cumulative Number of Counties") ///
            lcolor(navy) lwidth(medium)
        graph export "$OUTPUT_DIR/figures/cumulative_adoption.png", replace
    restore

    tempfile treatment_timing
    save `treatment_timing', replace
}
else {
    di ""
    di "    WARNING: Could not auto-detect key variables."
    di "    Please manually specify year_col and geo_col in the script."
    di "    Available variables:"
    describe
}

********************************************************************************
* SECTION 4: OCCUPATION CODE IDENTIFICATION
********************************************************************************

di ""
di "========================================================================"
di "SECTION 4: OCCUPATION CODE IDENTIFICATION"
di "========================================================================"

use `census_data', clear

*------------------------------------------------------------------------------
* 4.1 Find and examine occupation variables
*------------------------------------------------------------------------------
di ""
di "4.1 Occupation Variables in Census Data:"

ds *occ*
local occ_vars `r(varlist)'
di "    Found: `occ_vars'"

* Find the main occupation variable (typically occ1950 for IPUMS historical data)
local main_occ ""
foreach v in occ1950 occ occstr occupation occ1900 occ1920 {
    cap confirm variable `v'
    if !_rc {
        local main_occ "`v'"
        di ""
        di "    Main occupation variable identified: `main_occ'"
        continue, break
    }
}

if "`main_occ'" == "" & "`occ_vars'" != "" {
    local main_occ : word 1 of `occ_vars'
    di "    Using first occupation variable: `main_occ'"
}

*------------------------------------------------------------------------------
* 4.2 Full occupation code listing
*------------------------------------------------------------------------------
di ""
di "4.2 Full Occupation Code Listing:"

if "`main_occ'" != "" {
    * Check for value labels
    local occ_label : value label `main_occ'

    if "`occ_label'" != "" {
        di "    Value label: `occ_label'"
        label list `occ_label'

        * Export full occupation listing with frequencies
        preserve
            contract `main_occ', freq(count)
            decode `main_occ', gen(occ_label)
            gen pct = count / `census_n' * 100
            gsort -count

            export delimited using "$OUTPUT_DIR/tables/occupation_codes_full.csv", replace

            di ""
            di "    Top 30 occupations by frequency:"
            list in 1/30, clean
        restore
    }
    else {
        di "    No value labels found for `main_occ'"
        di "    Showing frequency distribution:"
        tab `main_occ', sort
    }
}

*------------------------------------------------------------------------------
* 4.3 Identify DISPLACED occupations
*------------------------------------------------------------------------------
di ""
di "========================================================================"
di "4.3 DISPLACED OCCUPATIONS"
di "    (Retail merchants, shopkeepers, peddlers, small store owners)"
di "========================================================================"

* Create displaced occupation indicator
* NOTE: These codes are for IPUMS OCC1950. Adjust based on your actual coding system.
* Common displaced occupation codes in OCC1950:
*   - 290: Buyers and shippers, farm products
*   - 450: Agents, n.e.c.
*   - 144: Hucksters and peddlers
*   - Various merchant/dealer codes

* First, let's search for relevant occupations by examining labels
if "`main_occ'" != "" {
    gen occ_displaced = 0
    label var occ_displaced "1=Occupation likely displaced by dept stores"

    * Get the value label
    local occ_label : value label `main_occ'

    if "`occ_label'" != "" {
        * Search through labels for displaced occupation keywords
        * We'll create a list of codes to include

        di ""
        di "    Searching for displaced occupation codes..."
        di "    Keywords: merchant, shopkeeper, peddler, huckster, dealer, vendor, grocer"
        di ""

        * Decode to search labels
        decode `main_occ', gen(occ_label_str)

        * Flag displaced occupations based on label text
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "merchant")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "shopkeeper")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "peddler")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "huckster")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "hawker")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "vendor")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "dealer") & !regexm(lower(occ_label_str), "auto")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "grocer")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "dry goods")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "general store")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "retail.*proprietor")
        replace occ_displaced = 1 if regexm(lower(occ_label_str), "store.*owner")

        * Also include specific OCC1950 codes if applicable
        * Uncomment and adjust based on your data:
        * replace occ_displaced = 1 if inlist(`main_occ', 144, 290, ...)

        * Show identified displaced occupations
        di ""
        di "    Identified Displaced Occupations:"
        preserve
            keep if occ_displaced == 1
            contract `main_occ' occ_label_str, freq(count)
            gsort -count
            list, clean
            export delimited using "$OUTPUT_DIR/tables/displaced_occupations.csv", replace
        restore

        * Summary
        di ""
        tab occ_displaced, missing
        di "    N in displaced occupations: " _N " -> " %12.0fc occ_displaced
    }
}

*------------------------------------------------------------------------------
* 4.4 Identify CREATED occupations
*------------------------------------------------------------------------------
di ""
di "========================================================================"
di "4.4 CREATED OCCUPATIONS"
di "    (Department store clerks, salespeople, retail workers)"
di "========================================================================"

if "`main_occ'" != "" {
    gen occ_created = 0
    label var occ_created "1=Occupation likely created by dept stores"

    local occ_label : value label `main_occ'

    if "`occ_label'" != "" {
        di ""
        di "    Searching for created occupation codes..."
        di "    Keywords: clerk, sales, salesman, saleswoman, cashier, store, retail"
        di ""

        * Flag created occupations based on label text
        replace occ_created = 1 if regexm(lower(occ_label_str), "clerk") & regexm(lower(occ_label_str), "sales")
        replace occ_created = 1 if regexm(lower(occ_label_str), "salesman")
        replace occ_created = 1 if regexm(lower(occ_label_str), "saleswoman")
        replace occ_created = 1 if regexm(lower(occ_label_str), "salesperson")
        replace occ_created = 1 if regexm(lower(occ_label_str), "salesmen")
        replace occ_created = 1 if regexm(lower(occ_label_str), "saleswomen")
        replace occ_created = 1 if regexm(lower(occ_label_str), "cashier")
        replace occ_created = 1 if regexm(lower(occ_label_str), "floorwalker")
        replace occ_created = 1 if regexm(lower(occ_label_str), "floor manager")
        replace occ_created = 1 if regexm(lower(occ_label_str), "department.*head")
        replace occ_created = 1 if regexm(lower(occ_label_str), "buyer.*store")
        replace occ_created = 1 if regexm(lower(occ_label_str), "window.*dresser")
        replace occ_created = 1 if regexm(lower(occ_label_str), "stock.*clerk")
        replace occ_created = 1 if regexm(lower(occ_label_str), "retail.*sales")

        * Show identified created occupations
        di ""
        di "    Identified Created Occupations:"
        preserve
            keep if occ_created == 1
            contract `main_occ' occ_label_str, freq(count)
            gsort -count
            list, clean
            export delimited using "$OUTPUT_DIR/tables/created_occupations.csv", replace
        restore

        * Summary
        di ""
        tab occ_created, missing
    }
}

*------------------------------------------------------------------------------
* 4.5 Summary of occupation indicators
*------------------------------------------------------------------------------
di ""
di "4.5 Occupation Indicator Summary:"
di ""

tab occ_displaced occ_created, missing

di ""
di "    Displaced occupations: " %12.0fc `=sum(occ_displaced)'
di "    Created occupations:   " %12.0fc `=sum(occ_created)'

*------------------------------------------------------------------------------
* 4.6 Occupation distributions over time
*------------------------------------------------------------------------------
di ""
di "4.6 Occupation Distributions Over Time:"

* Find year variable
ds *year*
local year_vars `r(varlist)'
local year_col : word 1 of `year_vars'

if "`year_col'" != "" {
    di ""
    di "    Using year variable: `year_col'"

    * Displaced by year
    di ""
    di "    Displaced Occupations by Year:"
    table `year_col', stat(sum occ_displaced) stat(mean occ_displaced) stat(count occ_displaced)

    preserve
        collapse (sum) n_displaced=occ_displaced (mean) pct_displaced=occ_displaced (count) total=occ_displaced, by(`year_col')
        replace pct_displaced = pct_displaced * 100
        list, clean
        export delimited using "$OUTPUT_DIR/tables/displaced_by_year.csv", replace
    restore

    * Created by year
    di ""
    di "    Created Occupations by Year:"
    table `year_col', stat(sum occ_created) stat(mean occ_created) stat(count occ_created)

    preserve
        collapse (sum) n_created=occ_created (mean) pct_created=occ_created (count) total=occ_created, by(`year_col')
        replace pct_created = pct_created * 100
        list, clean
        export delimited using "$OUTPUT_DIR/tables/created_by_year.csv", replace
    restore

    * Visualization
    preserve
        collapse (mean) pct_displaced=occ_displaced pct_created=occ_created, by(`year_col')
        replace pct_displaced = pct_displaced * 100
        replace pct_created = pct_created * 100

        twoway (bar pct_displaced `year_col', color(red%50)) ///
               (bar pct_created `year_col', color(green%50)), ///
            title("Occupation Shares Over Time") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Displaced" 2 "Created"))
        graph export "$OUTPUT_DIR/figures/occupation_trends.png", replace
    restore
}

* Drop temporary label variable
cap drop occ_label_str

* Save census data with occupation indicators
save `census_data', replace

********************************************************************************
* SECTION 5: MERGE DATASETS AND SHOW TREATMENT VARIATION
********************************************************************************

di ""
di "========================================================================"
di "SECTION 5: MERGING DATASETS"
di "========================================================================"

use `census_data', clear

* Identify merge key in census data
di ""
di "5.1 Identifying Merge Keys:"

ds *county* *fips* *icp*
local census_geo_vars `r(varlist)'
di "    Census geographic variables: `census_geo_vars'"

* Try to merge - user should verify the correct merge key
* Common merge keys: countyicp, fips, statefip + countyicp

* First attempt: look for countyicp or similar
local merge_key ""
foreach v in countyicp county_icp fips county_fips statefip_countyicp {
    cap confirm variable `v'
    if !_rc {
        local merge_key "`v'"
        di "    Attempting merge on: `merge_key'"
        continue, break
    }
}

* Also check what's in treatment timing data
use `treatment_timing', clear
describe
local treatment_geo_var : word 1 of `r(varlist)'
di "    Treatment timing geographic variable: `treatment_geo_var'"

* Reload census data
use `census_data', clear

* Attempt merge
if "`merge_key'" != "" {
    di ""
    di "5.2 Merging on: `merge_key'"

    * Rename treatment geo var if different
    merge m:1 `merge_key' using `treatment_timing', keep(master match) gen(_merge_treatment)

    di ""
    di "    Merge Results:"
    tab _merge_treatment

    * Create treatment indicators
    ds *year*
    local year_col : word 1 of `r(varlist)'

    if "`year_col'" != "" {
        di ""
        di "5.3 Creating Treatment Indicators:"

        * Ever treated
        gen ever_treated = (first_dept_store_year != .)
        label var ever_treated "1=County ever receives department store"

        * Currently treated (post-treatment)
        gen treated = (first_dept_store_year != .) & (`year_col' >= first_dept_store_year)
        label var treated "1=Post-treatment period"

        * Event time
        gen event_time = `year_col' - first_dept_store_year
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
    }

    * Save merged data
    save "$OUTPUT_DIR/data/merged_analysis_data.dta", replace
    export delimited using "$OUTPUT_DIR/data/merged_analysis_data.csv", replace
}
else {
    di ""
    di "    WARNING: Could not identify merge key."
    di "    Please manually specify the merge variable."
    di "    Census geographic variables available: `census_geo_vars'"
}

*------------------------------------------------------------------------------
* 5.4 Treatment Timing Variation
*------------------------------------------------------------------------------
di ""
di "5.4 Treatment Timing Variation:"

if "`merge_key'" != "" {
    tab first_dept_store_year if ever_treated == 1, missing

    * Visualization
    preserve
        keep if ever_treated == 1
        collapse (count) n=ever_treated, by(first_dept_store_year)

        graph bar n, over(first_dept_store_year, label(angle(45))) ///
            title("Treatment Cohort Sizes") ///
            ytitle("Number of Census Observations") ///
            bar(1, color(navy%70))
        graph export "$OUTPUT_DIR/figures/treatment_cohort_sizes.png", replace
    restore
}

tempfile merged_data
save `merged_data', replace

********************************************************************************
* SECTION 6: CREATE CODEBOOK
********************************************************************************

di ""
di "========================================================================"
di "SECTION 6: CREATING CODEBOOK"
di "========================================================================"

* Create codebook file
file open codebook using "$OUTPUT_DIR/codebooks/codebook.txt", write replace

file write codebook "========================================================================" _n
file write codebook "CODEBOOK: Department Store Labor Market Impact Analysis" _n
file write codebook "Generated: $S_DATE $S_TIME" _n
file write codebook "========================================================================" _n _n

file write codebook "1. DATA SOURCES" _n
file write codebook "----------------------------------------" _n
file write codebook "Census Data: $CENSUS_DATA" _n
file write codebook "  - Observations: `census_n'" _n
file write codebook "  - Variables: `census_k'" _n _n
file write codebook "Department Store Data: $DEPT_STORE" _n
file write codebook "  - Observations: `dept_n'" _n
file write codebook "  - Variables: `dept_k'" _n _n

file write codebook "2. KEY VARIABLES" _n
file write codebook "----------------------------------------" _n
file write codebook "Geographic Identifiers:" _n
file write codebook "  Census: `census_geo_vars'" _n
file write codebook "  Dept Store: `treatment_geo_var'" _n _n
file write codebook "Year Variables:" _n
file write codebook "  Census: `census_year_vars'" _n
file write codebook "  Dept Store: `dept_year_vars'" _n _n

file write codebook "3. TREATMENT VARIABLES" _n
file write codebook "----------------------------------------" _n
file write codebook "first_dept_store_year:" _n
file write codebook "  Year when county first received a department store" _n
file write codebook "  Missing for never-treated counties" _n _n
file write codebook "ever_treated:" _n
file write codebook "  1 = County receives department store at some point" _n
file write codebook "  0 = County never receives department store (control)" _n _n
file write codebook "treated:" _n
file write codebook "  1 = Observation is in treated county AND in/after treatment year" _n
file write codebook "  0 = Otherwise (control or pre-treatment)" _n _n
file write codebook "event_time:" _n
file write codebook "  Years relative to treatment (negative=pre, 0=treatment year, positive=post)" _n
file write codebook "  Missing for never-treated counties" _n _n

file write codebook "4. OCCUPATION CLASSIFICATION" _n
file write codebook "----------------------------------------" _n
file write codebook "occ_displaced:" _n
file write codebook "  1 = Occupation likely negatively affected by department stores" _n
file write codebook "  Keywords: merchant, shopkeeper, peddler, huckster, dealer, vendor, grocer" _n _n
file write codebook "occ_created:" _n
file write codebook "  1 = Occupation likely created/expanded by department stores" _n
file write codebook "  Keywords: clerk, sales, salesman, saleswoman, cashier, retail" _n _n

file write codebook "5. METHODOLOGY NOTES" _n
file write codebook "----------------------------------------" _n
file write codebook "Staggered Difference-in-Differences Design:" _n
file write codebook "  - Treatment: First department store opening in county" _n
file write codebook "  - Timing: Varies across counties (staggered adoption)" _n
file write codebook "  - Control: Counties that never receive department stores" _n
file write codebook "  - Estimation: Suitable for Callaway-Sant'Anna or Sun-Abraham" _n

file close codebook

di "    Codebook saved to: $OUTPUT_DIR/codebooks/codebook.txt"

********************************************************************************
* SECTION 7: SUMMARY STATISTICS
********************************************************************************

di ""
di "========================================================================"
di "SECTION 7: GENERATING SUMMARY STATISTICS"
di "========================================================================"

use `merged_data', clear

*------------------------------------------------------------------------------
* 7.1 Pre-treatment characteristics by treatment status
*------------------------------------------------------------------------------
di ""
di "7.1 Pre-Treatment Characteristics by Treatment Status:"

* Define pre-treatment sample
ds *year*
local year_col : word 1 of `r(varlist)'

cap gen pre_period = (ever_treated == 0) | (ever_treated == 1 & `year_col' < first_dept_store_year)

* Get numeric variables for balance table
ds, has(type numeric)
local numeric_vars `r(varlist)'

* Exclude treatment-related variables
local outcome_vars ""
foreach v of local numeric_vars {
    if !inlist("`v'", "first_dept_store_year", "ever_treated", "treated", "event_time", "_merge_treatment", "pre_period") {
        local outcome_vars "`outcome_vars' `v'"
    }
}

* Limit to first 15 variables
local outcome_vars : word 1 of `outcome_vars'
forval i = 2/15 {
    local v : word `i' of `numeric_vars'
    if "`v'" != "" & !inlist("`v'", "first_dept_store_year", "ever_treated", "treated", "event_time", "_merge_treatment", "pre_period") {
        local outcome_vars "`outcome_vars' `v'"
    }
}

di "    Analyzing variables: `outcome_vars'"

* Balance table
if "`outcome_vars'" != "" {
    preserve
        keep if pre_period == 1

        * Calculate means by treatment status
        foreach v of varlist `outcome_vars' {
            qui sum `v' if ever_treated == 1
            local `v'_treat_mean = r(mean)
            local `v'_treat_sd = r(sd)
            local `v'_treat_n = r(N)

            qui sum `v' if ever_treated == 0
            local `v'_ctrl_mean = r(mean)
            local `v'_ctrl_sd = r(sd)
            local `v'_ctrl_n = r(N)
        }

        * Display table
        di ""
        di _col(1) "Variable" _col(25) "Treated Mean" _col(40) "Control Mean" _col(55) "Difference"
        di "----------------------------------------------------------------------"
        foreach v of varlist `outcome_vars' {
            local diff = ``v'_treat_mean' - ``v'_ctrl_mean'
            di _col(1) "`v'" _col(25) %9.3f ``v'_treat_mean' _col(40) %9.3f ``v'_ctrl_mean' _col(55) %9.3f `diff'
        }
    restore
}

*------------------------------------------------------------------------------
* 7.2 Outcome variables summary
*------------------------------------------------------------------------------
di ""
di "7.2 Outcome Variables Summary:"

foreach v in occ_displaced occ_created {
    cap confirm variable `v'
    if !_rc {
        di ""
        di "    `v':"
        sum `v', detail
    }
}

*------------------------------------------------------------------------------
* 7.3 Occupation distribution by treatment status
*------------------------------------------------------------------------------
di ""
di "7.3 Occupation Distribution by Treatment Status:"

cap confirm variable occ_displaced
if !_rc {
    di ""
    di "    Displaced Occupations:"
    table ever_treated, stat(sum occ_displaced) stat(mean occ_displaced) stat(count occ_displaced)
}

cap confirm variable occ_created
if !_rc {
    di ""
    di "    Created Occupations:"
    table ever_treated, stat(sum occ_created) stat(mean occ_created) stat(count occ_created)
}

*------------------------------------------------------------------------------
* 7.4 Sample sizes
*------------------------------------------------------------------------------
di ""
di "7.4 Sample Size Summary:"

di ""
di "    By treatment status:"
tab ever_treated, missing

di ""
di "    By treatment status and year:"
tab `year_col' ever_treated, missing

preserve
    collapse (count) n=ever_treated (mean) pct_treated=treated (mean) pct_ever_treated=ever_treated, by(`year_col')
    list, clean
    export delimited using "$OUTPUT_DIR/tables/sample_by_year.csv", replace
restore

********************************************************************************
* SECTION 8: VISUALIZATIONS
********************************************************************************

di ""
di "========================================================================"
di "SECTION 8: CREATING VISUALIZATIONS"
di "========================================================================"

*------------------------------------------------------------------------------
* 8.1 Pre-trends in key outcomes
*------------------------------------------------------------------------------
di ""
di "8.1 Pre-Trends in Key Outcomes:"

ds *year*
local year_col : word 1 of `r(varlist)'

* Displaced occupations pre-trend
cap confirm variable occ_displaced
if !_rc {
    preserve
        collapse (mean) occ_displaced, by(`year_col' ever_treated)
        replace occ_displaced = occ_displaced * 100

        reshape wide occ_displaced, i(`year_col') j(ever_treated)

        twoway (line occ_displaced0 `year_col', lcolor(blue) lwidth(medium)) ///
               (line occ_displaced1 `year_col', lcolor(red) lwidth(medium)), ///
            title("Pre-Trends: Displaced Occupations") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Never Treated" 2 "Ever Treated"))
        graph export "$OUTPUT_DIR/figures/pretrend_displaced.png", replace
    restore
}

* Created occupations pre-trend
cap confirm variable occ_created
if !_rc {
    preserve
        collapse (mean) occ_created, by(`year_col' ever_treated)
        replace occ_created = occ_created * 100

        reshape wide occ_created, i(`year_col') j(ever_treated)

        twoway (line occ_created0 `year_col', lcolor(blue) lwidth(medium)) ///
               (line occ_created1 `year_col', lcolor(red) lwidth(medium)), ///
            title("Pre-Trends: Created Occupations") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Never Treated" 2 "Ever Treated"))
        graph export "$OUTPUT_DIR/figures/pretrend_created.png", replace
    restore
}

*------------------------------------------------------------------------------
* 8.2 Event Study Plot (Raw)
*------------------------------------------------------------------------------
di ""
di "8.2 Event Study Plots:"

cap confirm variable event_time
if !_rc {
    * Displaced
    cap confirm variable occ_displaced
    if !_rc {
        preserve
            keep if ever_treated == 1
            keep if event_time >= -20 & event_time <= 20

            collapse (mean) mean=occ_displaced (sd) sd=occ_displaced (count) n=occ_displaced, by(event_time)
            gen se = sd / sqrt(n)
            gen ci_lo = mean - 1.96*se
            gen ci_hi = mean + 1.96*se

            twoway (rcap ci_lo ci_hi event_time, lcolor(gray)) ///
                   (scatter mean event_time, mcolor(navy) msize(small)), ///
                xline(0, lcolor(red) lpattern(dash)) ///
                title("Event Study: Displaced Occupations") ///
                xtitle("Years Relative to Treatment") ytitle("Share") ///
                legend(off)
            graph export "$OUTPUT_DIR/figures/event_study_displaced.png", replace
        restore
    }

    * Created
    cap confirm variable occ_created
    if !_rc {
        preserve
            keep if ever_treated == 1
            keep if event_time >= -20 & event_time <= 20

            collapse (mean) mean=occ_created (sd) sd=occ_created (count) n=occ_created, by(event_time)
            gen se = sd / sqrt(n)
            gen ci_lo = mean - 1.96*se
            gen ci_hi = mean + 1.96*se

            twoway (rcap ci_lo ci_hi event_time, lcolor(gray)) ///
                   (scatter mean event_time, mcolor(green) msize(small)), ///
                xline(0, lcolor(red) lpattern(dash)) ///
                title("Event Study: Created Occupations") ///
                xtitle("Years Relative to Treatment") ytitle("Share") ///
                legend(off)
            graph export "$OUTPUT_DIR/figures/event_study_created.png", replace
        restore
    }
}

*------------------------------------------------------------------------------
* 8.3 Combined visualization
*------------------------------------------------------------------------------
di ""
di "8.3 Combined Occupation Trends:"

cap confirm variable occ_displaced
cap confirm variable occ_created
if !_rc {
    preserve
        collapse (mean) occ_displaced occ_created, by(`year_col' ever_treated)
        replace occ_displaced = occ_displaced * 100
        replace occ_created = occ_created * 100

        * Treated group
        twoway (line occ_displaced `year_col' if ever_treated==1, lcolor(red) lwidth(medium)) ///
               (line occ_created `year_col' if ever_treated==1, lcolor(green) lwidth(medium)) ///
               (line occ_displaced `year_col' if ever_treated==0, lcolor(red) lwidth(medium) lpattern(dash)) ///
               (line occ_created `year_col' if ever_treated==0, lcolor(green) lwidth(medium) lpattern(dash)), ///
            title("Occupation Composition Over Time") ///
            xtitle("Census Year") ytitle("Percent") ///
            legend(order(1 "Displaced (Treated)" 2 "Created (Treated)" ///
                        3 "Displaced (Control)" 4 "Created (Control)") rows(2))
        graph export "$OUTPUT_DIR/figures/occupation_composition_combined.png", replace
    restore
}

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
di "Outputs saved to: $OUTPUT_DIR"
di "  - tables/: CSV tables"
di "  - figures/: PNG visualizations"
di "  - codebooks/: Variable documentation"
di "  - data/: Merged analysis dataset"
di ""
di "Key output files:"
di "  - merged_analysis_data.dta: Ready for DiD estimation"
di "  - occupation_codes_full.csv: All occupation codes"
di "  - displaced_occupations.csv: Classified displaced occupations"
di "  - created_occupations.csv: Classified created occupations"
di ""

log close

********************************************************************************
* END OF SCRIPT
********************************************************************************
